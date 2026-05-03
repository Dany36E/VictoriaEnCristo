import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:app_quitar/data/bible_verses.dart';
import 'package:app_quitar/models/sacred_alarm.dart';
import 'package:app_quitar/services/sacred_alarm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _configKey = 'sacred_alarm_config_v1';
const String _eventsKey = 'sacred_alarm_events_v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SacredAlarmService.I.resetForTesting();
  });

  tearDown(() async {
    await SacredAlarmService.I.resetForTesting();
  });

  group('SacredAlarmService schedule builder', () {
    test('genera tres horarios aleatorios dentro de la ventana configurada', () {
      const config = SacredAlarmConfig(
        enabled: true,
        startMinute: 8 * 60,
        endMinute: 20 * 60,
        randomCount: 3,
        minGapMinutes: 90,
        activities: [
          SacredAlarmActivityType.prayer,
          SacredAlarmActivityType.worship,
          SacredAlarmActivityType.meditation,
        ],
      );

      final events = SacredAlarmService.buildScheduleForDate(
        date: DateTime(2026, 4, 29),
        config: config,
        random: Random(7),
        verses: BibleVerses.victoryVerses,
      );

      expect(events, hasLength(3));
      expect(events.map((event) => event.dateIso).toSet(), {'2026-04-29'});
      for (final event in events) {
        final minute = event.scheduledAt.hour * 60 + event.scheduledAt.minute;
        expect(minute, inInclusiveRange(config.startMinute, config.endMinute));
        expect(event.status, SacredAlarmEventStatus.scheduled);
        expect(event.locked, isTrue);
        expect(event.verse, isNotEmpty);
        expect(event.reference, isNotEmpty);
      }
    });

    test('respeta separacion minima entre campanas cuando la ventana lo permite', () {
      const config = SacredAlarmConfig(
        enabled: true,
        startMinute: 7 * 60,
        endMinute: 22 * 60,
        randomCount: 3,
        minGapMinutes: 120,
      );

      final events = SacredAlarmService.buildScheduleForDate(
        date: DateTime(2026, 4, 29),
        config: config,
        random: Random(12),
      );
      final minutes = events
          .map((event) => event.scheduledAt.hour * 60 + event.scheduledAt.minute)
          .toList();

      for (var i = 1; i < minutes.length; i++) {
        expect(minutes[i] - minutes[i - 1], greaterThanOrEqualTo(120));
      }
    });

    test('usa distribucion estable si la ventana es muy estrecha', () {
      const config = SacredAlarmConfig(
        enabled: true,
        startMinute: 10 * 60,
        endMinute: 11 * 60,
        randomCount: 3,
        minGapMinutes: 90,
      );

      final events = SacredAlarmService.buildScheduleForDate(
        date: DateTime(2026, 4, 29),
        config: config,
        random: Random(1),
      );
      final minutes = events
          .map((event) => event.scheduledAt.hour * 60 + event.scheduledAt.minute)
          .toList();

      expect(minutes, orderedEquals([600, 630, 660]));
    });

    test('genera horarios fijos repetitivos por dias de semana', () {
      const config = SacredAlarmConfig(
        enabled: true,
        randomCount: 0,
        fixedRules: [
          SacredAlarmFixedRule(id: 'mar-jue-1915', minuteOfDay: 19 * 60 + 15, weekdays: [2, 4]),
          SacredAlarmFixedRule(id: 'mar-jue-1930', minuteOfDay: 19 * 60 + 30, weekdays: [2, 4]),
          SacredAlarmFixedRule(id: 'mar-jue-2100', minuteOfDay: 21 * 60, weekdays: [2, 4]),
          SacredAlarmFixedRule(id: 'mar-jue-2115', minuteOfDay: 21 * 60 + 15, weekdays: [2, 4]),
        ],
      );

      final tuesdayEvents = SacredAlarmService.buildScheduleForDate(
        date: DateTime(2026, 4, 28),
        config: config,
        random: Random(2),
      );
      final wednesdayEvents = SacredAlarmService.buildScheduleForDate(
        date: DateTime(2026, 4, 29),
        config: config,
        random: Random(2),
      );

      expect(
        tuesdayEvents.map((event) => event.scheduledAt.hour * 60 + event.scheduledAt.minute),
        orderedEquals([1155, 1170, 1260, 1275]),
      );
      expect(tuesdayEvents.map((event) => event.sourceType).toSet(), {'fixed'});
      expect(wednesdayEvents, isEmpty);
    });

    test('limita momentos aleatorios a varias ventanas separadas', () {
      const config = SacredAlarmConfig(
        enabled: true,
        randomCount: 8,
        minGapMinutes: 15,
        windows: [
          SacredAlarmWindow(id: 'manana', startMinute: 7 * 60, endMinute: 8 * 60),
          SacredAlarmWindow(id: 'noche', startMinute: 19 * 60, endMinute: 21 * 60 + 15),
        ],
      );

      final events = SacredAlarmService.buildScheduleForDate(
        date: DateTime(2026, 4, 29),
        config: config,
        random: Random(44),
      );

      expect(events, hasLength(8));
      for (final event in events) {
        final minute = event.scheduledAt.hour * 60 + event.scheduledAt.minute;
        final inMorning = minute >= 7 * 60 && minute <= 8 * 60;
        final inNight = minute >= 19 * 60 && minute <= 21 * 60 + 15;
        expect(inMorning || inNight, isTrue);
        expect(minute > 8 * 60 && minute < 19 * 60, isFalse);
      }
    });
  });

  group('SacredAlarmService schedule persistence', () {
    test('reemplaza campanas futuras al cambiar configuracion en vez de acumularlas', () async {
      final service = SacredAlarmService.I;

      await service.updateConfig(
        const SacredAlarmConfig(
          enabled: true,
          randomCount: 3,
          minGapMinutes: 15,
          scheduleDaysAhead: 4,
          windows: [SacredAlarmWindow(id: 'manana', startMinute: 7 * 60, endMinute: 8 * 60)],
        ),
      );
      final firstSchedule = service.upcomingEvents();
      expect(firstSchedule, isNotEmpty);
      expect(firstSchedule.length, lessThanOrEqualTo(12));

      await service.updateConfig(
        const SacredAlarmConfig(
          enabled: true,
          randomCount: 1,
          minGapMinutes: 15,
          scheduleDaysAhead: 4,
          windows: [SacredAlarmWindow(id: 'noche', startMinute: 22 * 60, endMinute: 23 * 60)],
        ),
      );
      final secondSchedule = service.upcomingEvents();

      expect(secondSchedule.length, lessThanOrEqualTo(4));
      expect(service.scheduledEvents.value.length, secondSchedule.length);
      for (final event in secondSchedule) {
        final minute = event.scheduledAt.hour * 60 + event.scheduledAt.minute;
        expect(minute, inInclusiveRange(22 * 60, 23 * 60));
      }
    });

    test('elimina campanas aleatorias persistidas cuando randomCount queda en cero', () async {
      final staleEvents = List<SacredAlarmEvent>.generate(
        30,
        (index) => _futureEvent(id: 'stale-random-$index', dayOffset: (index % 20) + 1),
      );
      SharedPreferences.setMockInitialValues({
        _configKey: const SacredAlarmConfig(enabled: true, randomCount: 0).encode(),
        _eventsKey: SacredAlarmEvent.encodeList(staleEvents),
      });
      await SacredAlarmService.I.resetForTesting();

      await SacredAlarmService.I.init();

      expect(SacredAlarmService.I.scheduledEvents.value, isEmpty);
      expect(SacredAlarmService.I.upcomingEvents(), isEmpty);
    });

    test('ignora y limpia eventos guardados si Campanas Sagradas esta desactivado', () async {
      final staleEvent = _futureEvent(id: 'disabled-stale', dayOffset: 1);
      SharedPreferences.setMockInitialValues({
        _configKey: const SacredAlarmConfig(enabled: false).encode(),
        _eventsKey: SacredAlarmEvent.encodeList([staleEvent]),
      });
      await SacredAlarmService.I.resetForTesting();

      await SacredAlarmService.I.init();

      expect(SacredAlarmService.I.scheduledEvents.value, isEmpty);
      expect(SacredAlarmService.I.todayEvents.value, isEmpty);
      expect(SacredAlarmService.I.upcomingEvents(), isEmpty);
    });

    test('promueve a ringing una alarma reciente que sono mientras la app estaba cerrada', () async {
      final firedEvent = _pastEvent(id: 'fired-1', minutesAgo: 10);
      SharedPreferences.setMockInitialValues({
        _configKey: const SacredAlarmConfig(
          enabled: true,
          randomCount: 0,
          scheduleDaysAhead: 1,
        ).encode(),
        _eventsKey: SacredAlarmEvent.encodeList([firedEvent]),
      });
      await SacredAlarmService.I.resetForTesting();

      await SacredAlarmService.I.init();

      final recovered = SacredAlarmService.I.scheduledEvents.value
          .firstWhere((event) => event.id == 'fired-1');
      expect(recovered.status, SacredAlarmEventStatus.ringing);
      expect(recovered.firedAtMs, isNotNull);
    });

    test('activateFromRoute recupera un evento pasado reciente por sessionId', () async {
      final firedEvent = _pastEvent(id: 'tap-1', minutesAgo: 5);
      SharedPreferences.setMockInitialValues({
        _configKey: const SacredAlarmConfig(
          enabled: true,
          randomCount: 0,
          scheduleDaysAhead: 1,
        ).encode(),
        _eventsKey: SacredAlarmEvent.encodeList([firedEvent]),
      });
      await SacredAlarmService.I.resetForTesting();

      final activated = await SacredAlarmService.I.activateFromRoute('tap-1');

      expect(activated, isNotNull);
      expect(activated!.id, 'tap-1');
      expect(activated.status, SacredAlarmEventStatus.ringing);
      expect(SacredAlarmService.I.activeEvent.value?.id, 'tap-1');
    });

    test('activateFromRoute devuelve null si la alarma referida es muy antigua', () async {
      final ancient = _pastEvent(id: 'ancient', minutesAgo: 6 * 60);
      SharedPreferences.setMockInitialValues({
        _configKey: const SacredAlarmConfig(
          enabled: true,
          randomCount: 0,
          scheduleDaysAhead: 1,
        ).encode(),
        _eventsKey: SacredAlarmEvent.encodeList([ancient]),
      });
      await SacredAlarmService.I.resetForTesting();

      final activated = await SacredAlarmService.I.activateFromRoute('non-existent');

      expect(activated, isNull);
      expect(SacredAlarmService.I.activeEvent.value, isNull);
    });
  });
}

SacredAlarmEvent _pastEvent({required String id, required int minutesAgo}) {
  final scheduledAt = DateTime.now().subtract(Duration(minutes: minutesAgo));
  return SacredAlarmEvent(
    id: id,
    dateIso: _dateIso(scheduledAt),
    scheduledAtMs: scheduledAt.millisecondsSinceEpoch,
    activityType: SacredAlarmActivityType.prayer,
    verse: 'Prueba pasada',
    reference: 'QA 2:2',
    sourceType: 'random',
    sourceId: id,
  );
}

SacredAlarmEvent _futureEvent({required String id, required int dayOffset}) {
  final scheduledAt = DateTime.now().add(Duration(days: dayOffset, hours: 1));
  return SacredAlarmEvent(
    id: id,
    dateIso: _dateIso(scheduledAt),
    scheduledAtMs: scheduledAt.millisecondsSinceEpoch,
    activityType: SacredAlarmActivityType.prayer,
    verse: 'Prueba',
    reference: 'QA 1:1',
    sourceType: 'random',
    sourceId: id,
  );
}

String _dateIso(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
