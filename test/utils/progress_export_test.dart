import 'dart:ui' as ui;

import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:app_quitar/utils/progress_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La pantalla de Progreso es transparente: sin el fondo, la imagen que se
/// comparte salía negra.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> transparente() {
    final grabadora = ui.PictureRecorder();
    Canvas(grabadora);
    return grabadora.endRecording().toImage(8, 8);
  }

  Future<Color> pixel(ui.Image imagen) async {
    final datos = (await imagen.toByteData())!;
    final (r, g, b, a) = (
      datos.getUint8(0),
      datos.getUint8(1),
      datos.getUint8(2),
      datos.getUint8(3),
    );
    return Color.fromARGB(a, r, g, b);
  }

  testWidgets('la imagen de progreso lleva el fondo del tema', (tester) async {
    await tester.runAsync(() async {
      // Papel oscuro: café con la textura teñida, opaco y oscuro.
      final conKraft = await ProgressExport.conFondo(
        await transparente(),
        AppThemeData.paperKraft,
      );
      final kraft = await pixel(conKraft);
      expect((kraft.a * 255).round(), 255);
      expect(kraft.computeLuminance(), lessThan(0.05));
      conKraft.dispose();

      // Papel: crema con la textura encima, opaco y claro.
      final conPapel = await ProgressExport.conFondo(
        await transparente(),
        AppThemeData.paper,
      );
      final color = await pixel(conPapel);
      expect((color.a * 255).round(), 255);
      expect(color.computeLuminance(), greaterThan(0.5));
      conPapel.dispose();
    });
  });
}
