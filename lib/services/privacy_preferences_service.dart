import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/platform_capabilities.dart';
import '../utils/safe_log.dart';

/// Preferencias de privacidad con valores conservadores por defecto.
///
/// Analytics, reportes de fallos y el reproductor externo de YouTube quedan
/// apagados hasta que la persona los habilita mediante una acción afirmativa.
class PrivacyPreferencesService {
  PrivacyPreferencesService._();

  static final PrivacyPreferencesService I = PrivacyPreferencesService._();

  static const legalVersion = '2026-09-07';
  static const _legalVersionKey = 'privacy.legal_version';
  static const _legalAcceptedAtKey = 'privacy.legal_accepted_at';
  static const _legalAcceptedUidKey = 'privacy.legal_accepted_uid';
  static const _analyticsKey = 'privacy.analytics_enabled';
  static const _crashReportsKey = 'privacy.crash_reports_enabled';
  static const _youtubeEmbedsKey = 'privacy.youtube_embeds_enabled';

  final ValueNotifier<bool> legalConsentAccepted = ValueNotifier(false);
  final ValueNotifier<bool> analyticsEnabled = ValueNotifier(false);
  final ValueNotifier<bool> crashReportsEnabled = ValueNotifier(false);
  final ValueNotifier<bool> youtubeEmbedsEnabled = ValueNotifier(false);

  SharedPreferences? _prefs;
  // Singleton de proceso: la suscripción vive mientras la app está abierta.
  // ignore: cancel_subscriptions
  StreamSubscription<User?>? _authSubscription;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _refreshConsentForUser(FirebaseAuth.instance.currentUser);
    analyticsEnabled.value = _prefs!.getBool(_analyticsKey) ?? false;
    crashReportsEnabled.value = _prefs!.getBool(_crashReportsKey) ?? false;
    youtubeEmbedsEnabled.value = _prefs!.getBool(_youtubeEmbedsKey) ?? false;
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen(
      _refreshConsentForUser,
    );
  }

  /// Debe ejecutarse inmediatamente después de inicializar Firebase para que
  /// los SDK opcionales respeten la elección almacenada desde el arranque.
  Future<void> applyFirebasePreferences() async {
    if (PlatformCapabilities.supportsFirebaseAnalytics) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
        analyticsEnabled.value,
      );
    }
    if (PlatformCapabilities.supportsCrashlytics) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        crashReportsEnabled.value,
      );
    }
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefs!.setBool(_analyticsKey, enabled);
    if (PlatformCapabilities.supportsFirebaseAnalytics) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    }
    analyticsEnabled.value = enabled;
  }

  Future<void> setCrashReportsEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefs!.setBool(_crashReportsKey, enabled);
    if (PlatformCapabilities.supportsCrashlytics) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
    }
    crashReportsEnabled.value = enabled;
  }

  Future<void> setYoutubeEmbedsEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefs!.setBool(_youtubeEmbedsKey, enabled);
    youtubeEmbedsEnabled.value = enabled;
  }

  /// Conserva evidencia local y, si hay una cuenta, registra versión y fecha
  /// en su documento privado de Firestore. No guarda el contenido escrito por
  /// la persona ni habilita analítica automáticamente.
  Future<void> acceptRequiredConsent() async {
    await _ensureInitialized();
    final acceptedAt = DateTime.now().toUtc().toIso8601String();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _prefs!.setString(_legalVersionKey, legalVersion);
    await _prefs!.setString(_legalAcceptedAtKey, acceptedAt);
    await _prefs!.setString(_legalAcceptedUidKey, user.uid);
    legalConsentAccepted.value = true;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'legalConsentVersion': legalVersion,
            'legalConsentAcceptedAt': FieldValue.serverTimestamp(),
            'sensitiveDataConsent': true,
          });
    } catch (error) {
      // El consentimiento local permite continuar sin fingir que el registro
      // remoto ocurrió. Firestore reintentará escrituras offline; otros fallos
      // quedan en el log local para diagnóstico sin exponer datos sensibles.
      safeWarn(
        'PRIVACY',
        'No se pudo registrar el consentimiento remoto: $error',
      );
    }
  }

  Future<void> _ensureInitialized() async {
    if (_prefs == null) await initialize();
  }

  void _refreshConsentForUser(User? user) {
    final prefs = _prefs;
    legalConsentAccepted.value =
        user != null &&
        prefs?.getString(_legalVersionKey) == legalVersion &&
        prefs?.getString(_legalAcceptedUidKey) == user.uid;
  }
}
