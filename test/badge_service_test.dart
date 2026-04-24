import 'package:flutter_test/flutter_test.dart';
import 'package:app_quitar/models/badge_definition.dart';

/// Tests unitarios para lógica de badges.
/// No dependen de SharedPreferences ni Firebase — testean lógica pura.
void main() {
  group('BadgeCategory thresholds', () {
    test('streak tiene 7 niveles con umbrales crecientes', () {
      final thresholds = BadgeCategory.streak.thresholds;
      expect(thresholds.length, 7);
      for (int i = 1; i < thresholds.length; i++) {
        expect(thresholds[i], greaterThan(thresholds[i - 1]));
      }
    });

    test('todas las categorías tienen exactamente 7 umbrales', () {
      for (final cat in BadgeCategory.values) {
        expect(cat.thresholds.length, 7,
            reason: '${cat.name} debe tener 7 umbrales');
      }
    });
  });

  group('computeLevel logic (reproducida)', () {
    // Reproduce _computeLevel de BadgeService para probar sin singleton
    BadgeLevel? computeLevel(BadgeCategory category, int value) {
      final thresholds = category.thresholds;
      BadgeLevel? highest;
      for (int i = 0; i < thresholds.length; i++) {
        if (value >= thresholds[i]) {
          highest = BadgeLevel.values[i];
        } else {
          break;
        }
      }
      return highest;
    }

    test('valor 0 → null (ningún nivel)', () {
      expect(computeLevel(BadgeCategory.streak, 0), isNull);
    });

    test('valor justo en primer umbral → semilla', () {
      // streak thresholds: [3, 7, 14, 30, 100, 200, 365]
      expect(computeLevel(BadgeCategory.streak, 3), BadgeLevel.semilla);
    });

    test('valor entre umbrales → nivel inferior', () {
      // valor 10 está entre 7 (brote) y 14 (planta)
      expect(computeLevel(BadgeCategory.streak, 10), BadgeLevel.brote);
    });

    test('valor exacto en umbral alto → ese nivel', () {
      expect(computeLevel(BadgeCategory.streak, 100), BadgeLevel.fruto);
    });

    test('valor máximo → corona', () {
      expect(computeLevel(BadgeCategory.streak, 365), BadgeLevel.corona);
    });

    test('valor mayor que máximo umbral → corona', () {
      expect(computeLevel(BadgeCategory.streak, 999), BadgeLevel.corona);
    });

    test('funciona con categoría bible', () {
      // bible thresholds: [10, 50, 150, 300, 600, 900, 1189]
      expect(computeLevel(BadgeCategory.bible, 9), isNull);
      expect(computeLevel(BadgeCategory.bible, 10), BadgeLevel.semilla);
      expect(computeLevel(BadgeCategory.bible, 150), BadgeLevel.planta);
      expect(computeLevel(BadgeCategory.bible, 1189), BadgeLevel.corona);
    });
  });

  group('restoreFromCloud merge logic (reproducida)', () {
    // Reproduce la merge strategy de BadgeService.restoreFromCloud
    Map<String, int> mergeCloudIntoLocal(
        Map<String, int> local, Map<String, int> cloud) {
      final result = Map<String, int>.from(local);
      for (final entry in cloud.entries) {
        final localLevel = result[entry.key] ?? -1;
        if (entry.value > localLevel) {
          result[entry.key] = entry.value;
        }
      }
      return result;
    }

    test('cloud vacío no modifica local', () {
      final local = {'streak': 2, 'bible': 1};
      final result = mergeCloudIntoLocal(local, {});
      expect(result, local);
    });

    test('cloud mayor gana', () {
      final local = {'streak': 2};
      final cloud = {'streak': 5};
      final result = mergeCloudIntoLocal(local, cloud);
      expect(result['streak'], 5);
    });

    test('local mayor se mantiene', () {
      final local = {'streak': 5};
      final cloud = {'streak': 2};
      final result = mergeCloudIntoLocal(local, cloud);
      expect(result['streak'], 5);
    });

    test('merge combina categorías distintas', () {
      final local = {'streak': 3};
      final cloud = {'bible': 4};
      final result = mergeCloudIntoLocal(local, cloud);
      expect(result['streak'], 3);
      expect(result['bible'], 4);
    });

    test('merge toma max de cada categoría', () {
      final local = {'streak': 5, 'bible': 1, 'journal': 3};
      final cloud = {'streak': 2, 'bible': 4, 'favorites': 1};
      final result = mergeCloudIntoLocal(local, cloud);
      expect(result['streak'], 5); // local ganó
      expect(result['bible'], 4); // cloud ganó
      expect(result['journal'], 3); // solo en local
      expect(result['favorites'], 1); // solo en cloud
    });
  });

  group('BadgeLevel enum', () {
    test('tiene exactamente 7 valores', () {
      expect(BadgeLevel.values.length, 7);
    });

    test('displayName no está vacío', () {
      for (final level in BadgeLevel.values) {
        expect(level.displayName, isNotEmpty);
      }
    });

    test('emoji no está vacío', () {
      for (final level in BadgeLevel.values) {
        expect(level.emoji, isNotEmpty);
      }
    });
  });

  group('BadgeCategory enum', () {
    test('tiene exactamente 9 categorías', () {
      expect(BadgeCategory.values.length, 9);
    });

    test('displayName no está vacío', () {
      for (final cat in BadgeCategory.values) {
        expect(cat.displayName, isNotEmpty);
      }
    });
  });
}
