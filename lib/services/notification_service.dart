import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../data/bible_verses.dart';
import 'user_pref_cloud_sync_service.dart';
import 'victory_scoring_service.dart';

/// Servicio de notificaciones para recordatorios diarios.
/// Usa flutter_local_notifications con timezone para scheduling recurrente.
class NotificationService {
  static const String _morningEnabledKey = 'morning_notification_enabled';
  static const String _morningTimeKey = 'morning_notification_time';
  static const String _nightEnabledKey = 'night_notification_enabled';
  static const String _nightTimeKey = 'night_notification_time';
  static const String _emergencyReminderKey = 'emergency_reminder_enabled';
  static const String _victoryReminderKey = 'victory_reminder_enabled';
  static const String _victoryReminderTimesKey = 'victory_reminder_times';
  static const String _reengagementKey = 'reengagement_enabled';
  static const List<int> _defaultVictoryReminderMinutes = <int>[
    18 * 60,
    22 * 60,
  ];
  static const int _maxVictoryReminderSlots = 6;

  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Configuración por defecto
  TimeOfDay _morningTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _nightTime = const TimeOfDay(hour: 21, minute: 0);
  List<TimeOfDay> _victoryReminderTimes = <TimeOfDay>[
    const TimeOfDay(hour: 18, minute: 0),
    const TimeOfDay(hour: 22, minute: 0),
  ];
  bool _morningEnabled = true;
  bool _nightEnabled = true;
  bool _emergencyReminderEnabled = true;
  bool _victoryReminderEnabled = true;
  bool _reengagementEnabled = true;

  // Notificaciones locales
  final FlutterLocalNotificationsPlugin _flnp =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  /// Último payload tappeado. Lo observa `main.dart` para hacer deep-link
  /// a la pantalla correspondiente cuando el usuario abre la app desde una
  /// notificación (tanto en foreground como cold-start).
  static final ValueNotifier<String?> lastTapPayload = ValueNotifier<String?>(
    null,
  );

  /// Payloads conocidos (mantener sincronizados con el router).
  static const String payloadMorning = 'route:devotional';
  static const String payloadNight = 'route:journal';
  static const String payloadVictory = 'route:victory';
  static const String payloadReengagement = 'route:home';
  static const String payloadPlanPrefix = 'route:plan:';
  static const String payloadBattleInvite = 'route:battle_invite';
  static const String payloadBattleMessage = 'route:battle_message';
  static const String payloadBattleSos = 'route:battle_sos';

  /// Se alterna a `true` mientras el usuario esté viendo la pantalla de
  /// Compañero de Batalla. Si es `true`, suprimimos notificaciones locales
  /// de invitaciones / mensajes porque la UI ya los muestra reactivamente
  /// (evita ruido duplicado). Lo controla el propio `BattlePartnerScreen`.
  static final ValueNotifier<bool> isViewingBattlePartner = ValueNotifier<bool>(
    false,
  );

  // Getters
  TimeOfDay get morningTime => _morningTime;
  TimeOfDay get nightTime => _nightTime;
  List<TimeOfDay> get victoryReminderTimes =>
      List.unmodifiable(_victoryReminderTimes);
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

  /// Recargar solo preferencias ya restauradas desde cloud.
  Future<void> reloadSettings() => _loadSettings();

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

