// Pruebas de las propias comprobaciones visuales: deben fallar con los
// errores que queremos atrapar y pasar con una pantalla correcta.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_checks.dart';

void main() {
  Future<void> revisarTexto(WidgetTester tester, Widget hijo) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 200);
    addTearDown(tester.view.reset);
    final clave = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(key: clave, child: hijo),
      ),
    );
    final limite =
        clave.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final (imagen, pixeles) = (await tester.runAsync(
      () => capturarPixeles(limite),
    ))!;
    try {
      expectReadableText(tester, limite, imagen, pixeles);
    } finally {
      imagen.dispose();
    }
  }

  Future<void> debeFallar(Future<void> revision) async {
    try {
      await revision;
    } on TestFailure {
      return;
    }
    fail('La comprobación debió reportar el problema');
  }

  Widget sobre(Color fondo, TextStyle estilo) => Material(
    color: fondo,
    child: Center(child: Text('Texto de prueba', style: estilo)),
  );

  testWidgets('texto negro sobre fondo oscuro falla', (tester) async {
    await debeFallar(
      revisarTexto(
        tester,
        sobre(const Color(0xFF0A0A12), const TextStyle(color: Colors.black)),
      ),
    );
  });

  testWidgets('texto con 30 % de opacidad falla', (tester) async {
    await debeFallar(
      revisarTexto(
        tester,
        sobre(
          Colors.white,
          TextStyle(color: Colors.black.withValues(alpha: 0.3)),
        ),
      ),
    );
  });

  testWidgets('texto blanco grueso sobre dorado claro falla', (tester) async {
    await debeFallar(
      revisarTexto(
        tester,
        sobre(
          const Color(0xFFD4A853),
          const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  });

  testWidgets('texto legible pasa', (tester) async {
    await revisarTexto(
      tester,
      sobre(const Color(0xFF0A0A12), const TextStyle(color: Colors.white)),
    );
  });

  testWidgets('FAB extendido con forma de círculo falla', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            shape: CircleBorder(),
          ),
        ),
        home: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Nueva oración'),
          ),
        ),
      ),
    );
    expect(
      () => expectButtonBackgroundsCoverContent(tester),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('FAB extendido con píldora pasa', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Nueva oración'),
          ),
        ),
      ),
    );
    expectButtonBackgroundsCoverContent(tester);
  });
}
