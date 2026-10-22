import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:app_quitar/widgets/selector_modo_papel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../visual/theme_matrix.dart';

void main() {
  setUpThemeMatrix();

  for (final letra in [1.0, 2.0]) {
    testWidgets('el selector cabe y cambia el modo (letra ${letra}x)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        await ThemeService().initialize();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.paperTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(letra)),
            child: AppThemeData.provider(
              theme: ThemeService().currentTheme,
              child: child!,
            ),
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: SelectorModoPapel(),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      // Cada opción se ve completa (se achica, no se corta).
      for (final nombre in ['Claro', 'Oscuro', 'Automático', 'Kraft', 'Noche']) {
        final texto = find.text(nombre);
        expect(texto, findsOneWidget, reason: nombre);
        final parrafo = tester.renderObject<RenderParagraph>(texto);
        expect(parrafo.didExceedMaxLines, isFalse, reason: nombre);
      }

      await tester.tap(find.text('Oscuro'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(ThemeService().modo, ModoTema.oscuro);
      await tester.tap(find.text('Noche'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(ThemeService().themeId, 'papel_noche');
      await tester.tap(find.text('Claro'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(ThemeService().themeId, 'papel');
    });
  }
}
