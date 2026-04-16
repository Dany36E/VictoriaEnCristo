import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../data/bible_verses.dart';

/// Servicio de notificaciones para recordatorios diarios.
/// Usa flutter_local_notifications con timezone para scheduling recurrente.
class NotificationService {
  static const String _morningEnabledKey = 'morning_notification_enabled';
  static const String _morningTimeKey = 'morning_notification_time';
  static const String _nightEnabledKey = 'night_notification_enabled';
  static const String _nightTimeKey = 'night_notification_time';
  static const String _emergencyReminderKey = 'emergency_reminder_enabled';
  static const String _victoryReminderKey = 'victory_reminder_enabled';
  static const String _reengagementKey = 'reengagement_enabled';

  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Configuración por defecto
  TimeOfDay _morningTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _nightTime = const TimeOfDay(hour: 21, minute: 0);
  bool _morningEnabled = true;
  bool _nightEnabled = true;
  bool _emergencyReminderEnabled = true;
  bool _victoryReminderEnabled = true;
  bool _reengagementEnabled = true;

  // Notificaciones locales
  final FlutterLocalNotificationsPlugin _flnp = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  // Getters
  TimeOfDay get morningTime => _morningTime;
  TimeOfDay get nightTime => _nightTime;
  bool get morningEnabled => _morningEnabled;
  bool get nightEnabled => _nightEnabled;
  bool get emergencyReminderEnabled => _emergencyReminderEnabled;
  bool get victoryReminderEnabled => _victoryReminderEnabled;
  bool get reengagementEnabled => _reengagementEnabled;

  /// Inicializar servicio y cargar configuración
  Future<void> initialize() async {
    await _loadSettings();
    await _initNotifications();
  }

  /// Cargar configuración guardada
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    _morningEnabled = prefs.getBool(_morningEnabledKey) ?? true;
    _nightEnabled = prefs.getBool(_nightEnabledKey) ?? true;
    _emergencyReminderEnabled = prefs.getBool(_emergencyReminderKey) ?? true;
    _victoryReminderEnabled = prefs.getBool(_victoryReminderKey) ?? true;
    _reengagementEnabled = prefs.getBool(_reengagementKey) ?? true;
    
    final morningMinutes = prefs.getInt(_morningTimeKey);
    if (morningMinutes != null) {
      _morningTime = TimeOfDay(
        hour: morningMinutes ~/ 60,
        minute: morningMinutes % 60,
      );
    }
    
