import 'package:flutter/material.dart';

/// Portada editorial propia de Victoria en Cristo.
///
/// Sustituye fotografías remotas por un paisaje abstracto reproducible: capas
/// de terreno, un sendero ascendente y luz contenida. Es decorativo, no carga
/// datos de terceros y mantiene el foco en el contenido superpuesto.
class BrandBackdrop extends StatelessWidget {
  final Color accent;

  const BrandBackdrop({super.key, this.accent = const Color(0xFFE0B93D)});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BrandBackdropPainter(accent),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _BrandBackdropPainter extends CustomPainter {
  final Color accent;

  const _BrandBackdropPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07131F), Color(0xFF102B40), Color(0xFF06101A)],
          stops: [0, 0.52, 1],
        ).createShader(bounds),
    );

    final light = Path()
      ..moveTo(size.width * 0.43, size.height)
      ..lineTo(size.width * 0.72, 0)
      ..lineTo(size.width * 0.88, 0)
      ..lineTo(size.width * 0.57, size.height)
      ..close();
    canvas.drawPath(
      light,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [accent.withValues(alpha: 0), accent.withValues(alpha: 0.12)],
        ).createShader(bounds),
    );

    _drawRidge(canvas, size, const Color(0xFF24465B), 0.46, const [
      0.18,
      0.42,
      0.31,
      0.54,
      0.43,
      0.48,
      0.62,
      0.65,
    ]);
    _drawRidge(canvas, size, const Color(0xFF153449), 0.60, const [
      0.14,
      0.73,
      0.34,
      0.51,
      0.56,
      0.69,
      0.76,
      0.55,
    ]);
    _drawRidge(canvas, size, const Color(0xFF0A2132), 0.75, const [
      0.17,
      0.58,
      0.38,
      0.80,
      0.59,
      0.63,
      0.83,
      0.77,
    ]);

    final trail = Path()
      ..moveTo(size.width * 0.36, size.height)
      ..cubicTo(
        size.width * 0.43,
        size.height * 0.82,
        size.width * 0.54,
        size.height * 0.73,
        size.width * 0.62,
        size.height * 0.57,
      )
      ..cubicTo(
        size.width * 0.67,
        size.height * 0.47,
        size.width * 0.69,
        size.height * 0.34,
        size.width * 0.73,
        size.height * 0.20,
      );
    canvas.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.012
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            accent.withValues(alpha: 0.15),
            accent.withValues(alpha: 0.82),
          ],
        ).createShader(bounds),
    );

    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.34 + i * 0.09);
      final contour = Path()
        ..moveTo(-size.width * 0.08, y)
        ..cubicTo(
          size.width * 0.23,
          y - size.height * 0.045,
          size.width * 0.44,
          y + size.height * 0.055,
          size.width * 1.08,
          y - size.height * 0.025,
        );
      canvas.drawPath(
        contour,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFB7D0DD).withValues(alpha: 0.07),
      );
    }
  }

  void _drawRidge(
    Canvas canvas,
    Size size,
    Color color,
    double baseline,
    List<double> points,
  ) {
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, size.height * baseline);
    for (var i = 0; i < points.length; i += 2) {
      path.lineTo(size.width * points[i], size.height * points[i + 1]);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BrandBackdropPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
