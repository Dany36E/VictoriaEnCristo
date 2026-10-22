import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme_data.dart';
import '../vec/vec_tema.dart';

/// Utilidad para capturar un widget como imagen y compartir.
/// Usa RepaintBoundary + toImage para renderizar a PNG.
class ProgressExport {
  ProgressExport._();

  static const double _escala = 3.0;

  /// Captura el widget asociado al [boundaryKey] y lo comparte.
  static Future<void> captureAndShare(
    BuildContext context,
    GlobalKey boundaryKey,
  ) async {
    final tema = AppThemeData.of(context);
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final captura = await boundary.toImage(pixelRatio: _escala);
      final image = await _conFondo(captura, tema);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mi_progreso_victoria.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Mi progreso en Victoria en Cristo 🏆',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  /// El fondo de la página está fuera de la captura (el widget es
  /// transparente): se pinta debajo para que la imagen no salga negra. En el
  /// tema papel es la hoja con textura, igual que FondoPapel.
  static Future<ui.Image> _conFondo(ui.Image captura, AppThemeData tema) async {
    final grabadora = ui.PictureRecorder();
    final lienzo = Canvas(grabadora);
    final rect =
        Offset.zero & Size(captura.width.toDouble(), captura.height.toDouble());
    lienzo.drawRect(
      rect,
      Paint()..color = tema.isPaper ? VecColores.crema : tema.scaffoldBg,
    );
    if (tema.isPaper) {
      final datos = await rootBundle.load(
        'assets/vec/texturas/papel_tile_512.png',
      );
      final codec = await ui.instantiateImageCodec(datos.buffer.asUint8List());
      final textura = (await codec.getNextFrame()).image;
      // FondoPapel la repite a escala 2 (256 lógicos) y a media opacidad.
      final ajuste = Matrix4.diagonal3Values(_escala / 2, _escala / 2, 1);
      lienzo.drawRect(
        rect,
        Paint()
          ..shader = ImageShader(
            textura,
            TileMode.repeated,
            TileMode.repeated,
            ajuste.storage,
          )
          ..color = const Color(0x80000000),
      );
    }
    lienzo.drawImage(captura, Offset.zero, Paint());
    return grabadora.endRecording().toImage(captura.width, captura.height);
  }
}
