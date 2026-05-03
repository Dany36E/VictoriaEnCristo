/// ═══════════════════════════════════════════════════════════════════════════
/// FCM SERVICE
/// Gestiona el token FCM del dispositivo y lo guarda en
/// `users/{uid}/fcmTokens/{deviceId}` para que Cloud Functions pueda enviar
/// push notifications al Compañero de Batalla (invite / message / SOS).
///
/// Pattern:
/// - `FcmService.I.init()` se llama en phase 3 post-runApp.
/// - Solicita permiso, obtiene token, upsert a Firestore.
/// - Escucha `onTokenRefresh` para mantener el token actualizado.
/// - Escucha `onMessage` en foreground y muestra la misma notificación local
///   que llegaría por sistema en background/terminated.
/// - Tolera ausencia de usuario: si no hay auth, no hace nada.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import '../utils/platform_capabilities.dart';

class FcmService {
  FcmService._();
  static final FcmService I = FcmService._();

  static const _kDeviceIdKey = 'fcm_device_id';
  static const _kLastTokenKey = 'fcm_last_token';
  static const _kLastTokenUidKey = 'fcm_last_token_uid';

  bool _initialized = false;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  String? get token => _token;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (!PlatformCapabilities.supportsFcm) {
      debugPrint('🔔 [FCM] skipped on ${PlatformCapabilities.currentLabel}');
      return;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      // Permisos (en iOS/Web es obligatorio; en Android 13+ también).
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // iOS necesita APNS token antes del FCM token.
      if (!kIsWeb && Platform.isIOS) {
        await messaging.getAPNSToken();
      }

      _token = await messaging.getToken();
      await _persistToken();

      _refreshSub = messaging.onTokenRefresh.listen((t) async {
        _token = t;
        await _persistToken();
      });

      // Reintentar cuando cambie el auth (login/logout).
      _authSub = FirebaseAuth.instance.authStateChanges().listen((u) async {
        if (u != null) {
          await _persistToken();
        }
      });

      _foregroundSub = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
        onError: (e) => debugPrint('⚠️ [FCM] foreground message error: $e'),
      );

      debugPrint('🔔 [FCM] token=${_token?.substring(0, 12) ?? 'null'}…');
    } catch (e) {
      debugPrint('⚠️ [FCM] init error: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] ?? '';
    if (!type.startsWith('battle_')) return;

    final fromName = _clean(data['fromName']) ?? 'Tu compañero';
    final rawId =
        _clean(data['messageId']) ??
        _clean(data['inviteId']) ??
        message.messageId ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final id = _notifIdFor(type, rawId);

    switch (type) {
      case 'battle_invite':
        await NotificationService().showBattlePartnerInvite(
          id: id,
          fromName: fromName == 'Tu compañero' ? 'Alguien' : fromName,
        );
        break;
      case 'battle_sos':
        await NotificationService().showBattleSos(id: id, fromName: fromName);
        break;
      case 'battle_message':
        final text =
            _clean(data['text']) ?? message.notification?.body ?? 'Te envió un mensaje de aliento';
        await NotificationService().showBattleMessage(id: id, fromName: fromName, text: text);
        break;
    }
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  int _notifIdFor(String type, String docId) {
    final hash = docId.hashCode & 0x3FFFFFFF;
    return type == 'battle_invite' ? (0x20000000 | hash) : (0x40000000 | hash);
  }

  Future<void> _persistToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = _token;
    if (user == null || token == null || token.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString(_kDeviceIdKey);
      if (deviceId == null) {
        deviceId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
        await prefs.setString(_kDeviceIdKey, deviceId);
      }

      // OPTIMIZACIÓN: si el token y el uid no cambiaron desde la última
      // persistencia, evitamos un write innecesario a Firestore en cada
      // arranque/refresh. Re-escribimos al menos una vez cada 7 días para
      // mantener `updatedAt` razonablemente fresco (sirve para purgar
      // tokens muertos en backend).
      final lastToken = prefs.getString(_kLastTokenKey);
      final lastUid = prefs.getString(_kLastTokenUidKey);
      final lastWriteMs = prefs.getInt('${_kLastTokenKey}_ts') ?? 0;
      final ageMs = DateTime.now().millisecondsSinceEpoch - lastWriteMs;
      const refreshIntervalMs = 7 * 24 * 60 * 60 * 1000; // 7 días
      if (lastToken == token && lastUid == user.uid && ageMs < refreshIntervalMs) {
        return;
      }

      final platform = kIsWeb
          ? 'web'
          : Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
          ? 'android'
          : 'other';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(deviceId)
          .set({
            'token': token,
            'platform': platform,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await prefs.setString(_kLastTokenKey, token);
      await prefs.setString(_kLastTokenUidKey, user.uid);
      await prefs.setInt('${_kLastTokenKey}_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ [FCM] persist error: $e');
    }
  }

  /// Re-registra el token bajo el usuario actualmente autenticado. Útil
  /// cuando cambia la cuenta y el token ya existía pero estaba vinculado
  /// al uid anterior.
  Future<void> registerTokenForCurrentUser() async {
    if (!PlatformCapabilities.supportsFcm) return;
    if (_token == null) {
      try {
        _token = await FirebaseMessaging.instance.getToken();
      } catch (_) {}
    }
    await _persistToken();
  }

  /// Elimina el documento del token FCM del dispositivo para el usuario
  /// actualmente autenticado. Importante al cerrar sesión o al cambiar de
  /// cuenta, para que las Cloud Functions no envíen notificaciones al
  /// dispositivo equivocado.
  Future<void> clearTokenForUser() async {
    if (!PlatformCapabilities.supportsFcm) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString(_kDeviceIdKey);
      if (deviceId == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(deviceId)
          .delete();
      debugPrint('🔔 [FCM] Token doc deleted for user ${user.uid}');
    } catch (e) {
      debugPrint('⚠️ [FCM] clearTokenForUser error: $e');
    }
  }

  Future<void> dispose() async {
    await _refreshSub?.cancel();
    await _authSub?.cancel();
    await _foregroundSub?.cancel();
    _refreshSub = null;
    _authSub = null;
    _foregroundSub = null;
    _initialized = false;
  }
}
