import 'package:app_quitar/screens/learning/game_headbanz_screen.dart';
import 'package:app_quitar/services/pantalla_encendida.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual/theme_matrix.dart';

/// En «¿Quién soy?» el celular va en la frente: la pantalla debe quedarse
/// encendida mientras se juega y volver a la normalidad al salir.
void main() {
  setUpThemeMatrix();

  late List<bool> llamadas;

  setUp(() {
    llamadas = <bool>[];
    PantallaEncendida.implementacionParaPruebas = (activar) async {
      llamadas.add(activar);
    };
  });

  tearDown(() => PantallaEncendida.implementacionParaPruebas = null);

  testWidgets('se activa al jugar y se libera al salir', (tester) async {
    // Pantalla alta para que el botón de empezar esté construido.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.paperTheme,
        builder: (context, child) =>
            AppThemeData.provider(theme: AppThemeData.paper, child: child!),
        home: const GameHeadbanzScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // En la introducción la pantalla se apaga como siempre.
    expect(llamadas, isEmpty);

    final empezar = find.text('¡Empezar a jugar!');
    await tester.ensureVisible(empezar);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(empezar);
    await tester.pump(const Duration(milliseconds: 300));
    expect(llamadas, [true]);

    // Cuenta regresiva y unos segundos de carta: sigue encendida.
    await tester.pump(const Duration(seconds: 5));
    expect(llamadas, [true]);

    // Salir del juego devuelve el apagado automático al sistema.
    await tester.pumpWidget(const SizedBox.shrink());
    expect(llamadas.last, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  test('si la plataforma falla, no rompe el juego', () async {
    PantallaEncendida.implementacionParaPruebas = (_) async =>
        throw UnsupportedError('sin wakelock');
    await PantallaEncendida.mantener(true);
  });
}
