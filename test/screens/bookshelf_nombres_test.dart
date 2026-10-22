import 'package:app_quitar/screens/learning/bookshelf_screen.dart';
import 'package:app_quitar/services/learning/book_repository.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual/theme_matrix.dart';

/// Como el escalado de Android 14+: las letras chicas crecen más que las
/// grandes, así que agrandar 1.5 veces no es multiplicar el ancho por 1.5.
class _EscalaNoLineal extends TextScaler {
  const _EscalaNoLineal(this.factor);
  final double factor;

  @override
  double scale(double fontSize) {
    final peso = ((40 - fontSize) / 30).clamp(0.2, 1.0);
    return fontSize * (1 + (factor - 1) * peso);
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => factor;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) => this;

  @override
  bool operator ==(Object other) =>
      other is _EscalaNoLineal && other.factor == factor;

  @override
  int get hashCode => factor.hashCode;
}

/// Ninguna palabra del nombre de un libro se parte a la mitad en su lomo
/// («Deuteronomi / o»), en ningún ancho ni tamaño de letra del sistema.
void main() {
  setUpThemeMatrix();
  setUpAll(() => BookRepository.I.load());

  for (final tema in ['papel', 'night_pure']) {
    for (final (nombreEscala, escala) in <(String, TextScaler)>[
      ('1x', TextScaler.noScaling),
      ('1.3x', const TextScaler.linear(1.3)),
      ('1.15x no lineal', const _EscalaNoLineal(1.15)),
      ('1.5x no lineal', const _EscalaNoLineal(1.5)),
      ('2x no lineal', const _EscalaNoLineal(2)),
    ]) {
      testWidgets('nombres sin partir ($tema, letra $nombreEscala)', (
        tester,
      ) async {
        await tester.runAsync(() => ThemeService().setTheme(tema));
        final theme = AppThemeData.all.firstWhere((t) => t.id == tema);
        for (final ancho in [320.0, 360.0, 393.0, 411.0, 430.0]) {
          tester.view.devicePixelRatio = 1;
          // Alta para que se construyan los libros del Antiguo Testamento.
          tester.view.physicalSize = Size(ancho, 5000);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.isPaper ? AppTheme.paperTheme : AppTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: escala),
                child: child!,
              ),
              home: AppThemeData.provider(
                theme: theme,
                child: const BookshelfScreen(),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));

          // Las dos pestañas: el Nuevo Testamento tiene la palabra más
          // larga («Tesalonicenses»).
          for (final pestana in ['Antiguo', 'Nuevo']) {
            if (pestana == 'Nuevo') {
              await tester.tap(find.textContaining('Nuevo Testamento'));
              await tester.pump(const Duration(milliseconds: 600));
            }
            var revisados = 0;
            for (final libro in BookRepository.I.all) {
              final hallado = find.text(libro.name);
              if (hallado.evaluate().isEmpty) continue;
              revisados++;
              final parrafo = tester.renderObject<RenderParagraph>(
                hallado.first,
              );
              var inicio = 0;
              for (final palabra in libro.name.split(' ')) {
                // Todas las letras de la palabra en el mismo renglón.
                final cajas = parrafo.getBoxesForSelection(
                  TextSelection(
                    baseOffset: inicio,
                    extentOffset: inicio + palabra.length,
                  ),
                );
                expect(
                  cajas.map((c) => c.top.round()).toSet(),
                  hasLength(1),
                  reason: '«${libro.name}» a $ancho px partió «$palabra»',
                );
                inicio += palabra.length + 1;
              }
            }
            expect(revisados, greaterThan(20), reason: '$pestana, $ancho px');
          }
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 11));
      });
    }
  }
}