    final victoryMinutes = prefs
        .getStringList(_victoryReminderTimesKey)
        ?.map(int.tryParse)
        .whereType<int>()
        .toList(growable: false);
    _victoryReminderTimes = _timesFromMinutes(
      victoryMinutes == null || victoryMinutes.isEmpty
          ? _defaultVictoryReminderMinutes
          : victoryMinutes,
    );
  }

  Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;
    try {
      tz.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      // iOS/macOS: no solicitamos permisos en init; se piden explícitamente
      // cuando el usuario activa notificaciones (requestPermissions()).
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const init = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );
      await _flnp.initialize(
        init,
        onDidReceiveNotificationResponse: _handleNotificationTap,
      );
      await _createAndroidChannels();

      // Cold-start: si la app fue abierta desde una notificación cuando
      // estaba cerrada, recuperar el payload inicial.
      try {
        final launch = await _flnp.getNotificationAppLaunchDetails();
        final payload = launch?.notificationResponse?.payload;
        if (launch?.didNotificationLaunchApp == true &&
            payload != null &&
            payload.isNotEmpty) {
          lastTapPayload.value = payload;
        }
      } catch (_) {}

      _notificationsInitialized = true;
    } catch (e) {
      debugPrint('⚠️ No se pudo inicializar notificaciones locales: $e');
      _notificationsInitialized = false;
    }
  }

  Future<void> _createAndroidChannels() async {
    final androidImpl = _flnp
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl == null) return;

    const channels = [
      AndroidNotificationChannel(
        'battle_partner_invites',
        'Solicitudes de compañero',
        description: 'Avisa cuando alguien quiere ser tu compañero de batalla',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'battle_partner_messages',
        'Mensajes de compañeros',
        description: 'Ánimos y oraciones de tus compañeros de batalla',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'battle_partner_sos',
        'SOS de oración',
        description: 'Alerta cuando un compañero pide oración urgente',
        importance: Importance.max,
      ),
    ];

    for (final channel in channels) {
      await androidImpl.createNotificationChannel(channel);
    }
  }

  /// Handler global de taps en notificaciones (foreground/background).
  /// Solo publica el payload; la navegación la resuelve un listener en
  /// `main.dart` con acceso al `navigatorKey`.
  static void _handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    debugPrint('🔔 Notification tap payload: $payload');
    lastTapPayload.value = payload;
  }

  /// Guardar configuración
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_morningEnabledKey, _morningEnabled);
    await prefs.setBool(_nightEnabledKey, _nightEnabled);
    await prefs.setBool(_emergencyReminderKey, _emergencyReminderEnabled);
    await prefs.setBool(_victoryReminderKey, _victoryReminderEnabled);
    await prefs.setBool(_reengagementKey, _reengagementEnabled);
    await prefs.setInt(
      _morningTimeKey,
      _morningTime.hour * 60 + _morningTime.minute,
    );
    await prefs.setInt(_nightTimeKey, _nightTime.hour * 60 + _nightTime.minute);
    await prefs.setStringList(
      _victoryReminderTimesKey,
      _victoryReminderTimes
          .map((time) => _minutesOfDay(time).toString())
          .toList(),
    );
    UserPrefCloudSyncService.I.markDirty();
  }

  /// Solicitar permisos (Android 13+/iOS)
  Future<bool> requestPermissions() async {
    try {
      if (!_notificationsInitialized) await _initNotifications();
      final androidImpl = _flnp
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final iosImpl = _flnp
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final macosImpl = _flnp
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();

      final androidOk = await androidImpl?.requestNotificationsPermission();
      final iosOk = await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final macOk = await macosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Al menos una plataforma respondió true (o la actual no aplica y
      // asumimos true). Si todas son null, no hay impl; damos true.
      if (androidOk == null && iosOk == null && macOk == null) return true;
      return (androidOk ?? false) || (iosOk ?? false) || (macOk ?? false);
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

  /// Actualizar las horas de recordatorio para cerrar el día de victoria.
  Future<void> setVictoryReminderTimes(List<TimeOfDay> times) async {
    _victoryReminderTimes = _normalizeVictoryReminderTimes(times);
    await _saveSettings();
    if (_victoryReminderEnabled) {
      await _scheduleVictoryReminders();
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
  static const int _legacyVictoryReminderId = 1003;
  static const int _reengagementId = 1004;
  static const int _victoryReminderBaseId = 1100;

  /// Calcular próxima hora de disparo
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  TimeOfDay _timeFromMinutes(int minutes) {
    final safe = minutes.clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: safe ~/ 60, minute: safe % 60);
  }

  List<TimeOfDay> _timesFromMinutes(Iterable<int> minutes) {
    return _normalizeVictoryReminderTimes(minutes.map(_timeFromMinutes));
  }

  List<TimeOfDay> _normalizeVictoryReminderTimes(Iterable<TimeOfDay> times) {
    final minutes = times.map(_minutesOfDay).toSet().toList()..sort();
    final limited = minutes.take(_maxVictoryReminderSlots);
    final normalized = limited.map(_timeFromMinutes).toList(growable: false);
    if (normalized.isEmpty) {
      return _timesFromMinutes(_defaultVictoryReminderMinutes.take(1));
    }
    return normalized;
  }

  Future<bool> _hasRegisteredToday() async {
    try {
      if (!VictoryScoringService.I.isInitialized) {
        await VictoryScoringService.I.init();
      }
      return VictoryScoringService.I.hasDataForToday();
    } catch (_) {
      return false;
    }
  }

  Future<tz.TZDateTime> _nextVictoryReminderInstance(
    TimeOfDay time, {
    bool skipToday = false,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final hasRegisteredToday = skipToday || await _hasRegisteredToday();
    final isToday =
        scheduled.year == now.year &&
        scheduled.month == now.month &&
        scheduled.day == now.day;
    if (!scheduled.isAfter(now) || (hasRegisteredToday && isToday)) {
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
      final body =
          '🌅 "${verse.verse.substring(0, verse.verse.length > 80 ? 80 : verse.verse.length)}..." — ${verse.reference}';
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_reminders',
          'Recordatorio matutino',
          channelDescription: 'Versículo y motivación cada mañana',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      );
      await _flnp.zonedSchedule(
        _morningNotificationId,
        'Buenos días, guerrero',
        body,
        _nextInstanceOfTime(_morningTime),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payloadMorning,
      );
      debugPrint(
        '🔔 Notificación matutina programada: ${_morningTime.hour}:${_morningTime.minute.toString().padLeft(2, '0')}',
      );
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
        iOS: DarwinNotificationDetails(presentSound: true),
      );
      await _flnp.zonedSchedule(
        _nightNotificationId,
        '¿Cómo estuvo tu día?',
        '🌙 Recuerda registrar tu progreso antes de dormir.',
        _nextInstanceOfTime(_nightTime),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payloadNight,
      );
      debugPrint(
        '🔔 Notificación nocturna programada: ${_nightTime.hour}:${_nightTime.minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      debugPrint('⚠️ Error programando notificación nocturna: $e');
    }
  }

  /// Cancela la notificación de re-engagement programada. Llamar en logout
  /// para que el siguiente usuario no reciba la notificación del anterior.
  Future<void> cancelReengagementNotification() async {
    try {
      await _flnp.cancel(_reengagementId);
    } catch (_) {}
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
    if (_morningEnabled) {
      await _scheduleMorningNotification();
    } else {
      await _cancelMorningNotification();
    }
    if (_nightEnabled) {
      await _scheduleNightNotification();
    } else {
      await _cancelNightNotification();
    }
    if (_victoryReminderEnabled) {
      await _scheduleVictoryReminders();
    } else {
      await _cancelVictoryReminders();
    }
    if (_reengagementEnabled) {
      await _scheduleReengagement();
    } else {
      await _flnp.cancel(_reengagementId);
    }
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
        while (scheduled.weekday == DateTime.saturday ||
            scheduled.weekday == DateTime.sunday) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'plan_reminders',
          'Recordatorios de Plan',
          channelDescription:
              'Recordatorios diarios para planes personalizados',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      );

      await _flnp.zonedSchedule(
        _planNotificationId(planId),
        title ?? 'Continúa tu plan',
        body ?? 'Tu sesión de hoy está lista.',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '$payloadPlanPrefix$planId',
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
      await _scheduleVictoryReminders();
    } else {
      await _cancelVictoryReminders();
    }
  }

  /// Programar recordatorios diarios para registrar victoria.
  Future<void> _scheduleVictoryReminders({bool skipToday = false}) async {
    if (!_notificationsInitialized) await _initNotifications();
    if (!_notificationsInitialized) return;
    try {
      await _cancelVictoryReminders();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'victory_reminder',
          'Recordatorio de victoria',
          channelDescription: 'Te recuerda registrar tu victoria diaria',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      );
      for (var i = 0; i < _victoryReminderTimes.length; i++) {
        final time = _victoryReminderTimes[i];
        final scheduled = await _nextVictoryReminderInstance(
          time,
          skipToday: skipToday,
        );
        await _flnp.zonedSchedule(
          _victoryReminderBaseId + i,
          '¿Hoy fue día de victoria?',
          '⚔️ Toma un momento para cerrar tu día y registrar victoria o gracia.',
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payloadVictory,
        );
        debugPrint(
          '🔔 Recordatorio de victoria programado: ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error programando recordatorio de victoria: $e');
    }
  }

  Future<void> _cancelVictoryReminders() async {
    try {
      await _flnp.cancel(_legacyVictoryReminderId);
      for (var i = 0; i < _maxVictoryReminderSlots; i++) {
        await _flnp.cancel(_victoryReminderBaseId + i);
      }
    } catch (e) {
      debugPrint('⚠️ Error cancelando recordatorios de victoria: $e');
    }
  }

  /// Cancelar el recordatorio de victoria (llamar cuando el usuario registra)
  Future<void> cancelVictoryReminderForToday() async {
    if (_victoryReminderEnabled) {
      await _scheduleVictoryReminders(skipToday: true);
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

      final scheduled = tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(hours: 48));

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
        iOS: DarwinNotificationDetails(presentSound: true),
      );
      await _flnp.zonedSchedule(
        _reengagementId,
        'Te extrañamos, guerrero',
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payloadReengagement,
      );
      debugPrint('🔔 Re-engagement programado para: $scheduled');
    } catch (e) {
      debugPrint('⚠️ Error programando re-engagement: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COMPAÑERO DE BATALLA — notificaciones event-driven (no programadas)
  // ═══════════════════════════════════════════════════════════════════════

  /// Notifica en el dispositivo una nueva solicitud de compañero de batalla.
  /// Si el usuario está actualmente en `BattlePartnerScreen`, se omite para
  /// evitar duplicar el feedback visual.
  Future<void> showBattlePartnerInvite({
    required int id,
    required String fromName,
  }) async {
    if (isViewingBattlePartner.value) return;
    if (!_notificationsInitialized) await _initNotifications();
    if (!_notificationsInitialized) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'battle_partner_invites',
          'Solicitudes de compañero',
          channelDescription:
              'Avisa cuando alguien quiere ser tu compañero de batalla',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          category: AndroidNotificationCategory.social,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      );
      await _flnp.show(
        id,
        'Nueva solicitud de compañero 🤝',
        '$fromName quiere acompañarte en la batalla',
        details,
        payload: payloadBattleInvite,
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo mostrar notificación de invitación: $e');
    }
  }

  /// Notifica un nuevo mensaje/sticker de un compañero de batalla.
  /// `text` es el texto legible del sticker (ya traducido, incluyendo emoji).
  Future<void> showBattleMessage({
    required int id,
    required String fromName,
    required String text,
  }) async {
    if (isViewingBattlePartner.value) return;
    if (!_notificationsInitialized) await _initNotifications();
    if (!_notificationsInitialized) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'battle_partner_messages',
          'Mensajes de compañeros',
          channelDescription: 'Ánimos y oraciones de tus compañeros de batalla',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          category: AndroidNotificationCategory.message,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      );
      await _flnp.show(
        id,
        '$fromName te escribió 💬',
        text,
        details,
        payload: payloadBattleMessage,
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo mostrar notificación de mensaje: $e');
    }
  }

  /// Notificación urgente de SOS ("Oren por mí ahora") enviada por un
  /// compañero. Se salta la supresión por foreground porque el usuario
  /// DEBE ver este tipo de alerta aunque esté en la misma pantalla.
  Future<void> showBattleSos({
    required int id,
    required String fromName,
  }) async {
    if (!_notificationsInitialized) await _initNotifications();
    if (!_notificationsInitialized) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'battle_partner_sos',
          'SOS de oración',
          channelDescription: 'Alerta cuando un compañero pide oración urgente',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          fullScreenIntent: false,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );
      await _flnp.show(
        id,
        '$fromName necesita oración ahora 🆘',
        'Detente un momento y ora por tu compañero',
        details,
        payload: payloadBattleSos,
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo mostrar notificación SOS: $e');
    }
  }
}
