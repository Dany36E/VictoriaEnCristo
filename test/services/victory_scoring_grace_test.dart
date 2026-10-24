// Días de gracia (token mensual) y recarga de gigantes tras el onboarding.
import 'package:app_quitar/services/victory_scoring_service.dart';
import 'package:app_quitar/utils/fecha_calendario.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Map<String, int>> _dias(
  Map<String, int> estados, {
  String g = 'sexual',
}) => {
  for (final e in estados.entries) e.key: {g: e.value},
};

void main() {
  final scoring = VictoryScoringService.I;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scoring.resetForTesting();
    scoring.clock = () => DateTime(2026, 10, 23, 9);
  });
  tearDown(scoring.resetForTesting);

  group('día de gracia', () {
    test('cubre ayer si rompió una racha y la racha vuelve', () async {
      await scoring.initForTesting(
        giants: ['sexual'],
        days: _dias({'2026-10-20': 1, '2026-10-21': 1, '2026-10-22': 0}),
      );
      expect(scoring.getCurrentStreak(), 0);
      final dia = scoring.diaParaGracia();
      expect(dia, isNotNull);
      expect(FechaCalendario.clave(dia!), '2026-10-22');
      expect(scoring.motivoSinGracia(), MotivoSinGracia.ninguno);

      expect(await scoring.useGraceToken(dia), isTrue);
      expect(scoring.getCurrentStreak(), 3);
      expect(scoring.graceTokens, 0);
      expect(scoring.esDiaDeGracia(DateTime(2026, 10, 22)), isTrue);
      // Ya no queda token este mes.
      expect(scoring.diaParaGracia(), isNull);
    });

    test('cubre anteayer si ayer fue victoria', () async {
      await scoring.initForTesting(
        giants: ['sexual'],
        days: _dias({'2026-10-20': 1, '2026-10-22': 1}),
      );
      expect(FechaCalendario.clave(scoring.diaParaGracia()!), '2026-10-21');
    });

    test('no se usa si no hay racha que proteger', () async {
      await scoring.initForTesting(
        giants: ['sexual'],
        days: _dias({'2026-10-22': 0}),
      );
      expect(scoring.diaParaGracia(), isNull);
      expect(scoring.motivoSinGracia(), MotivoSinGracia.nadaQueProteger);
    });

    test('no cubre dos días seguidos sin victoria', () async {
      await scoring.initForTesting(
        giants: ['sexual'],
        days: _dias({'2026-10-19': 1, '2026-10-20': 1}),
      );
      expect(scoring.diaParaGracia(), isNull);
    });

    test('rechaza una fecha distinta a la elegible (hoy o futura)', () async {
      await scoring.initForTesting(
        giants: ['sexual'],
        days: _dias({'2026-10-21': 1}),
      );
      expect(await scoring.useGraceToken(DateTime(2026, 10, 23)), isFalse);
      expect(await scoring.useGraceToken(DateTime(2026, 10, 24)), isFalse);
      expect(scoring.graceTokens, 1);
    });

    test('un token por mes, no se acumula', () async {
      await scoring.initForTesting(
        giants: ['sexual'],
        days: _dias({'2026-10-21': 1}),
      );
      expect(await scoring.useGraceToken(scoring.diaParaGracia()!), isTrue);
      expect(scoring.motivoSinGracia(), isNot(MotivoSinGracia.ninguno));
      // Cambio de mes: vuelve a haber exactamente uno.
      scoring.clock = () => DateTime(2026, 11, 2, 9);
      await scoring.setDayAllGiants(DateTime(2026, 10, 31), 1);
      expect(FechaCalendario.clave(scoring.diaParaGracia()!), '2026-11-01');
      expect(scoring.graceTokens, VictoryScoringService.tokensDeGraciaPorMes);
    });
  });

  group('estado del día', () {
    test('distingue victoria, gracia y sin registro', () async {
      await scoring.initForTesting(
        giants: ['sexual'],
        days: _dias({'2026-10-22': 0, '2026-10-23': 1}),
      );
      expect(scoring.estadoDelDia(DateTime(2026, 10, 23)), EstadoDia.victoria);
      expect(scoring.estadoDelDia(DateTime(2026, 10, 22)), EstadoDia.gracia);
      expect(
        scoring.estadoDelDia(DateTime(2026, 10, 21)),
        EstadoDia.sinRegistro,
      );
      expect(EstadoDia.desdeId('grace'), EstadoDia.gracia);
      expect(EstadoDia.desdeId('x'), EstadoDia.sinRegistro);
    });
  });

  group('gigantes tras el onboarding', () {
    test('al pasar del gigante provisional se conservan los días', () async {
      await scoring.initForTesting(
        giants: ['general'],
        days: _dias({
          '2026-10-21': 1,
          '2026-10-22': 1,
          '2026-10-23': 0,
        }, g: 'general'),
      );
      expect(scoring.getBestStreakAllTime(), 2);
      await scoring.aplicarGigantes(['sexual', 'digital', 'mental']);
      expect(scoring.selectedGiants, ['sexual', 'digital', 'mental']);
      expect(scoring.isVictoryDay(DateTime(2026, 10, 21)), isTrue);
      expect(scoring.isVictoryDay(DateTime(2026, 10, 22)), isTrue);
      expect(scoring.estadoDelDia(DateTime(2026, 10, 23)), EstadoDia.gracia);
      expect(scoring.getBestStreakAllTime(), 2);
    });

    test('lista vacía no cambia nada', () async {
      await scoring.initForTesting(giants: ['general']);
      await scoring.aplicarGigantes([]);
      expect(scoring.selectedGiants, ['general']);
    });
  });
}
