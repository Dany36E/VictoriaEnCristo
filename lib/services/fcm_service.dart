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
/// - Escucha `onMessage` en foreground (no-op: las notifs locales son
///   generadas por los listeners de Firestore de BattlePartnerService).
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

class FcmService {
  FcmService._();
  static final FcmService I = FcmService._();

  static const _kDeviceIdKey = 'fcm_device_id';

  bool _initialized = false;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<User?>? _authSub;

  String? get token => _token;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final messaging = FirebaseMessaging.instance;
      // Permisos (en iOS/Web es obligatorio; en Android 13+ también).
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

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

      debugPrint('🔔 [FCM] token=${_token?.substring(0, 12) ?? 'null'}…');
    } catch (e) {
      debugPrint('⚠️ [FCM] init error: $e');
    }
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
    } catch (e) {
      debugPrint('⚠️ [FCM] persist error: $e');
    }
  }

  /// Re-registra el token bajo el usuario actualmente autenticado. Útil
  /// cuando cambia la cuenta y el token ya existía pero estaba vinculado
  /// al uid anterior.
  Future<void> registerTokenForCurrentUser() async {
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
    _refreshSub = null;
    _authSub = null;
    _initialized = false;
  }
}
