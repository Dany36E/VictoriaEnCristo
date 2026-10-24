// Rachas a través del cambio de horario de verano.
//
// La máquina de pruebas puede estar en una zona sin horario de verano (p. ej.
// México desde 2022), así que se usan fechas TZDateTime de zonas que sí lo
// tienen (Nueva York, Madrid, Santiago de Chile) para reproducir el error
// original (restar 24 h a la medianoche local) y comprobar la corrección.
import 'package:app_quitar/services/victory_scoring_service.dart';
import 'package:app_quitar/utils/fecha_calendario.dart';
import 'package:app_quitar/utils/time_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Claves "AAAA-MM-DD" de [n] días consecutivos que terminan en [fin].
Set<String> _diasHasta(DateTime fin, int n) => {
  for (var i = 0; i < n; i++)
    FechaCalendario.clave(FechaCalendario.sumarDias(fin, -i)),
};

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('error original (documentado)', () {
    test('restar 24 h a la medianoche del día después del cambio de primavera '
        'en Nueva York salta un día', () {
      final ny = tz.getLocation('America/New_York');
      // 8 de marzo de 2026: el día dura 23 h.
      final medianoche = tz.TZDateTime(ny, 2026, 3, 9);
      final menos24h = medianoche.subtract(const Duration(days: 1));
      expect(menos24h.day, 7, reason: 'cae el 7, no el 8: así se rompía');
      expect(
        FechaCalendario.clave(FechaCalendario.diaAnterior(medianoche)),
        '2026-03-08',
      );
    });

    test('difference().inDays entre medianoches consecutivas da 0 en DST', () {
      final madrid = tz.getLocation('Europe/Madrid');
      final a = tz.TZDateTime(madrid, 2026, 3, 29);
      final b = tz.TZDateTime(madrid, 2026, 3, 30);
      expect(b.difference(a).inDays, 0, reason: 'el día dura 23 h');
      expect(FechaCalendario.diasEntre(a, b), 1);
    });
  });

  group('FechaCalendario', () {
    for (final caso in [
      ('America/New_York', 2026, 3, 9), // primavera (23 h)
      ('America/New_York', 2026, 11, 2), // otoño (25 h)
      ('Europe/Madrid', 2026, 3, 30),
      ('Europe/Madrid', 2026, 10, 26),
      ('America/Santiago', 2026, 9, 7), // Chile cambia a medianoche
      ('America/Santiago', 2026, 4, 6),
    ]) {
      test('racha de 10 días cruzando el cambio en ${caso.$1} '
          '(${caso.$2}-${caso.$3}-${caso.$4})', () {
        final zona = tz.getLocation(caso.$1);
        final hoy = tz.TZDateTime(zona, caso.$2, caso.$3, caso.$4, 0, 30);
        final victorias = _diasHasta(hoy, 10);
        final racha = FechaCalendario.rachaActual(
          hoy: hoy,
          esVictoria: (d) => victorias.contains(FechaCalendario.clave(d)),
        );
        expect(racha, 10);
        // También a última hora del día.
        final noche = tz.TZDateTime(zona, caso.$2, caso.$3, caso.$4, 23, 50);
        expect(
          FechaCalendario.rachaActual(
            hoy: noche,
            esVictoria: (d) => victorias.contains(FechaCalendario.clave(d)),
          ),
          10,
        );
      });
    }

    test('si hoy no se registró, la racha sigue desde ayer', () {
      final hoy = DateTime(2026, 3, 9);
      final victorias = _diasHasta(DateTime(2026, 3, 8), 4);
      expect(
        FechaCalendario.rachaActual(
          hoy: hoy,
          esVictoria: (d) => victorias.contains(FechaCalendario.clave(d)),
        ),
        4,
      );
    });

    test('mejorRacha cruza el cambio de horario y fin de año', () {
      final ny = tz.getLocation('America/New_York');
      final dias = [
        for (var d = 5; d <= 12; d++) tz.TZDateTime(ny, 2026, 3, d),
        tz.TZDateTime(ny, 2026, 12, 30),
        tz.TZDateTime(ny, 2026, 12, 31),
        tz.TZDateTime(ny, 2027, 1, 1),
      ];
      expect(FechaCalendario.mejorRacha(dias), 8);
      expect(FechaCalendario.mejorRacha(const []), 0);
    });

    test('desdeClave rechaza fechas inválidas', () {
      expect(FechaCalendario.desdeClave('2026-02-30'), isNull);
      expect(FechaCalendario.desdeClave('x'), isNull);
      expect(
        FechaCalendario.desdeClave('2026-03-08'),
        DateTime.utc(2026, 3, 8),
      );
    });
  });

  group('VictoryScoringService con reloj en el cambio de horario', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      VictoryScoringService.I.resetForTesting();
    });
    tearDown(() => VictoryScoringService.I.resetForTesting());

    test('la racha no se rompe el día del cambio (Nueva York)', () async {
      final ny = tz.getLocation('America/New_York');
      final scoring = VictoryScoringService.I;
      scoring.clock = () => tz.TZDateTime(ny, 2026, 3, 10, 7);
      final dias = <String, Map<String, int>>{
        for (final k in _diasHasta(tz.TZDateTime(ny, 2026, 3, 10), 6))
          k: {'sexual': 1},
      };
      await scoring.initForTesting(giants: ['sexual'], days: dias);
      expect(scoring.getCurrentStreak(), 6);
      expect(scoring.getBestStreakAllTime(), 6);
      expect(scoring.isTodayVictory(), isTrue);
      expect(scoring.estadoHoy, EstadoDia.victoria);
    });

    test('días del camino cuentan por calendario', () async {
      final scoring = VictoryScoringService.I;
      SharedPreferences.setMockInitialValues({
        'journey_start_iso_v1': '2026-03-01',
      });
      final madrid = tz.getLocation('Europe/Madrid');
      scoring.clock = () => tz.TZDateTime(madrid, 2026, 3, 30, 0, 10);
      await scoring.initForTesting(giants: ['sexual']);
      expect(scoring.getJourneyDayCount(), 30);
      expect(TimeUtils.dateToISO(scoring.clock()), '2026-03-30');
    });
  });
}
