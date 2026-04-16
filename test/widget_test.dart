import 'package:flutter_test/flutter_test.dart';
import 'package:app_quitar/utils/time_utils.dart';

/// Tests para lógica de rachas y días de victoria.
/// Replica la lógica de cálculo sin depender de singletons/SharedPrefs.
void main() {
  group('TimeUtils', () {
    test('todayISO devuelve formato yyyy-MM-dd', () {
      final iso = TimeUtils.todayISO();
      expect(iso, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('dateToISO formatea correctamente', () {
      expect(TimeUtils.dateToISO(DateTime(2025, 1, 5)), '2025-01-05');
      expect(TimeUtils.dateToISO(DateTime(2025, 12, 31)), '2025-12-31');
    });

    test('parseISO invierte dateToISO', () {
      final date = DateTime(2025, 3, 14);
      final parsed = TimeUtils.parseISO(TimeUtils.dateToISO(date));
      expect(parsed, isNotNull);
      expect(parsed!.year, 2025);
      expect(parsed.month, 3);
      expect(parsed.day, 14);
    });

    test('parseISO retorna null para formato inválido', () {
      expect(TimeUtils.parseISO('not-a-date'), isNull);
      expect(TimeUtils.parseISO(''), isNull);
    });
  });

  group('Streak calculation logic', () {
    /// Replica getCurrentStreak() de VictoryScoringService
    /// sin depender de SharedPreferences
    int calculateStreak(Set<String> victoryDaysISO) {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      DateTime checkDate = todayStart;

      if (!victoryDaysISO.contains(TimeUtils.dateToISO(checkDate))) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        if (!victoryDaysISO.contains(TimeUtils.dateToISO(checkDate))) {
          return 0;
        }
      }

      int streak = 0;
      while (victoryDaysISO.contains(TimeUtils.dateToISO(checkDate))) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
      return streak;
    }

    test('sin días → racha 0', () {
      expect(calculateStreak({}), 0);
    });

    test('solo hoy → racha 1', () {
      final today = TimeUtils.todayISO();
      expect(calculateStreak({today}), 1);
    });

    test('hoy + ayer → racha 2', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      expect(
        calculateStreak({
          TimeUtils.dateToISO(today),
          TimeUtils.dateToISO(yesterday),
        }),
        2,
      );
    });

    test('5 días consecutivos terminando hoy', () {
      final today = DateTime.now();
      final days = <String>{};
      for (int i = 0; i < 5; i++) {
        days.add(TimeUtils.dateToISO(today.subtract(Duration(days: i))));
      }
      expect(calculateStreak(days), 5);
    });

    test('hueco rompe la racha', () {
      final today = DateTime.now();
      // Hoy + anteayer (falta ayer)
      final days = {
        TimeUtils.dateToISO(today),
        TimeUtils.dateToISO(today.subtract(const Duration(days: 2))),
      };
      expect(calculateStreak(days), 1);
    });

    test('racha empieza desde ayer si hoy no hay victoria', () {
      final today = DateTime.now();
      final days = <String>{};
      // Ayer, anteayer, hace 3 días
      for (int i = 1; i <= 3; i++) {
        days.add(TimeUtils.dateToISO(today.subtract(Duration(days: i))));
      }
      expect(calculateStreak(days), 3);
    });

    test('ni hoy ni ayer → racha 0 aunque haya días anteriores', () {
      final today = DateTime.now();
      // Hace 3 y 4 días solamente
      final days = {
        TimeUtils.dateToISO(today.subtract(const Duration(days: 3))),
        TimeUtils.dateToISO(today.subtract(const Duration(days: 4))),
      };
      expect(calculateStreak(days), 0);
    });
  });

  group('Best streak all time', () {
    int bestStreak(Set<String> daysISO) {
      final dates = daysISO
          .map((iso) => TimeUtils.parseISO(iso))
          .whereType<DateTime>()
          .toList()
        ..sort((a, b) => a.compareTo(b));

      if (dates.isEmpty) return 0;
      if (dates.length == 1) return 1;

      int best = 1;
      int current = 1;
      for (int i = 1; i < dates.length; i++) {
        if (dates[i].difference(dates[i - 1]).inDays == 1) {
          current++;
          if (current > best) best = current;
        } else {
          current = 1;
        }
      }
      return best;
    }

    test('vacío → 0', () => expect(bestStreak({}), 0));
    test('un día → 1', () => expect(bestStreak({'2025-03-01'}), 1));

    test('3 consecutivos', () {
      expect(bestStreak({'2025-03-01', '2025-03-02', '2025-03-03'}), 3);
    });

    test('dos rachas, retorna la mayor', () {
      // Racha de 2 + racha de 4
      expect(
        bestStreak({
          '2025-01-01', '2025-01-02',
          '2025-02-10', '2025-02-11', '2025-02-12', '2025-02-13',
        }),
        4,
      );
    });

    test('cruza cambio de mes', () {
      expect(bestStreak({'2025-01-30', '2025-01-31', '2025-02-01'}), 3);
    });
  });
}
