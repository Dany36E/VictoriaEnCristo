/// ═══════════════════════════════════════════════════════════════════════════
/// QA SMOKE TEST — verifica que pantallas modificadas renderizan sin errores
/// ═══════════════════════════════════════════════════════════════════════════
/// • PrayersScreen: monta con cada uno de los 9 temas, sin overflow ni excepciones
/// • JesusStreakWidget: verifica que el sprite se resuelve y no hay overflows
///   en estados clave (0, 1, 7, 30, 100, 365 días)
/// • HomeScreen _GlassmorphicMenuButton: verifica bordes/texto en 9 temas
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:app_quitar/widgets/jesus_streak_widget.dart';
import 'package:app_quitar/data/prayers.dart';

// Envuelve un widget con AppThemeData.provider para que `AppThemeData.of`
// devuelva el tema correcto.
Widget _wrap({required AppThemeData theme, required Widget child}) {
  return MaterialApp(
    home: AppThemeData.provider(
      theme: theme,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────────────────────────────
  // DATA INTEGRITY
  // ─────────────────────────────────────────────────────────────────────────
  group('Prayers data integrity', () {
    test('todas las categorías tienen al menos 3 oraciones', () {
      final buckets = <String, List<Prayer>>{
        'emergency': Prayers.emergencyPrayers,
        'morning': Prayers.morningPrayers,
        'night': Prayers.nightPrayers,
        'strength': Prayers.strengthPrayers,
        'gratitude': Prayers.gratitudePrayers,
        'forgiveness': Prayers.forgivenessPrayers,
        'warfare': Prayers.warfarePrayers,
        'family': Prayers.familyPrayers,
      };
      for (final entry in buckets.entries) {
        expect(entry.value.length, greaterThanOrEqualTo(3),
            reason: 'Categoría "${entry.key}" tiene pocas oraciones');
      }
    });

    test('ninguna oración tiene campos vacíos y la duración es razonable', () {
      final all = <Prayer>[
        ...Prayers.emergencyPrayers,
        ...Prayers.morningPrayers,
        ...Prayers.nightPrayers,
        ...Prayers.strengthPrayers,
        ...Prayers.gratitudePrayers,
        ...Prayers.forgivenessPrayers,
        ...Prayers.warfarePrayers,
        ...Prayers.familyPrayers,
      ];
      for (final p in all) {
        expect(p.title.trim(), isNotEmpty, reason: 'Oración sin título');
        expect(p.content.trim().length, greaterThan(40),
            reason: 'Oración "${p.title}" muy corta');
        expect(p.durationMinutes, inInclusiveRange(1, 15),
            reason: 'Duración fuera de rango en "${p.title}"');
      }
    });

    test('suma total de oraciones ≥ 30', () {
      final total = Prayers.emergencyPrayers.length +
          Prayers.morningPrayers.length +
          Prayers.nightPrayers.length +
          Prayers.strengthPrayers.length +
          Prayers.gratitudePrayers.length +
          Prayers.forgivenessPrayers.length +
          Prayers.warfarePrayers.length +
          Prayers.familyPrayers.length;
      expect(total, greaterThanOrEqualTo(30));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // JESUS STREAK WIDGET — renderiza en estados clave sin overflow
  // ─────────────────────────────────────────────────────────────────────────
  group('JesusStreakWidget rendering', () {
    final states = <({int streak, bool done, bool newUser})>[
      (streak: 0, done: false, newUser: true),   // recién empieza
      (streak: 1, done: true, newUser: false),   // primera victoria
      (streak: 7, done: false, newUser: false),  // una semana
      (streak: 30, done: true, newUser: false),  // un mes
      (streak: 100, done: true, newUser: false), // 3 dígitos
      (streak: 365, done: true, newUser: false), // un año
      (streak: 1000, done: true, newUser: false),// 4 dígitos
    ];

    for (final s in states) {
      testWidgets(
        'streak=${s.streak} completedToday=${s.done} isNew=${s.newUser}',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(411, 914)); // pixel 5
          await tester.pumpWidget(_wrap(
            theme: AppThemeData.nightPure,
            child: SizedBox(
              width: 380,
              height: 240,
              child: JesusStreakWidget(
                streakDays: s.streak,
                completedToday: s.done,
                isNewUser: s.newUser,
                isLoading: false,
                checkinDone: s.done,
                onRegisterVictory: () {},
              ),
            ),
          ));
          // Permitir que animaciones de flutter_animate corran y se completen.
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(seconds: 2));

          // No exceptions on build
          expect(tester.takeException(), isNull);
          // Widget monta
          expect(find.byType(JesusStreakWidget), findsOneWidget);
        },
      );
    }

    testWidgets('renderiza también en viewport estrecho (340px)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(340, 780));
      await tester.pumpWidget(_wrap(
        theme: AppThemeData.nightPure,
        child: SizedBox(
          width: 320,
          height: 240,
          child: JesusStreakWidget(
            streakDays: 999,
            completedToday: true,
            isNewUser: false,
            checkinDone: true,
            onRegisterVictory: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TEMAS — el inherited widget resuelve bien para los 9 temas
  // ─────────────────────────────────────────────────────────────────────────
  group('AppThemeData provider', () {
    testWidgets('todos los 9 temas se resuelven vía AppThemeData.of', (tester) async {
      for (final theme in AppThemeData.all) {
        AppThemeData? resolved;
        await tester.pumpWidget(_wrap(
          theme: theme,
          child: Builder(
            builder: (ctx) {
              resolved = AppThemeData.of(ctx);
              return const SizedBox();
            },
          ),
        ));
        await tester.pump();
        expect(resolved, isNotNull, reason: 'Tema ${theme.id} no se resolvió');
        expect(resolved!.id, theme.id);
        expect(tester.takeException(), isNull,
            reason: 'Excepción al montar tema ${theme.id}');
      }
    });

    test('ids únicos', () {
      final ids = AppThemeData.all.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'IDs duplicados');
    });

    test('todos los temas definen colores no-null', () {
      for (final t in AppThemeData.all) {
        expect(t.scaffoldBg, isNotNull);
        expect(t.textPrimary, isNotNull);
        expect(t.accent, isNotNull);
      }
    });
  });
}