    final nightMinutes = prefs.getInt(_nightTimeKey);
    if (nightMinutes != null) {
      _nightTime = TimeOfDay(
        hour: nightMinutes ~/ 60,
        minute: nightMinutes % 60,
      );
    }
  }

  Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;
    try {
      tz.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const init = InitializationSettings(android: android);
      await _flnp.initialize(init);
      _notificationsInitialized = true;
    } catch (e) {
      debugPrint('⚠️ No se pudo inicializar notificaciones locales: $e');
      _notificationsInitialized = false;
    }
  }

  /// Guardar configuración
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool(_morningEnabledKey, _morningEnabled);
    await prefs.setBool(_nightEnabledKey, _nightEnabled);
    await prefs.setBool(_emergencyReminderKey, _emergencyReminderEnabled);
    await prefs.setBool(_victoryReminderKey, _victoryReminderEnabled);
    await prefs.setBool(_reengagementKey, _reengagementEnabled);
    await prefs.setInt(_morningTimeKey, _morningTime.hour * 60 + _morningTime.minute);
    await prefs.setInt(_nightTimeKey, _nightTime.hour * 60 + _nightTime.minute);
  }

  /// Solicitar permisos (Android 13+/iOS)
  Future<bool> requestPermissions() async {
    try {
      final android = await _flnp.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      return android ?? true;
    } catch (e) {
      debugPrint('⚠️ No se pudieron solicitar permisos de notificación: $e');
      return false;
    }
  }

  /// Actualizar hora de notificación matutina
  Future<void> setMorningTime(TimeOfDay time) async {
    _morningTime = time;
    await _saveSettings();
    if (_morningEnabled) {
      await _scheduleMorningNotification();
    }
  }

  /// Actualizar hora de notificación nocturna
  Future<void> setNightTime(TimeOfDay time) async {
    _nightTime = time;
    await _saveSettings();
    if (_nightEnabled) {
      await _scheduleNightNotification();
    }
  }

  /// Habilitar/deshabilitar notificación matutina
  Future<void> setMorningEnabled(bool enabled) async {
    _morningEnabled = enabled;
    await _saveSettings();
    if (enabled) {
      await _scheduleMorningNotification();
    } else {
      await _cancelMorningNotification();
    }
  }

  /// Habilitar/deshabilitar notificación nocturna
  Future<void> setNightEnabled(bool enabled) async {
    _nightEnabled = enabled;
    await _saveSettings();
    if (enabled) {
      await _scheduleNightNotification();
    } else {
      await _cancelNightNotification();
    }
  }

  /// Habilitar/deshabilitar recordatorio de emergencia
  Future<void> setEmergencyReminderEnabled(bool enabled) async {
    _emergencyReminderEnabled = enabled;
    await _saveSettings();
  }

  // IDs fijos para notificaciones recurrentes
  static const int _morningNotificationId = 1001;
  static const int _nightNotificationId = 1002;
  static const int _victoryReminderId = 1003;
  static const int _reengagementId = 1004;

  /// Calcular próxima hora de disparo
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Programar notificación matutina
  Future<void> _scheduleMorningNotification() async {
    if (!_notificationsInitialized) await _initNotifications();
    if (!_notificationsInitialized) return;
    try {
      await _flnp.cancel(_morningNotificationId);
      final verse = BibleVerses.getRandomVerse();
      final body = '🌅 "${verse.verse.substring(0, verse.verse.length > 80 ? 80 : verse.verse.length)}..." — ${verse.reference}';
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_reminders',
          'Recordatorio matutino',
          channelDescription: 'Versículo y motivación cada mañana',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      );
      await _flnp.zonedSchedule(
        _morningNotificationId,
        'Buenos días, guerrero',
        body,
        _nextInstanceOfTime(_morningTime),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('🔔 Notificación matutina programada: ${_morningTime.hour}:${_morningTime.minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('⚠️ Error programando notificación matutina: $e');
    }
  }

  /// Programar notificación nocturna
  Future<void> _scheduleNightNotification() async {
    if (!_notificationsInitialized) await _initNotifications();
    if (!_notificationsInitialized) return;
    try {
      await _flnp.cancel(_nightNotificationId);
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'night_reminders',
          'Recordatorio nocturno',
          channelDescription: 'Recordatorio para registrar tu día',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      );
      await _flnp.zonedSchedule(
        _nightNotificationId,
        '¿Cómo estuvo tu día?',
        '🌙 Recuerda registrar tu progreso antes de dormir.',
        _nextInstanceOfTime(_nightTime),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('🔔 Notificación nocturna programada: ${_nightTime.hour}:${_nightTime.minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('⚠️ Error programando notificación nocturna: $e');
    }
  }

  /// Cancelar notificación matutina
  Future<void> _cancelMorningNotification() async {
    try {
      await _flnp.cancel(_morningNotificationId);
      debugPrint('🔔 Notificación matutina cancelada');
    } catch (e) {
      debugPrint('⚠️ Error cancelando notificación matutina: $e');
    }
  }

  /// Cancelar notificación nocturna
  Future<void> _cancelNightNotification() async {
    try {
      await _flnp.cancel(_nightNotificationId);
      debugPrint('🔔 Notificación nocturna cancelada');
    } catch (e) {
      debugPrint('⚠️ Error cancelando notificación nocturna: $e');
    }
  }

  /// Programar todas las notificaciones
  Future<void> scheduleAllNotifications() async {
    if (_morningEnabled) await _scheduleMorningNotification();
    if (_nightEnabled) await _scheduleNightNotification();
    if (_victoryReminderEnabled) await _scheduleVictoryReminder();
    if (_reengagementEnabled) await _scheduleReengagement();
  }

  /// ────────────────────────────────────────────────────────────────────────
  /// Recordatorios por plan (diarios)
  /// ────────────────────────────────────────────────────────────────────────
  Future<bool> scheduleDailyPlanReminder({
    required String planId,
    required TimeOfDay timeOfDay,
    int offsetMinutes = 0,
    bool weekdaysOnly = false,
    String? title,
    String? body,
  }) async {
    try {
      if (!_notificationsInitialized) await _initNotifications();
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        timeOfDay.hour,
        timeOfDay.minute,
      ).add(Duration(minutes: -offsetMinutes));

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      if (weekdaysOnly) {
        while (scheduled.weekday == DateTime.saturday || scheduled.weekday == DateTime.sunday) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'plan_reminders',
          'Recordatorios de Plan',
          channelDescription: 'Recordatorios diarios para planes personalizados',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      );

      await _flnp.zonedSchedule(
        _planNotificationId(planId),
        title ?? 'Continúa tu plan',
        body ?? 'Tu sesión de hoy está lista.',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ scheduleDailyPlanReminder error: $e');
      return false;
    }
  }

  Future<void> cancelPlanReminder(String planId) async {
    try {
      await _flnp.cancel(_planNotificationId(planId));
    } catch (e) {
      debugPrint('⚠️ cancelPlanReminder error: $e');
    }
  }

  Future<bool> hasPlanReminder(String planId) async {
    try {
      final pending = await _flnp.pendingNotificationRequests();
      return pending.any((p) => p.id == _planNotificationId(planId));
    } catch (e) {
      debugPrint('⚠️ hasPlanReminder error: $e');
      return false;
    }
  }

  int _planNotificationId(String planId) => planId.hashCode & 0x7fffffff;

  /// Obtener mensaje para notificación matutina
  String getMorningMessage() {
    final verse = BibleVerses.getRandomVerse();
    return '🌅 Buenos días, guerrero. "${verse.verse.substring(0, verse.verse.length > 80 ? 80 : verse.verse.length)}..." - ${verse.reference}';
  }

  /// Obtener mensaje para notificación nocturna
  String getNightMessage(int currentStreak) {
    if (currentStreak > 0) {
      return '🌙 ¡$currentStreak días de victoria! ¿Registraste tu día de hoy?';
    }
    return '🌙 ¿Cómo estuvo tu día? Recuerda registrar tu progreso.';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECORDATORIO INTELIGENTE DE VICTORIA (diario a las 20:00)
  // Si el usuario no ha registrado victoria cuando ya puede (≥18h)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Habilitar/deshabilitar recordatorio de victoria
  Future<void> setVictoryReminderEnabled(bool enabled) async {
    _victoryReminderEnabled = enabled;
    await _saveSettings();
    if (enabled) {
      await _scheduleVictoryReminder();
    } else {
      await _flnp.cancel(_victoryReminderId);
    }
  }

  /// Programar recordatorio diario a las 20:00 para registrar victoria
  Future<void> _scheduleVictoryReminder() async {
    if (!_notificationsInitialized) await _initNotifications();
    if (!_notificationsInitialized) return;
    try {
      await _flnp.cancel(_victoryReminderId);
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'victory_reminder',
          'Recordatorio de victoria',
          channelDescription: 'Te recuerda registrar tu victoria diaria',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      );
      await _flnp.zonedSchedule(
        _victoryReminderId,
        '¿Ya registraste tu victoria?',
        '⚔️ Ya son más de las 6 PM. ¡No olvides marcar tu día!',
        _nextInstanceOfTime(const TimeOfDay(hour: 20, minute: 0)),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('🔔 Recordatorio de victoria programado: 20:00');
    } catch (e) {
      debugPrint('⚠️ Error programando recordatorio de victoria: $e');
    }
  }

  /// Cancelar el recordatorio de victoria (llamar cuando el usuario registra)
  Future<void> cancelVictoryReminderForToday() async {
    // Re-programar para mañana (zonedSchedule con matchDateTimeComponents.time
    // ya maneja esto, pero cancelamos y reprogramamos para limpiar)
    if (_victoryReminderEnabled) {
      await _scheduleVictoryReminder();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RE-ENGAGEMENT (si no abre la app en 2+ días)
  // Programa una notificación fija a 48h en el futuro
  // Se re-programa cada vez que la app se inicia
  // ═══════════════════════════════════════════════════════════════════════════

  /// Habilitar/deshabilitar re-engagement
  Future<void> setReengagementEnabled(bool enabled) async {
    _reengagementEnabled = enabled;
    await _saveSettings();
    if (enabled) {
      await _scheduleReengagement();
    } else {
      await _flnp.cancel(_reengagementId);
    }
  }

  /// Programar notificación de re-engagement a 48h desde ahora
  Future<void> _scheduleReengagement() async {
    if (!_notificationsInitialized) await _initNotifications();
    if (!_notificationsInitialized) return;
    try {
      await _flnp.cancel(_reengagementId);

      final scheduled = tz.TZDateTime.now(tz.local).add(const Duration(hours: 48));

      const messages = [
        '💪 La victoria se construye un día a la vez. ¡Vuelve!',
        '🛡️ Tu racha te espera. No pierdas el impulso.',
        '🙏 Dios tiene algo nuevo para ti hoy. Abre tu app.',
        '⚔️ Un guerrero no abandona la batalla. ¡Regresa!',
      ];
      final body = messages[DateTime.now().day % messages.length];

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'reengagement',
          'Te extrañamos',
          channelDescription: 'Recordatorio si no has abierto la app en 2 días',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
        ),
      );
      await _flnp.zonedSchedule(
        _reengagementId,
        'Te extrañamos, guerrero',
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('🔔 Re-engagement programado para: $scheduled');
    } catch (e) {
      debugPrint('⚠️ Error programando re-engagement: $e');
    }
  }
}
