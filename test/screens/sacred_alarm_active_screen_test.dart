/// QA tests para SacredAlarmActiveScreen.
///
/// Reproducen el flujo de "tap en notificacion": una alarma sagrada sono
/// natively, su estado en SharedPreferences sigue marcandola como
/// `scheduled`, el usuario abre la app desde la notificacion. La pantalla
/// debe recuperar el evento (no mostrar "No hay una campana activa").
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_quitar/models/sacred_alarm.dart';
import 'package:app_quitar/screens/sacred_alarm_active_screen.dart';
import 'package:app_quitar/services/sacred_alarm_service.dart';
import 'package:app_quitar/theme/app_theme_data.dart';

const String _configKey = 'sacred_alarm_config_v1';
const String _eventsKey = 'sacred_alarm_events_v1';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: AppThemeData.provider(
      theme: AppThemeData.nightPure,
      child: child,
    ),
  );
}

SacredAlarmEvent _pastEvent({required String id, required int minutesAgo}) {
  final scheduledAt = DateTime.now().subtract(Duration(minutes: minutesAgo));
  final dateIso =
      '${scheduledAt.year}-${scheduledAt.month.toString().padLeft(2, '0')}-${scheduledAt.day.toString().padLeft(2, '0')}';
  return SacredAlarmEvent(
    id: id,
    dateIso: dateIso,
    scheduledAtMs: scheduledAt.millisecondsSinceEpoch,
    activityType: SacredAlarmActivityType.prayer,
    verse: 'En todo tiempo ama el amigo.',
    reference: 'Proverbios 17:17',
    sourceType: 'random',
    sourceId: id,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SacredAlarmService.I.resetForTesting();
  });

  tearDown(() async {
    await SacredAlarmService.I.resetForTesting();
  });

  group('SacredAlarmActiveScreen', () {
    testWidgets('tap en notificacion recupera la alarma reciente y muestra UI completa', (tester) async {
      final fired = _pastEvent(id: 'fired-test', minutesAgo: 8);
      SharedPreferences.setMockInitialValues({
        _configKey: const SacredAlarmConfig(
          enabled: true,
          randomCount: 0,
          scheduleDaysAhead: 1,
        ).encode(),
        _eventsKey: SacredAlarmEvent.encodeList([fired]),
      });
      await SacredAlarmService.I.resetForTesting();

      await tester.pumpWidget(
        _wrap(const SacredAlarmActiveScreen(sessionId: 'fired-test')),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Campana Sagrada'), findsOneWidget);
      expect(find.text('No hay una campana activa en este momento.'), findsNothing);
      expect(find.textContaining('Proverbios 17:17'), findsOneWidget);
      expect(
        find.textContaining('Permanece presente'),
        findsOneWidget,
        reason: 'debe aparecer el contador de presencia mientras se completa',
      );
    });

    testWidgets('cuando no hay sessionId pero hay alarma reciente sin completar la recupera', (tester) async {
      final fired = _pastEvent(id: 'orphan', minutesAgo: 12);
      SharedPreferences.setMockInitialValues({
        _configKey: const SacredAlarmConfig(
          enabled: true,
          randomCount: 0,
          scheduleDaysAhead: 1,
        ).encode(),
        _eventsKey: SacredAlarmEvent.encodeList([fired]),
      });
      await SacredAlarmService.I.resetForTesting();

      await tester.pumpWidget(_wrap(const SacredAlarmActiveScreen()));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No hay una campana activa en este momento.'), findsNothing);
      expect(find.textContaining('Proverbios 17:17'), findsOneWidget);
    });

    testWidgets('si la alarma referida no existe muestra fallback con boton para apagar', (tester) async {
      SharedPreferences.setMockInitialValues({
        _configKey: const SacredAlarmConfig(
          enabled: true,
          randomCount: 0,
          scheduleDaysAhead: 1,
        ).encode(),
        _eventsKey: SacredAlarmEvent.encodeList(const []),
      });
      await SacredAlarmService.I.resetForTesting();

      await tester.pumpWidget(
        _wrap(const SacredAlarmActiveScreen(sessionId: 'no-existe')),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No hay una campana activa en este momento.'), findsOneWidget);
      expect(find.text('Apagar campana'), findsOneWidget);

      // Pulsar el boton de respaldo no debe lanzar excepciones aunque el
      // canal nativo no este disponible en tests.
      await tester.tap(find.text('Apagar campana'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(find.text('Campana apagada'), findsOneWidget);
    });
  });
}
