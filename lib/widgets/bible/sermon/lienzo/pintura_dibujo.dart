/// Pintura de los dibujos de Apuntes: hoja con su fondo, trazos de tinta,
/// miniaturas y PNG para el PDF.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../models/bible/dibujo_nota.dart';

/// Color de la hoja (papel del kit) y de sus renglones.
const Color colorHoja = Color(0xFFFBF7EE);
const Color colorRenglon = Color(0x262F4A68);
const Color colorMargen = Color(0x40C4553A);

/// Separación de renglones, cuadrícula y puntos en unidades del lienzo.
const double pasoRenglon = 44;

void pintarFondoHoja(Canvas canvas, Size hoja, FondoLienzo fondo) {
  final linea = Paint()
    ..color = colorRenglon
    ..strokeWidth = 1.4;
  switch (fondo) {
    case FondoLienzo.liso:
      return;
    case FondoLienzo.rayado:
      for (var y = pasoRenglon * 2; y < hoja.height; y += pasoRenglon) {
        canvas.drawLine(Offset(0, y), Offset(hoja.width, y), linea);
      }
      canvas.drawLine(
        const Offset(88, 0),
        Offset(88, hoja.height),
        Paint()
          ..color = colorMargen
          ..strokeWidth = 1.6,
      );
    case FondoLienzo.cuadricula:
      for (var y = pasoRenglon; y < hoja.height; y += pasoRenglon) {
        canvas.drawLine(Offset(0, y), Offset(hoja.width, y), linea);
      }
      for (var x = pasoRenglon; x < hoja.width; x += pasoRenglon) {
        canvas.drawLine(Offset(x, 0), Offset(x, hoja.height), linea);
      }
    case FondoLienzo.puntos:
      final punto = Paint()..color = const Color(0x592F4A68);
      for (var y = pasoRenglon; y < hoja.height; y += pasoRenglon) {
        for (var x = pasoRenglon; x < hoja.width; x += pasoRenglon) {
          canvas.drawCircle(Offset(x, y), 2.2, punto);
        }
      }
  }
}

void pintarTrazo(Canvas canvas, Trazo trazo) {
  final color = Color(trazo.color);
  canvas.drawPath(
    trazo.camino,
    Paint()
      ..isAntiAlias = true
      ..color = color.withValues(alpha: color.a * trazo.opacidad),
  );
}

/// Graba los trazos terminados en un `Picture` para no recalcularlos en
/// cada cuadro.
ui.Picture grabarTrazos(List<Trazo> trazos) {
  final grabadora = ui.PictureRecorder();
  final canvas = Canvas(grabadora);
  for (final t in trazos) {
    pintarTrazo(canvas, t);
  }
  return grabadora.endRecording();
}

/// Dibujo completo (hoja, fondo y trazos) escalado al tamaño disponible.
class VistaDibujo extends StatelessWidget {
  const VistaDibujo({
    super.key,
    required this.dibujo,
    this.foto,
    this.conHoja = true,
  });

  final DatosDibujo dibujo;

  /// Foto debajo de las marcas (para fotos marcadas).
  final ui.Image? foto;
  final bool conHoja;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: dibujo.proporcion,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PintorVista(dibujo, foto, conHoja),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PintorVista extends CustomPainter {
  _PintorVista(this.dibujo, this.foto, this.conHoja);

  final DatosDibujo dibujo;
  final ui.Image? foto;
  final bool conHoja;

  @override
  void paint(Canvas canvas, Size size) {
    final escala = size.width / DatosDibujo.ancho;
    canvas.save();
    canvas.scale(escala);
    final hoja = Size(DatosDibujo.ancho, dibujo.alto);
    if (conHoja) {
      canvas.drawRect(Offset.zero & hoja, Paint()..color = colorHoja);
      pintarFondoHoja(canvas, hoja, dibujo.fondo);
    }
    final foto = this.foto;
    if (foto != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & hoja,
        image: foto,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    }
    canvas.clipRect(Offset.zero & hoja);
    for (final t in dibujo.trazos) {
      pintarTrazo(canvas, t);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorVista old) =>
      old.dibujo != dibujo || old.foto != foto || old.conHoja != conHoja;
}

/// PNG del dibujo (para el PDF). [foto] va debajo si son marcas.
Future<Uint8List?> dibujoAPng(
  DatosDibujo dibujo, {
  double anchoPx = 1200,
  ui.Image? foto,
}) async {
  final escala = anchoPx / DatosDibujo.ancho;
  final tam = Size(anchoPx, dibujo.alto * escala);
  final grabadora = ui.PictureRecorder();
  final canvas = Canvas(grabadora);
  _PintorVista(dibujo, foto, foto == null).paint(canvas, tam);
  final imagen = await grabadora.endRecording().toImage(
    tam.width.round(),
    tam.height.round(),
  );
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
  imagen.dispose();
  return datos?.buffer.asUint8List();
}
