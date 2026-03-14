import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../data/bible_verses.dart';

/// Servicio de notificaciones para recordatorios diarios
/// Nota: Para notificaciones locales reales se necesita flutter_local_notifications
/// Este servicio maneja la lógica y configuración
class NotificationService {
  static const String _morningEnabledKey = 'morning_notification_enabled';
  static const String _morningTimeKey = 'morning_notification_time';
  static const String _nightEnabledKey = 'night_notification_enabled';
  static const String _nightTimeKey = 'night_notification_time';
  static const String _emergencyReminderKey = 'emergency_reminder_enabled';

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

  // Notificaciones locales
  final FlutterLocalNotificationsPlugin _flnp = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  // Getters
  TimeOfDay get morningTime => _morningTime;
  TimeOfDay get nightTime => _nightTime;
  bool get morningEnabled => _morningEnabled;
  bool get nightEnabled => _nightEnabled;
  bool get emergencyReminderEnabled => _emergencyReminderEnabled;

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

  /// Programar notificación matutina
  Future<void> _scheduleMorningNotification() async {
    // Aquí iría la lógica de flutter_local_notifications
    // Por ahora es un placeholder
    final verse = BibleVerses.getRandomVerse();
    print('Notificación matutina programada para ${_morningTime.hour}:${_morningTime.minute}');
    print('Versículo: ${verse.reference}');
  }

  /// Programar notificación nocturna
  Future<void> _scheduleNightNotification() async {
    print('Notificación nocturna programada para ${_nightTime.hour}:${_nightTime.minute}');
  }

  /// Cancelar notificación matutina
  Future<void> _cancelMorningNotification() async {
    print('Notificación matutina cancelada');
  }

  /// Cancelar notificación nocturna
  Future<void> _cancelNightNotification() async {
    print('Notificación nocturna cancelada');
  }

  /// Programar todas las notificaciones
  Future<void> scheduleAllNotifications() async {
    if (_morningEnabled) await _scheduleMorningNotification();
    if (_nightEnabled) await _scheduleNightNotification();
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

      final details = NotificationDetails(
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
        androidAllowWhileIdle: true,
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
}
