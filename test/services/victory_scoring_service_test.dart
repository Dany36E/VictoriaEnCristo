/// Tests de VictoryScoringService: rachas, umbral de victoria, migración
/// legacy, tokens de gracia y detección de recaída.
///
/// El servicio usa `DateTime.now()` internamente, así que los tests trabajan
/// con fechas relativas a hoy (hoy, ayer, antier...) para ser estables sin
/// importar cuándo corran.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_quitar/services/victory_scoring_service.dart';
import 'package:app_quitar/utils/time_utils.dart';

/// 5 gigantes → con umbral 0.60, se requieren ceil(3.0)=3 victorias para ⭐.
const _giants = ['lujuria', 'ira', 'pereza', 'gula', 'orgullo'];

DateTime _daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
}

String _iso(int daysAgo) => TimeUtils.dateToISO(_daysAgo(daysAgo));

/// Mapa de un día con [wins] gigantes en victoria (el resto en 0).
Map<String, int> _day(int wins) => {
      for (var i = 0; i < _giants.length; i++) _giants[i]: i < wins ? 1 : 0,
    };

Future<VictoryScoringService> _initService({
  Map<String, Object> extraPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'selected_giants': _giants,
    // Evita que la migración legacy interfiera en tests que no la prueban.
    'migrated_victory_to_by_giant': true,
    ...extraPrefs,
  });
  final service = VictoryScoringService.I;
  service.resetForTesting();
  await service.init();
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Inicialización', () {
    test('sin datos: racha 0, nada registrado hoy', () async {
      final s = await _initService();
      expect(s.getCurrentStreak(), 0);
      expect(s.isLoggedToday(), isFalse);
      expect(s.getBestStreakAllTime(), 0);
      expect(s.getTotalGiantsCount(), _giants.length);
    });

    test('umbral por defecto 0.60 con 5 gigantes requiere 3 victorias', () async {
      final s = await _initService();
      expect(s.threshold, VictoryScoringService.defaultThreshold);
      expect(s.getRequiredVictories(), 3);
    });
  });

  group('Victoria del día (umbral)', () {
    test('3 de 5 gigantes es victoria; 2 de 5 no lo es', () async {
      final s = await _initService(extraPrefs: {
        'victory_by_giant_v1': jsonEncode({
          _iso(1): _day(3),
          _iso(2): _day(2),
        }),
      });
      expect(s.isVictoryDay(_daysAgo(1)), isTrue);
      expect(s.isVictoryDay(_daysAgo(2)), isFalse);
      expect(s.getDayScore(_daysAgo(1)), closeTo(0.6, 0.001));
    });

    test('día sin registro nunca es victoria', () async {
      final s = await _initService();
      expect(s.isVictoryDay(_daysAgo(1)), isFalse);
    });
  });

  group('Racha actual', () {
    test('hoy + 2 días previos en victoria → racha 3', () async {
      final s = await _initService(extraPrefs: {
        'victory_by_giant_v1': jsonEncode({
          _iso(0): _day(5),
          _iso(1): _day(5),
          _iso(2): _day(3),
        }),
      });
      expect(s.getCurrentStreak(), 3);
    });

    test('hoy sin registrar pero ayer y antier en victoria → racha 2', () async {
      final s = await _initService(extraPrefs: {
        'victory_by_giant_v1': jsonEncode({
          _iso(1): _day(5),
          _iso(2): _day(5),
        }),
      });
      expect(s.getCurrentStreak(), 2);
    });

    test('hueco de un día corta la racha', () async {
      final s = await _initService(extraPrefs: {
        'victory_by_giant_v1': jsonEncode({
          _iso(0): _day(5),
          // _iso(1) falta: hueco
          _iso(2): _day(5),
          _iso(3): _day(5),
        }),
      });
      expect(s.getCurrentStreak(), 1);
    });

    test('día con score bajo el umbral corta la racha igual que un hueco', () async {
      final s = await _initService(extraPrefs: {
        'victory_by_giant_v1': jsonEncode({
          _iso(0): _day(5),
          _iso(1): _day(2), // registrado pero NO victoria (2 < 3)
          _iso(2): _day(5),
        }),
      });
      expect(s.getCurrentStreak(), 1);
    });

    test('ni hoy ni ayer en victoria → racha 0 aunque haya historia', () async {
      final s = await _initService(extraPrefs: {
        'victory_by_giant_v1': jsonEncode({
          _iso(3): _day(5),
          _iso(4): _day(5),
        }),
      });
      expect(s.getCurrentStreak(), 0);
    });
  });

  group('Mejor racha histórica', () {
    test('detecta la racha más larga aunque no sea la actual', () async {
      final s = await _initService(extraPrefs: {
        'victory_by_giant_v1': jsonEncode({
          _iso(1): _day(5),
          // hueco en _iso(2)
          _iso(3): _day(5),
          _iso(4): _day(5),
          _iso(5): _day(5),
        }),
      });
      expect(s.getBestStreakAllTime(), 3);
    });
  });

  group('Escritura', () {
    test('setDayAllGiants marca victoria y persiste', () async {
      final s = await _initService();
      await s.setDayAllGiants(_daysAgo(0), 1);
      expect(s.isVictoryDay(_daysAgo(0)), isTrue);
      expect(s.isLoggedToday(), isTrue);
      expect(s.getCurrentStreak(), 1);

      // Persistencia: lo guardado debe sobrevivir un reinit en frío.
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('victory_by_giant_v1');
      expect(stored, isNotNull);
      expect(jsonDecode(stored!), contains(_iso(0)));
    });

    test('días futuros no se pueden editar', () async {
      final s = await _initService();
      final tomorrow = _daysAgo(-1);
      await s.setDayAllGiants(tomorrow, 1);
      expect(s.isDateLogged(tomorrow), isFalse);
    });

    test('setDayGiantState clampa valores fuera de 0/1', () async {
      final s = await _initService();
      await s.setDayGiantState(_daysAgo(0), _giants.first, 7);
      expect(s.getDayGiantStates(_daysAgo(0))[_giants.first], 1);
    });

    test('write-through notifica al sync adapter vía onDayChanged', () async {
      final s = await _initService();
      DateTime? notified;
      s.onDayChanged = (date) => notified = date;
      await s.setDayAllGiants(_daysAgo(0), 1);
      expect(notified, isNotNull);
      expect(TimeUtils.isSameDay(notified!, _daysAgo(0)), isTrue);
    });
  });

  group('Migración legacy', () {
    test('victory_days_set se migra marcando todos los gigantes', () async {
      final s = await _initService(extraPrefs: {
        'migrated_victory_to_by_giant': false,
        'victory_days_set': jsonEncode([_iso(1), _iso(2)]),
      });
      // Días migrados cuentan como victoria plena
      expect(s.isVictoryDay(_daysAgo(1)), isTrue);
      expect(s.isVictoryDay(_daysAgo(2)), isTrue);
      expect(s.getDayVictoriesCount(_daysAgo(1)), _giants.length);
      expect(s.getCurrentStreak(), 2);

      // Flag de migración queda activo (no re-migra)
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('migrated_victory_to_by_giant'), isTrue);
    });

    test('la migración NO pisa datos nuevos existentes', () async {
      final s = await _initService(extraPrefs: {
        'migrated_victory_to_by_giant': false,
        'victory_days_set': jsonEncode([_iso(5)]),
        'victory_by_giant_v1': jsonEncode({_iso(1): _day(2)}),
      });
      // El día legacy no se migró porque ya había datos del sistema nuevo
      expect(s.isDateLogged(_daysAgo(5)), isFalse);
      // Y los datos nuevos siguen intactos
      expect(s.getDayVictoriesCount(_daysAgo(1)), 2);
    });
  });

  group('Tokens de gracia', () {
    test('el mes nuevo otorga 1 token; usarlo marca el día como victoria', () async {
      final s = await _initService();
      expect(s.graceTokens, 1);

      final ok = await s.useGraceToken(_daysAgo(1));
      expect(ok, isTrue);
      expect(s.graceTokens, 0);
      expect(s.isVictoryDay(_daysAgo(1)), isTrue);
      expect(s.graceDaysUsed, contains(_iso(1)));

      // Sin tokens, el segundo uso falla
      final again = await s.useGraceToken(_daysAgo(2));
      expect(again, isFalse);
      expect(s.isVictoryDay(_daysAgo(2)), isFalse);
    });

    test('no se puede usar token de gracia en día futuro', () async {
      final s = await _initService();
      final ok = await s.useGraceToken(_daysAgo(-1));
      expect(ok, isFalse);
      expect(s.graceTokens, 1);
    });
  });

  group('Detección de recaída', () {
    test('racha >=3 que cae a 0 dispara relapseEventNotifier', () async {
      // Racha de 3 anclada en ayer (hoy aún sin registrar)
      final s = await _initService(extraPrefs: {
        'victory_by_giant_v1': jsonEncode({
          _iso(1): _day(5),
          _iso(2): _day(5),
          _iso(3): _day(5),
        }),
      });
      expect(s.getCurrentStreak(), 3);
      expect(s.relapseEventNotifier.value, isNull);

      // El usuario marca ayer como caída: ni hoy ni ayer son victoria,
      // la racha pasa de 3 a 0 en una sola transición → recaída.
      await s.setDayAllGiants(_daysAgo(1), 0);
      expect(s.getCurrentStreak(), 0);
      expect(s.relapseEventNotifier.value, 3);
      expect(s.hasPendingRelapseAck, isTrue);
      expect(s.lastBrokenStreak, 3);

      // El usuario reconoce la recaída
      await s.acknowledgeRelapse();
      expect(s.hasPendingRelapseAck, isFalse);
      expect(s.relapseEventNotifier.value, isNull);
    });
  });

  group('Estado semanal', () {
    test('getWeeklyStatus devuelve 7 días lunes→domingo y marca hoy', () async {
      final s = await _initService(extraPrefs: {
        'victory_by_giant_v1': jsonEncode({_iso(0): _day(5)}),
      });
      final week = s.getWeeklyStatus();
      expect(week.length, 7);
      expect((week.first['date'] as DateTime).weekday, DateTime.monday);
      final todayEntry = week.firstWhere((d) => d['isToday'] == true);
      expect(todayEntry['completed'], isTrue);
    });
  });
}
