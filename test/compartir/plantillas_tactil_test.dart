import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_quitar/models/bible/bible_verse.dart';
import 'package:app_quitar/screens/bible/template_picker_screen.dart';
import 'package:app_quitar/services/bible/bible_user_data_service.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:app_quitar/vec/vec_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual/theme_matrix.dart';
import '../visual/visual_checks.dart';

const _verso = BibleVerse(
  bookName: 'Filipenses',
  bookNumber: 50,
  chapter: 4,
  verse: 13,
  text: 'Todo lo puedo en Cristo que me fortalece.',
  version: 'RVR1960',
);

/// Con «Personalizar» abierto, todos los controles de la pantalla de
/// plantillas se pueden tocar (48×48) y tienen nombre para el lector.
void main() {
  setUpThemeMatrix();

  for (final (tema, tamano, letra) in [
    for (final t in AppThemeData.all) (t.id, const Size(360, 800), 1.0),
    // Teléfono chico con letra del sistema al doble.
    ('papel', const Size(320, 568), 2.0),
    ('night_pure', const Size(320, 568), 2.0),
  ]) {
    testWidgets('plantillas con Personalizar abierto ($tema, '
        '${tamano.width.round()} px, letra ${letra}x)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = tamano;
      addTearDown(tester.view.reset);
      BibleUserDataService.I.readerThemeNotifier.value = tema;
      await tester.runAsync(() => ThemeService().setTheme(tema));
      final theme = AppThemeData.all.firstWhere((t) => t.id == tema);
      final llave = GlobalKey();
      final manejador = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.isPaper ? AppTheme.paperTheme : AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(letra)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: llave,
            // Como en la app: en papel la hoja con textura va detrás.
            child: DecoratedBox(
              decoration: theme.isPaper
                  ? FondoPapel.decoracion
                  : BoxDecoration(color: theme.scaffoldBg),
              child: AppThemeData.provider(
                theme: theme,
                child: const TemplatePickerScreen(verse: _verso),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Personalizar'));
      // Un cuadro para empezar a abrir el panel y otro con la animación ya
      // terminada (dura 250 ms).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      // El panel quedó abierto: sus controles también se revisan.
      expect(find.text('TAMAÑO'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      if (letra == 1) {
        // Contraste de los textos del panel (en la matriz se dibuja cerrado).
        final limite =
            llave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final (imagen, pixeles) = (await tester.runAsync(
          () => capturarPixeles(limite),
        ))!;
        final problemas = problemasDeContraste(limite, imagen, pixeles);
        imagen.dispose();
        expect(problemas, isEmpty);
      }

      // Captura para revisar a ojo el panel abierto (un cuadro antes: las
      // imágenes que terminaron de cargar piden redibujar).
      await tester.pump();
      await tester.runAsync(() async {
        final limite =
            llave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final imagen = await limite.toImage();
        final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
        final archivo = File(
          'build/qa/plantillas_personalizar_${tema}_${tamano.width.round()}.png',
        );
        await archivo.parent.create(recursive: true);
        await archivo.writeAsBytes(png!.buffer.asUint8List());
        imagen.dispose();
      });
      manejador.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    });
  }
}
