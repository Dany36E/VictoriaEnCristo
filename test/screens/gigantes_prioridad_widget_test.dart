// Emergencia con chips de gigantes y editor «Mis gigantes».
import 'dart:convert';

import 'package:app_quitar/screens/emergency_screen.dart';
import 'package:app_quitar/screens/mis_gigantes_screen.dart';
import 'package:app_quitar/screens/onboarding/giant_frequency_screen.dart';
import 'package:app_quitar/screens/onboarding/giant_ranking_screen.dart';
import 'package:app_quitar/services/emergency_sos_service.dart';
import 'package:app_quitar/services/onboarding_service.dart';
import 'package:app_quitar/services/victory_scoring_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../visual/theme_matrix.dart' show setUpThemeMatrix;

Future<void> _gigantes(
  List<String> ids,
  Map<String, String> frecuencias,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await prefs.setStringList('selected_giants', ids);
  await prefs.setString('giant_frequencies_json', jsonEncode(frecuencias));
  await prefs.setBool(OnboardingService.keyGiantOrderExplicit, true);
  await OnboardingService().init();
}

Future<void> _abrir(WidgetTester tester, Widget pantalla) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: pantalla));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _cerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 11));
}

Future<void> _ver(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  setUpThemeMatrix();
  setUpAll(() async {
    await EmergencySosService.I.init();
  });

  testWidgets('onboarding: ordenar pasa la lista ordenada a frecuencias', (
    tester,
  ) async {
    await tester.runAsync(() => _gigantes([], {}));
    await _abrir(
      tester,
      const GiantRankingScreen(selectedGiants: ['digital', 'sexual', 'mental']),
    );
    try {
      expect(find.text('Ordena tus gigantes'), findsOneWidget);
      expect(find.text('1°'), findsOneWidget);
      // El primero no tiene «Subir»; el último no tiene «Bajar».
      expect(find.byKey(const ValueKey('subir-digital')), findsNothing);
      expect(find.byKey(const ValueKey('bajar-mental')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('subir-sexual')));
      await tester.pump();
      await tester.tap(find.text('Continuar'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final freq = tester.widget<GiantFrequencyScreen>(
        find.byType(GiantFrequencyScreen),
      );
      expect(freq.selectedGiants, ['sexual', 'digital', 'mental']);
    } finally {
      await _cerrar(tester);
    }
  });

  group('emergencia', () {
    testWidgets('empieza con el gigante n.º 1 y los chips cambian el plan', (
      tester,
    ) async {
      await tester.runAsync(
        () => _gigantes(
          ['digital', 'sexual'],
          {'digital': 'weekly', 'sexual': 'daily'},
        ),
      );
      await _abrir(tester, const EmergencyScreen());
      try {
        expect(find.text('¿Con cuál luchas ahora?'), findsOneWidget);
        expect(find.text('Plan personalizado: Mundo Digital'), findsOneWidget);
        expect(find.text('SUELTA EL DISPOSITIVO'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('sos-gigante-sexual')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Plan personalizado: Pureza Sexual'), findsOneWidget);
        expect(find.text('APARTA LA MIRADA'), findsOneWidget);
        expect(find.text('SUELTA EL DISPOSITIVO'), findsNothing);
        // El aviso al compañero sigue en la pantalla.
        expect(find.byType(EmergencyScreen), findsOneWidget);
      } finally {
        await _cerrar(tester);
      }
    });

    testWidgets('con un solo gigante no hay chips', (tester) async {
      await tester.runAsync(() => _gigantes(['mental'], {'mental': 'daily'}));
      await _abrir(tester, const EmergencyScreen());
      try {
        expect(find.text('¿Con cuál luchas ahora?'), findsNothing);
        expect(
          find.text('Plan personalizado: Batallas Mentales'),
          findsOneWidget,
        );
      } finally {
        await _cerrar(tester);
      }
    });
  });

  group('Mis gigantes', () {
    final scoring = VictoryScoringService.I;
    tearDown(scoring.resetForTesting);

    testWidgets('agregar, quitar y reordenar guarda y conserva el historial', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await _gigantes(
          ['sexual', 'digital'],
          {'sexual': 'daily', 'digital': 'weekly'},
        );
        scoring.resetForTesting();
        scoring.clock = () => DateTime(2026, 10, 23, 9);
        await scoring.initForTesting(
          giants: ['sexual', 'digital'],
          days: {
            '2026-10-21': {'sexual': 1, 'digital': 1},
            '2026-10-22': {'sexual': 1, 'digital': 1},
          },
        );
      });
      expect(scoring.getCurrentStreak(), 2);
      await _abrir(tester, const MisGigantesScreen());
      try {
        // Agregar «mental» y elegir su frecuencia.
        await _ver(tester, find.byKey(const ValueKey('agregar-mental')));
        await tester.tap(find.byKey(const ValueKey('agregar-mental')));
        await tester.pump();
        final freq = find.byKey(const ValueKey('frecuencia-mental-daily'));
        await _ver(tester, freq);
        await tester.tap(freq);
        await tester.pump();

        // Quitar «digital» (pide confirmación).
        final quitar = find.byKey(const ValueKey('quitar-digital'));
        await _ver(tester, quitar);
        await tester.tap(quitar);
        await tester.pumpAndSettle();
        expect(find.text('¿Quitar «Mundo Digital»?'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('confirmar-quitar')));
        await tester.pumpAndSettle();

        // Subir «mental» al primer lugar.
        final subir = find.byKey(const ValueKey('subir-mental'));
        await _ver(tester, subir);
        await tester.tap(subir);
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('guardar-gigantes')));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final prefs = await tester.runAsync(SharedPreferences.getInstance);
        expect(prefs!.getStringList('selected_giants'), ['mental', 'sexual']);
        expect(jsonDecode(prefs.getString('giant_frequencies_json')!), {
          'mental': 'daily',
          'sexual': 'daily',
        });
        expect(scoring.selectedGiants, ['mental', 'sexual']);
        // Los días ya registrados siguen contando.
        expect(scoring.isVictoryDay(DateTime(2026, 10, 21)), isTrue);
        expect(scoring.isVictoryDay(DateTime(2026, 10, 22)), isTrue);
        expect(scoring.getCurrentStreak(), 2);
      } finally {
        await _cerrar(tester);
      }
    });
  });
}
