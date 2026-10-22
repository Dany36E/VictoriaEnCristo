import 'package:app_quitar/screens/learning/bookshelf_screen.dart';
import 'package:app_quitar/services/learning/book_repository.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual/theme_matrix.dart';

/// Los nombres de una sola palabra larga no se parten a la mitad en el lomo
/// del libro («Deuteronomi / o»), en ningún ancho de pantalla.
void main() {
  setUpThemeMatrix();
  setUpAll(() => BookRepository.I.load());

  for (final tema in ['papel', 'night_pure']) {
    for (final ancho in [320.0, 360.0, 393.0, 411.0, 430.0]) {
      testWidgets('Deuteronomio en un renglón ($tema, $ancho px)', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(ancho, 900);
        addTearDown(tester.view.reset);
        await tester.runAsync(() => ThemeService().setTheme(tema));
        final theme = AppThemeData.all.firstWhere((t) => t.id == tema);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.isPaper ? AppTheme.paperTheme : AppTheme.darkTheme,
            home: AppThemeData.provider(
              theme: theme,
              child: const BookshelfScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        // Deuteronomio está en la primera fila del Pentateuco, a la vista.
        final parrafo = tester.renderObject<RenderParagraph>(
          find.text('Deuteronomio'),
        );
        // Una sola palabra en un renglón: los cortes de línea posibles solo
        // están al final.
        final lineas = parrafo.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 12),
        );
        final renglones = lineas.map((c) => c.top.round()).toSet();
        expect(renglones, hasLength(1));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 11));
      });
    }
  }
}
