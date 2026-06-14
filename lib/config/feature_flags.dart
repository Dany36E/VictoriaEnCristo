library;

import '../services/remote_config_service.dart';

/// Flags de producto controlados remotamente vía /config/app en Firestore.
/// RemoteConfigService los cachea localmente con TTL 6h, offline-first.
/// Los defaults hardcoded aplican cuando el documento no existe o no se ha
/// cargado aún (primer arranque offline, TTL no expirado, etc.).
class FeatureFlags {
  FeatureFlags._();

  /// Insignias globales. Deshabilitadas por defecto hasta estabilizar el flow.
  static bool get badgesEnabled =>
      RemoteConfigService.I.get('badges_enabled', false);

  /// Capa de Talentos/Coleccionables. Deshabilitada hasta nuevo aviso.
  static bool get learningCollectiblesEnabled =>
      RemoteConfigService.I.get('learning_collectibles_enabled', false);

  /// SOS de emergencia (llama a contacto de confianza).
  static bool get emergencySosEnabled =>
      RemoteConfigService.I.get('emergency_sos_enabled', true);

  /// Alarmas sagradas (notificaciones de práctica diaria).
  static bool get sacredAlarmsEnabled =>
      RemoteConfigService.I.get('sacred_alarms_enabled', true);

  /// Flujo de Práctica Diaria (nuevo flow guiado).
  static bool get dailyPracticeEnabled =>
      RemoteConfigService.I.get('daily_practice_enabled', true);

  /// Push notifications vía FCM.
  static bool get fcmEnabled =>
      RemoteConfigService.I.get('fcm_enabled', true);
}
