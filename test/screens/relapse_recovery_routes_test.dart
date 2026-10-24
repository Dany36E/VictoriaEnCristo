// Tras una recaída, "Escribir en mi diario" y "Orar un momento" deben abrir
// pantallas reales (antes iban a rutas inexistentes y caían en Inicio).
import 'package:app_quitar/screens/journal_entry_editor.dart';
import 'package:app_quitar/screens/prayers_screen.dart';
import 'package:app_quitar/screens/relapse_recovery_screen.dart';
import 'package:app_quitar/services/victory_scoring_service.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Observador extends NavigatorObserver {
  final empujadas = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    empujadas.add(route);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    VictoryScoringService.I.resetForTesting();
    await VictoryScoringService.I.initForTesting(giants: ['sexual']);
  });
  tearDown(VictoryScoringService.I.resetForTesting);

  test('los destinos son las pantallas reales', () {
    expect(destinoDiario(), isA<JournalEntryEditor>());
    expect(destinoOracion(), isA<PrayersScreen>());
  });

  testWidgets('"Escribir en mi diario" abre el editor del diario', (
    tester,
  ) async {
    // Ancho: la fuente de pruebas es más ancha que la real y el encabezado
    // del editor (no es parte de esta prueba) se desbordaría.
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final obs = _Observador();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [obs],
        home: AppThemeData.provider(
          theme: AppThemeData.paper,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RelapseRecoveryScreen(brokenStreak: 5),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    final opcion = find.text('Escribir en mi diario');
    await tester.scrollUntilVisible(opcion, 200);
    await tester.tap(opcion);
    await tester.pumpAndSettle();
    expect(find.byType(JournalEntryEditor), findsOneWidget);
    expect(find.byType(RelapseRecoveryScreen), findsNothing);
  });
}
