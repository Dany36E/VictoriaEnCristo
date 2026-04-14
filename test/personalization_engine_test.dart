import 'package:flutter_test/flutter_test.dart';
import 'package:app_quitar/models/content_enums.dart';
import 'package:app_quitar/models/giant_frequency.dart';

/// Tests unitarios para PersonalizationEngine (lógica pura).
/// Reproduce getUserStage() sin depender de singletons.
void main() {
  group('getUserStage logic', () {
    // Replica la lógica de PersonalizationEngine.getUserStage()
    ContentStage getUserStage({
      required int streak,
      bool isCrisisMode = false,
      bool recentRelapse = false,
    }) {
      if (isCrisisMode) return ContentStage.crisis;
      if (recentRelapse) return ContentStage.restoration;
      if (streak >= 66) return ContentStage.maintenance;
      return ContentStage.habit;
    }

    test('crisis mode siempre retorna crisis', () {
      expect(getUserStage(streak: 100, isCrisisMode: true),
          ContentStage.crisis);
    });

    test('recaída reciente retorna restoration', () {
      expect(getUserStage(streak: 50, recentRelapse: true),
          ContentStage.restoration);
    });

    test('crisis tiene prioridad sobre relapse', () {
      expect(
          getUserStage(
              streak: 0, isCrisisMode: true, recentRelapse: true),
          ContentStage.crisis);
    });

    test('racha < 66 → habit', () {
      expect(getUserStage(streak: 0), ContentStage.habit);
      expect(getUserStage(streak: 65), ContentStage.habit);
    });

    test('racha == 66 → maintenance', () {
      expect(getUserStage(streak: 66), ContentStage.maintenance);
    });

    test('racha > 66 → maintenance', () {
      expect(getUserStage(streak: 100), ContentStage.maintenance);
      expect(getUserStage(streak: 365), ContentStage.maintenance);
    });
  });

  group('ContentStage enum', () {
    test('tiene los 4 valores esperados', () {
      expect(ContentStage.values.length, 4);
      expect(ContentStage.values, contains(ContentStage.crisis));
      expect(ContentStage.values, contains(ContentStage.habit));
      expect(ContentStage.values, contains(ContentStage.maintenance));
      expect(ContentStage.values, contains(ContentStage.restoration));
    });
  });

  group('GiantId from legacy', () {
    test('convierte IDs legacy conocidos', () {
      expect(GiantIdExtension.fromLegacyId('pureza'), GiantId.sexual);
      expect(GiantIdExtension.fromLegacyId('digital'), GiantId.digital);
    });

    test('ID desconocido retorna null', () {
      expect(GiantIdExtension.fromLegacyId('nonexistent'), isNull);
    });
  });

  group('BattleFrequency', () {
    test('fromId convierte valores conocidos', () {
      expect(BattleFrequencyExtension.fromId('daily'), BattleFrequency.daily);
      expect(BattleFrequencyExtension.fromId('weekly'), BattleFrequency.weekly);
    });

    test('fromId con valor desconocido retorna null', () {
      expect(BattleFrequencyExtension.fromId('xyz'), isNull);
    });
  });
}
