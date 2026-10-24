// Prioridad de gigantes: orden explícito, respaldo por frecuencia para
// usuarios antiguos y conservación del historial al editar gigantes.
import 'dart:convert';

import 'package:app_quitar/models/content_enums.dart';
import 'package:app_quitar/services/onboarding_service.dart';
import 'package:app_quitar/services/personalization_engine.dart';
import 'package:app_quitar/services/victory_scoring_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _prefs(Map<String, Object> valores) async {
  SharedPreferences.setMockInitialValues(valores);
  await OnboardingService().init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = PersonalizationEngine.I;

  group('orden de gigantes', () {
    test('el orden guardado se persiste y el primario es el primero', () async {
      await _prefs({});
      final ok = await OnboardingService().saveGiantsConfiguration(
        giants: ['mental', 'sexual', 'digital'],
        frequencies: {
          'mental': 'occasional',
          'sexual': 'daily',
          'digital': 'weekly',
        },
      );
      expect(ok, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('selected_giants'), [
        'mental',
        'sexual',
        'digital',
      ]);
      expect(prefs.getBool(OnboardingService.keyGiantOrderExplicit), isTrue);
      expect(OnboardingService().hasExplicitGiantOrder, isTrue);
      // Aunque «sexual» sea diario, manda el orden elegido.
      expect(engine.primaryGiant, GiantId.mental);
      expect(engine.rankedGiants, [
        GiantId.mental,
        GiantId.sexual,
        GiantId.digital,
      ]);
    });

    test(
      'usuario antiguo sin orden explícito: respaldo por frecuencia',
      () async {
        await _prefs({
          'selected_giants': ['digital', 'mental', 'sexual'],
          'giant_frequencies_json': jsonEncode({
            'digital': 'weekly',
            'mental': 'daily',
            'sexual': 'daily',
          }),
        });
        expect(OnboardingService().hasExplicitGiantOrder, isFalse);
        // Empate diario: decide la prioridad fija (sexual antes que mental).
        expect(engine.rankedGiants, [
          GiantId.sexual,
          GiantId.mental,
          GiantId.digital,
        ]);
        expect(engine.primaryGiant, GiantId.sexual);
      },
    );

    test('usuario antiguo sin frecuencias: orden guardado', () async {
      await _prefs({
        'selected_giants': ['emotions', 'sexual'],
      });
      expect(engine.primaryGiant, GiantId.emotions);
    });

    test('un solo gigante cuenta como orden explícito', () async {
      await _prefs({
        'selected_giants': ['health'],
      });
      expect(OnboardingService().hasExplicitGiantOrder, isTrue);
      expect(engine.rankedGiants, [GiantId.health]);
    });
  });

  group('editar gigantes conserva el historial', () {
    final scoring = VictoryScoringService.I;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      scoring.resetForTesting();
      scoring.clock = () => DateTime(2026, 10, 23, 9);
    });
    tearDown(scoring.resetForTesting);

    test('agregar un gigante no borra victorias pasadas', () async {
      await scoring.initForTesting(
        giants: ['sexual'],
        days: {
          '2026-10-20': {'sexual': 1},
          '2026-10-21': {'sexual': 1},
          '2026-10-22': {'sexual': 1},
        },
      );
      expect(scoring.getCurrentStreak(), 3);
      await scoring.actualizarGigantes(['sexual', 'digital']);
      expect(scoring.selectedGiants, ['sexual', 'digital']);
      for (final d in [20, 21, 22]) {
        expect(scoring.isVictoryDay(DateTime(2026, 10, d)), isTrue);
      }
      expect(scoring.getCurrentStreak(), 3);
      // El nuevo empieza hoy: sin registro propio hoy.
      expect(scoring.getDayGiantStates(DateTime(2026, 10, 23))['digital'], 0);
    });

    test('quitar un gigante conserva el resultado de cada día', () async {
      await scoring.initForTesting(
        giants: ['sexual', 'digital'],
        days: {
          // Día no victorioso que sin «digital» pasaría a victoria.
          '2026-10-20': {'sexual': 1, 'digital': 0},
          '2026-10-21': {'sexual': 1, 'digital': 1},
        },
      );
      expect(scoring.isVictoryDay(DateTime(2026, 10, 20)), isFalse);
      await scoring.actualizarGigantes(['sexual']);
      expect(scoring.isVictoryDay(DateTime(2026, 10, 20)), isFalse);
      expect(scoring.isVictoryDay(DateTime(2026, 10, 21)), isTrue);
    });

    test('reordenar no cambia ningún día', () async {
      await scoring.initForTesting(
        giants: ['sexual', 'digital'],
        days: {
          '2026-10-21': {'sexual': 1, 'digital': 0},
          '2026-10-22': {'sexual': 1, 'digital': 1},
        },
      );
      await scoring.actualizarGigantes(['digital', 'sexual']);
      expect(scoring.selectedGiants, ['digital', 'sexual']);
      expect(scoring.getDayGiantStates(DateTime(2026, 10, 21)), {
        'digital': 0,
        'sexual': 1,
      });
      expect(scoring.isVictoryDay(DateTime(2026, 10, 22)), isTrue);
    });
  });
}
