import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_verses.dart';
import '../models/sacred_alarm.dart';
import 'user_pref_cloud_sync_service.dart';

class SacredAlarmService {
  SacredAlarmService._();
  static final SacredAlarmService I = SacredAlarmService._();

  static const String _configKey = 'sacred_alarm_config_v1';
  static const String _eventsKey = 'sacred_alarm_events_v1';
  static const MethodChannel _channel = MethodChannel('victoria/sacred_alarms');

  final ValueNotifier<SacredAlarmConfig> config = ValueNotifier(const SacredAlarmConfig());
  final ValueNotifier<List<SacredAlarmEvent>> scheduledEvents = ValueNotifier(const []);
  final ValueNotifier<List<SacredAlarmEvent>> todayEvents = ValueNotifier(const []);
  final ValueNotifier<SacredAlarmEvent?> activeEvent = ValueNotifier(null);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _load();
    _initialized = true;
    if (config.value.enabled) {
      await ensureUpcomingSchedule(force: _needsScheduleRepair());
    }
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _initialized = false;
    config.value = const SacredAlarmConfig();
    scheduledEvents.value = const [];
    todayEvents.value = const [];
    activeEvent.value = null;
  }

  Future<bool> setEnabled(bool enabled) async {
    await init();
    if (!enabled && hasActiveCommitmentLock()) {
      return false;
    }
    config.value = config.value.copyWith(enabled: enabled);
    await _saveConfig();
    if (enabled) {
      await ensureUpcomingSchedule(force: _realTodayEvents().length < config.value.randomCount);
    } else {
      scheduledEvents.value = const [];
      todayEvents.value = const [];
      activeEvent.value = null;
      await _saveEvents();
      await _cancelNativeAlarms();
    }
    return true;
  }

  Future<bool> updateConfig(SacredAlarmConfig nextConfig) async {
    await init();
    final previous = config.value;
    if (previous.enabled && previous.strictMode && hasActiveCommitmentLock()) {
      if (!nextConfig.enabled || !nextConfig.strictMode) {
        return false;
      }
    }
    config.value = _sanitizeConfig(nextConfig);
    await _saveConfig();

    if (!config.value.enabled) {
      scheduledEvents.value = const [];
      todayEvents.value = const [];
      activeEvent.value = null;
      await _saveEvents();
      await _cancelNativeAlarms();
      return true;
    }

    await ensureUpcomingSchedule(force: true);
    return true;
  }

  Future<List<SacredAlarmEvent>> ensureTodaySchedule({bool force = false}) async {
    await init();
    await ensureUpcomingSchedule(force: force);
    return todayEvents.value;
  }

  Future<List<SacredAlarmEvent>> ensureUpcomingSchedule({bool force = false}) async {
    await init();
    if (!config.value.enabled) {
      scheduledEvents.value = const [];
      todayEvents.value = const [];
      activeEvent.value = null;
      await _saveEvents();
      await _cancelNativeAlarms();
      return const [];
    }

    config.value = _sanitizeConfig(config.value);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowMs = now.millisecondsSinceEpoch;
    final existing = scheduledEvents.value.where((event) => !_isTestEvent(event)).toList();
    final rebuilt = <String, SacredAlarmEvent>{};

    for (final event in existing) {
      final keepActive = event.status == SacredAlarmEventStatus.ringing;
      final keepCompletedToday =
          event.dateIso == _dateIso(today) && event.status == SacredAlarmEventStatus.completed;
      final keepLockedFuture =
          !force &&
          config.value.strictMode &&
          event.locked &&
          event.status != SacredAlarmEventStatus.completed &&
          event.scheduledAtMs >= nowMs;
      if (keepActive || keepCompletedToday || keepLockedFuture) {
        rebuilt[event.id] = event;
      }
    }

    for (var offset = 0; offset < config.value.scheduleDaysAhead; offset++) {
      final date = today.add(Duration(days: offset));
      final dateIso = _dateIso(date);
      final existingForDate = existing.where((event) => event.dateIso == dateIso).toList();
      final keepDate = !force && existingForDate.isNotEmpty;
      final source = keepDate
          ? existingForDate
          : buildScheduleForDate(date: date, config: config.value);

      for (final event in source) {
        if (event.scheduledAtMs < nowMs && event.status == SacredAlarmEventStatus.scheduled) {
          continue;
        }
        rebuilt.putIfAbsent(event.id, () => event);
      }
    }

    final schedule = rebuilt.values.toList()
      ..sort((a, b) => a.scheduledAtMs.compareTo(b.scheduledAtMs));
    scheduledEvents.value = schedule;
    _refreshTodayEvents();
    await _saveEvents();
    await _scheduleNativeAlarms(scheduledEvents.value);
    return schedule;
  }

  Future<void> regenerateTomorrowPreview() async {
    await init();
    if (!config.value.enabled) return;
    await ensureUpcomingSchedule(force: true);
  }

  Future<SacredAlarmEvent> triggerTestAlarm() async {
    await init();
    final now = DateTime.now();
    final verse = BibleVerses.victoryVerses[now.second % BibleVerses.victoryVerses.length];
    final event = SacredAlarmEvent(
      id: 'test-${now.millisecondsSinceEpoch}',
      dateIso: _dateIso(now),
      scheduledAtMs: now.millisecondsSinceEpoch,
      activityType: SacredAlarmActivityType.meditation,
      verse: verse.verse,
      reference: verse.reference,
      status: SacredAlarmEventStatus.ringing,
      firedAtMs: now.millisecondsSinceEpoch,
      sourceType: 'test',
      sourceId: 'test',
    );
    await _upsertEvent(event);
    activeEvent.value = event;
    await _invokeNative(
      'startAlarmNow',
      event.toNativeJson(
        enforceMinimumVolume: config.value.enforceMinimumVolume,
        minimumVolumePercent: config.value.minimumVolumePercent,
      ),
    );
    return event;
  }

  Future<SacredAlarmEvent?> activateFromRoute(String? sessionId) async {
    await init();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final events = scheduledEvents.value.toList();
    int index;
    if (sessionId == null || sessionId.isEmpty) {
      // Sin sessionId: priorizar evento ya en ringing, luego cualquier
      // evento pasado reciente del dia que aun no este completado.
      index = events.indexWhere(
        (event) => event.status == SacredAlarmEventStatus.ringing,
      );
      if (index < 0) {
        index = events.indexWhere(
          (event) =>
              event.status != SacredAlarmEventStatus.completed &&
              event.scheduledAtMs <= nowMs,
        );
      }
      if (index < 0) {
        index = events.indexWhere(
          (event) => event.status != SacredAlarmEventStatus.completed,
        );
      }
    } else {
      index = events.indexWhere((event) => event.id == sessionId);
    }
    if (index < 0) {
      activeEvent.value = null;
      return null;
    }
    final event = events[index].copyWith(
      status: SacredAlarmEventStatus.ringing,
      firedAtMs: events[index].firedAtMs ?? nowMs,
    );
    events[index] = event;
    scheduledEvents.value = events..sort((a, b) => a.scheduledAtMs.compareTo(b.scheduledAtMs));
    _refreshTodayEvents();
    activeEvent.value = event;
    await _saveEvents();
    return event;
  }

  Future<void> completeActiveAlarm(String eventId) async {
    await init();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final events = scheduledEvents.value.toList();
    final index = events.indexWhere((event) => event.id == eventId);
    if (index >= 0) {
      if (_isTestEvent(events[index])) {
        events.removeAt(index);
      } else {
        events[index] = events[index].copyWith(
          status: SacredAlarmEventStatus.completed,
          completedAtMs: nowMs,
        );
      }
      scheduledEvents.value = events..sort((a, b) => a.scheduledAtMs.compareTo(b.scheduledAtMs));
      _refreshTodayEvents();
      await _saveEvents();
    }
    activeEvent.value = null;
    await _invokeNative('stopAlarm', {'sessionId': eventId});
    await _scheduleNativeAlarms(scheduledEvents.value);
  }

  Future<bool> isExactAlarmAllowed() async {
    final result = await _invokeNative('isExactAlarmAllowed');
    return result == true;
  }

  /// Detiene cualquier alarma sagrada que este sonando en el lado nativo,
  /// sin requerir un eventId (util como red de seguridad cuando la sesion
  /// quedo huerfana en SharedPreferences).
  Future<void> stopAnyRingingAlarm() async {
    activeEvent.value = null;
    await _invokeNative('stopAlarm', {'sessionId': null});
  }
  Future<void> openExactAlarmSettings() async {
    await _invokeNative('openExactAlarmSettings');
  }

  bool hasActiveCommitmentLock() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return scheduledEvents.value.any(
      (event) =>
          !_isTestEvent(event) &&
          event.locked &&
          event.status != SacredAlarmEventStatus.completed &&
          event.scheduledAtMs >= nowMs,
    );
  }

  List<SacredAlarmEvent> upcomingEvents() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return scheduledEvents.value
        .where(
          (event) =>
              event.scheduledAtMs >= nowMs && event.status == SacredAlarmEventStatus.scheduled,
        )
        .toList()
      ..sort((a, b) => a.scheduledAtMs.compareTo(b.scheduledAtMs));
  }

  static List<SacredAlarmEvent> buildScheduleForDate({
    required DateTime date,
    required SacredAlarmConfig config,
    Random? random,
    List<BibleVerse>? verses,
  }) {
    final sanitized = _sanitizeConfig(config);
    final rng = random ?? Random.secure();
    final dateIso = _dateIso(date);
    final selectedVerses = verses ?? BibleVerses.allVerses;
    final activities = sanitized.activities.isEmpty
        ? SacredAlarmActivityType.values
        : sanitized.activities;
    final slots = <_ScheduleSlot>[];

    for (final rule in sanitized.fixedRules) {
      if (!rule.matchesDate(date)) continue;
      slots.add(
        _ScheduleSlot(
          minute: rule.minuteOfDay,
          sourceType: 'fixed',
          sourceId: rule.id,
          activityType: rule.activityType,
        ),
      );
    }

    final fixedMinutes = slots.map((slot) => slot.minute).toList();
    final randomMinutes = sanitized.randomMode
        ? _pickRandomMinutes(sanitized, rng, blockedMinutes: fixedMinutes)
        : _pickFixedSpreadMinutes(sanitized, blockedMinutes: fixedMinutes);
    for (var index = 0; index < randomMinutes.length; index++) {
      final minute = randomMinutes[index];
      slots.add(
        _ScheduleSlot(minute: minute, sourceType: 'random', sourceId: 'random-$index-$minute'),
      );
    }

    slots.sort((a, b) => a.minute.compareTo(b.minute));

    final shuffledActivities = activities.toList()..shuffle(rng);
    final shuffledVerses = selectedVerses.toList()..shuffle(rng);

    return List<SacredAlarmEvent>.generate(slots.length, (index) {
      final slot = slots[index];
      final minute = slot.minute;
      final scheduled = DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60);
      final activity = slot.activityType ?? shuffledActivities[index % shuffledActivities.length];
      final verse = shuffledVerses[index % shuffledVerses.length];
      return SacredAlarmEvent(
        id: '$dateIso-${slot.sourceType}-${slot.sourceId}',
        dateIso: dateIso,
        scheduledAtMs: scheduled.millisecondsSinceEpoch,
        activityType: activity,
        verse: verse.verse,
        reference: verse.reference,
        sourceType: slot.sourceType,
        sourceId: slot.sourceId,
      );
    });
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    config.value = _sanitizeConfig(SacredAlarmConfig.decode(prefs.getString(_configKey)));
    if (!config.value.enabled) {
      scheduledEvents.value = const [];
      todayEvents.value = const [];
      activeEvent.value = null;
      await _saveEvents();
      await _cancelNativeAlarms();
      return;
    }
    final events = SacredAlarmEvent.decodeList(prefs.getString(_eventsKey));
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cutoff = DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
    // Si una alarma sono mientras la app estaba cerrada, el codigo nativo no
    // pudo actualizar su estado en SharedPreferences. Cuando el usuario abre
    // la app (por ejemplo desde la notificacion), promovemos los eventos
    // pasados recientes a "ringing" para que la pantalla de Campana Sagrada
    // los pueda recuperar y permitir apagarlos.
    final ringingWindowMs =
        nowMs - const Duration(hours: 4).inMilliseconds;
    final restored = events.where((event) => event.scheduledAtMs >= cutoff).map((event) {
      if (event.status == SacredAlarmEventStatus.scheduled &&
          event.scheduledAtMs < nowMs &&
          event.scheduledAtMs >= ringingWindowMs &&
          !_isTestEvent(event)) {
        return event.copyWith(
          status: SacredAlarmEventStatus.ringing,
          firedAtMs: event.firedAtMs ?? event.scheduledAtMs,
        );
      }
      return event;
    }).toList()..sort((a, b) => a.scheduledAtMs.compareTo(b.scheduledAtMs));
    scheduledEvents.value = restored;
    _refreshTodayEvents();
    activeEvent.value = todayEvents.value.where((event) => event.isActive).firstOrNull;
    // Persistimos los cambios de estado para que un siguiente arranque vea
    // la promocion ya aplicada.
    await prefs.setString(_eventsKey, SacredAlarmEvent.encodeList(scheduledEvents.value));
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, config.value.encode());
    UserPrefCloudSyncService.I.markDirty();
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventsKey, SacredAlarmEvent.encodeList(scheduledEvents.value));
    UserPrefCloudSyncService.I.markDirty();
  }

  Future<void> _upsertEvent(SacredAlarmEvent event) async {
    final events = scheduledEvents.value.toList();
    final index = events.indexWhere((item) => item.id == event.id);
    if (index >= 0) {
      events[index] = event;
    } else {
      events.add(event);
    }
    scheduledEvents.value = events..sort((a, b) => a.scheduledAtMs.compareTo(b.scheduledAtMs));
    _refreshTodayEvents();
    await _saveEvents();
  }

  List<SacredAlarmEvent> _realTodayEvents() {
    final today = _dateIso(DateTime.now());
    return scheduledEvents.value
        .where((event) => event.dateIso == today && !_isTestEvent(event))
        .toList();
  }

  void _refreshTodayEvents() {
    final today = _dateIso(DateTime.now());
    todayEvents.value = scheduledEvents.value.where((event) => event.dateIso == today).toList()
      ..sort((a, b) => a.scheduledAtMs.compareTo(b.scheduledAtMs));
  }

  static bool _isTestEvent(SacredAlarmEvent event) => event.id.startsWith('test-');

  bool _needsScheduleRepair() {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final horizon = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: config.value.scheduleDaysAhead)).millisecondsSinceEpoch;
    final futureScheduled = scheduledEvents.value.where(
      (event) =>
          !_isTestEvent(event) &&
          event.status == SacredAlarmEventStatus.scheduled &&
          event.scheduledAtMs >= nowMs,
    );
    final hasEventsOutsideHorizon = futureScheduled.any((event) => event.scheduledAtMs >= horizon);
    if (hasEventsOutsideHorizon) return true;

    final hasRandomEventsWhenDisabled =
        config.value.randomCount == 0 &&
        futureScheduled.any((event) => event.sourceType == 'random');
    if (hasRandomEventsWhenDisabled) return true;

    final enabledFixedRuleCount = config.value.fixedRules.where((rule) => rule.enabled).length;
    final maxExpected =
        config.value.scheduleDaysAhead * (config.value.randomCount + enabledFixedRuleCount);
    return futureScheduled.length > maxExpected;
  }

  Future<void> _scheduleNativeAlarms(List<SacredAlarmEvent> events) async {
    if (!config.value.enabled) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final nativeEvents = events
        .where(
          (event) =>
              event.scheduledAtMs >= nowMs && event.status == SacredAlarmEventStatus.scheduled,
        )
        .map(
          (event) => event.toNativeJson(
            enforceMinimumVolume: config.value.enforceMinimumVolume,
            minimumVolumePercent: config.value.minimumVolumePercent,
          ),
        )
        .toList();
    await _invokeNative('scheduleAlarms', {'alarms': nativeEvents});
  }

  Future<void> _cancelNativeAlarms() async {
    await _invokeNative('cancelAlarms');
  }

  Future<dynamic> _invokeNative(String method, [dynamic arguments]) async {
    try {
      return await _channel.invokeMethod(method, arguments);
    } on MissingPluginException {
      debugPrint('🔔 [SACRED_ALARMS] Native bridge unavailable for $method');
      return null;
    } catch (e, st) {
      debugPrint('🔔 [SACRED_ALARMS] Native bridge error $method: $e\n$st');
      return null;
    }
  }

  static SacredAlarmConfig _sanitizeConfig(SacredAlarmConfig config) {
    final start = config.startMinute.clamp(0, 23 * 60 + 45).toInt();
    final end = config.endMinute.clamp(start + 60, 24 * 60 - 1).toInt();
    final windows = _normalizeWindows(config.effectiveWindows);
    final rules =
        config.fixedRules
            .map((rule) {
              final weekdays =
                  rule.weekdays.where((weekday) => weekday >= 1 && weekday <= 7).toSet().toList()
                    ..sort();
              return rule.copyWith(
                minuteOfDay: rule.minuteOfDay.clamp(0, 24 * 60 - 1).toInt(),
                weekdays: weekdays,
              );
            })
            .where((rule) => rule.weekdays.isNotEmpty)
            .toList()
          ..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
    return config.copyWith(
      startMinute: start,
      endMinute: end,
      randomCount: config.randomCount.clamp(0, 24).toInt(),
      minGapMinutes: config.minGapMinutes.clamp(15, 240).toInt(),
      activities: config.activities.isEmpty ? SacredAlarmActivityType.values : config.activities,
      windows: windows,
      fixedRules: rules,
      minimumVolumePercent: config.minimumVolumePercent.clamp(30, 100).toInt(),
      scheduleDaysAhead: config.scheduleDaysAhead.clamp(1, 45).toInt(),
    );
  }

  static List<int> _pickRandomMinutes(
    SacredAlarmConfig config,
    Random rng, {
    List<int> blockedMinutes = const [],
  }) {
    if (config.randomCount <= 0) return const [];
    final selected = <int>[];
    final candidates = _allWindowMinutes(config.windows);
    if (candidates.isEmpty) return const [];
    final blocked = blockedMinutes.toSet();
    final targetCount = min(config.randomCount, candidates.length);

    for (var attempts = 0; selected.length < targetCount && attempts < 1200; attempts++) {
      final candidate = candidates[rng.nextInt(candidates.length)];
      final hasGap = [
        ...selected,
        ...blocked,
      ].every((minute) => (minute - candidate).abs() >= config.minGapMinutes);
      if (hasGap) selected.add(candidate);
    }

    if (selected.length < targetCount) {
      return _pickFixedSpreadMinutes(config, blockedMinutes: blockedMinutes);
    }
    selected.sort();
    return selected;
  }

  static List<int> _pickFixedSpreadMinutes(
    SacredAlarmConfig config, {
    List<int> blockedMinutes = const [],
  }) {
    final blocked = blockedMinutes.toSet();
    final candidates = _allWindowMinutes(
      config.windows,
    ).where((minute) => !blocked.contains(minute)).toList();
    final count = min(config.randomCount, candidates.length);
    if (count <= 0) return const [];
    if (count == 1) return [candidates[(candidates.length / 2).floor()]];
    return List<int>.generate(count, (index) {
      final position = (index * (candidates.length - 1) / (count - 1)).round();
      return candidates[position];
    });
  }

  static List<SacredAlarmWindow> _normalizeWindows(List<SacredAlarmWindow> source) {
    final normalized = source.map((window) {
      final start = window.startMinute.clamp(0, 24 * 60 - 2).toInt();
      final end = window.endMinute.clamp(start + 1, 24 * 60 - 1).toInt();
      return window.copyWith(startMinute: start, endMinute: end);
    }).toList()..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    if (normalized.isEmpty) {
      return const [SacredAlarmWindow(id: 'default', startMinute: 7 * 60, endMinute: 22 * 60)];
    }
    return normalized;
  }

  static List<int> _allWindowMinutes(List<SacredAlarmWindow> windows) {
    final minutes = <int>{};
    for (final window in windows) {
      for (var minute = window.startMinute; minute <= window.endMinute; minute++) {
        minutes.add(minute);
      }
    }
    return minutes.toList()..sort();
  }

  static String _dateIso(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _ScheduleSlot {
  final int minute;
  final String sourceType;
  final String sourceId;
  final SacredAlarmActivityType? activityType;

  const _ScheduleSlot({
    required this.minute,
    required this.sourceType,
    required this.sourceId,
    this.activityType,
  });
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
