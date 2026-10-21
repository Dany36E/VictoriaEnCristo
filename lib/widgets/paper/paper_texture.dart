import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Grano y fibras de papel sobre toda la app (tema "Papel recortado").
///
/// Se pinta una sola vez (RepaintBoundary + shouldRepaint=false) y no
/// intercepta toques. Opacidades muy bajas para no afectar la legibilidad.
class PaperTextureOverlay extends StatelessWidget {
  final Widget child;

  /// Si es false no pinta nada, pero mantiene la misma estructura del árbol
  /// para que [child] no se recree al alternar el tema.
  final bool enabled;

  const PaperTextureOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (enabled)
          const Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _PaperGrainPainter()),
              ),
            ),
          ),
      ],
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  const _PaperGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Semilla fija: la textura no "baila" entre repintados.
    final rnd = math.Random(7);
    final dark = Paint()..color = const Color(0x0D5B4630);
    final light = Paint()..color = const Color(0x14FFFFFF);

    // Grano: puntos diminutos claros y oscuros.
    final grains = (size.width * size.height / 70).round();
    for (var i = 0; i < grains; i++) {
      final o = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      canvas.drawCircle(
        o,
        0.4 + rnd.nextDouble() * 0.7,
        rnd.nextBool() ? dark : light,
      );
    }

    // Fibras: trazos cortos y curvos, casi invisibles.
    final fiber = Paint()
      ..color = const Color(0x0A5B4630)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    final fibers = (size.width * size.height / 2600).round();
    for (var i = 0; i < fibers; i++) {
      final start = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      final angle = rnd.nextDouble() * math.pi * 2;
      final len = 6 + rnd.nextDouble() * 14;
      final end = start + Offset(math.cos(angle), math.sin(angle)) * len;
      final ctrl =
          Offset.lerp(start, end, 0.5)! +
          Offset(rnd.nextDouble() * 4 - 2, rnd.nextDouble() * 4 - 2);
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
        fiber,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) => false;
}
