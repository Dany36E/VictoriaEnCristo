/// Bandeja de herramientas del lienzo: plumas dibujadas con la punta del
/// color elegido; la herramienta activa sobresale, como en Notas.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../vec/vec_tema.dart';

/// Herramientas de la bandeja (las cuatro de tinta, el borrador y el lazo).
enum HerramientaLienzo { pluma, lapiz, marcador, resaltador, borrador, lazo }

extension NombreHerramienta on HerramientaLienzo {
  String get nombre => switch (this) {
    HerramientaLienzo.pluma => 'Pluma',
    HerramientaLienzo.lapiz => 'Lápiz',
    HerramientaLienzo.marcador => 'Marcador',
    HerramientaLienzo.resaltador => 'Resaltador',
    HerramientaLienzo.borrador => 'Borrador',
    HerramientaLienzo.lazo => 'Lazo para mover',
  };
}

class BandejaHerramientas extends StatelessWidget {
  const BandejaHerramientas({
    super.key,
    required this.activa,
    required this.colorDe,
    required this.onElegir,
  });

  final HerramientaLienzo activa;
  final Color Function(HerramientaLienzo) colorDe;
  final ValueChanged<HerramientaLienzo> onElegir;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in HerramientaLienzo.values)
          _Pluma(
            herramienta: h,
            color: colorDe(h),
            activa: h == activa,
            onTap: () {
              HapticFeedback.selectionClick();
              onElegir(h);
            },
          ),
      ],
    );
  }
}

class _Pluma extends StatelessWidget {
  const _Pluma({
    required this.herramienta,
    required this.color,
    required this.activa,
    required this.onTap,
  });

  final HerramientaLienzo herramienta;
  final Color color;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      label: herramienta.nombre,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: herramienta.nombre,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 64,
            child: ClipRect(
              child: AnimatedSlide(
                offset: Offset(0, activa ? 0 : 0.22),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: CustomPaint(
                  painter: _PintorPluma(herramienta, color),
                  size: const Size(46, 64),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorPluma extends CustomPainter {
  _PintorPluma(this.herramienta, this.color);

  final HerramientaLienzo herramienta;
  final Color color;

  static const _cuerpo = Color(0xFFFBF7EE);
  static const _contorno = Color(0xFF3A332C);
  static const _madera = Color(0xFFE8C39A);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final trazo = Paint()
      ..color = _contorno
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final relleno = Paint()..color = _cuerpo;
    final tinta = Paint()..color = color;

    void figura(Path p, Paint pintura) {
      canvas.drawPath(p, pintura);
      canvas.drawPath(p, trazo);
    }

    Path cuerpo(double ancho, double arriba) => Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - ancho / 2, arriba, ancho, size.height - arriba + 4),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
      );

    switch (herramienta) {
      case HerramientaLienzo.pluma:
        figura(
          Path()
            ..moveTo(cx - 9, 26)
            ..lineTo(cx, 4)
            ..lineTo(cx + 9, 26)
            ..close(),
          Paint()..color = const Color(0xFFC4C9D0),
        );
        canvas.drawLine(Offset(cx, 8), Offset(cx, 20), trazo);
        figura(cuerpo(18, 26), relleno);
        canvas.drawRect(Rect.fromLTWH(cx - 9, 30, 18, 6), tinta);
      case HerramientaLienzo.lapiz:
        figura(
          Path()
            ..moveTo(cx - 8, 26)
            ..lineTo(cx, 6)
            ..lineTo(cx + 8, 26)
            ..close(),
          Paint()..color = _madera,
        );
        figura(
          Path()
            ..moveTo(cx - 3.2, 14)
            ..lineTo(cx, 6)
            ..lineTo(cx + 3.2, 14)
            ..close(),
          tinta,
        );
        figura(cuerpo(16, 26), Paint()..color = color);
        canvas.drawLine(Offset(cx - 3, 30), Offset(cx - 3, size.height), trazo);
        canvas.drawLine(Offset(cx + 3, 30), Offset(cx + 3, size.height), trazo);
      case HerramientaLienzo.marcador:
        figura(
          Path()
            ..moveTo(cx - 7, 24)
            ..lineTo(cx - 4, 8)
            ..lineTo(cx + 4, 6)
            ..lineTo(cx + 7, 24)
            ..close(),
          tinta,
        );
        figura(cuerpo(22, 24), relleno);
        canvas.drawRect(Rect.fromLTWH(cx - 11, 28, 22, 8), tinta);
      case HerramientaLienzo.resaltador:
        figura(
          Path()
            ..moveTo(cx - 9, 24)
            ..lineTo(cx - 8, 8)
            ..lineTo(cx + 8, 12)
            ..lineTo(cx + 9, 24)
            ..close(),
          Paint()..color = color.withValues(alpha: 0.75),
        );
        figura(cuerpo(24, 24), relleno);
        canvas.drawRect(
          Rect.fromLTWH(cx - 12, 30, 24, 10),
          Paint()..color = color.withValues(alpha: 0.75),
        );
      case HerramientaLienzo.borrador:
        figura(
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(cx - 12, 8, 24, 22),
                const Radius.circular(4),
              ),
            ),
          Paint()..color = const Color(0xFFF1A9A0),
        );
        figura(cuerpo(24, 30), Paint()..color = VecColores.verde);
      case HerramientaLienzo.lazo:
        final lazo = Paint()
          ..color = _contorno
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        final c = Offset(cx, 22);
        const r = 13.0;
        for (var a = 0.0; a < 2 * math.pi; a += math.pi / 6) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            a,
            math.pi / 10,
            false,
            lazo,
          );
        }
        figura(cuerpo(16, 40), relleno);
    }
  }

  @override
  bool shouldRepaint(_PintorPluma old) =>
      old.herramienta != herramienta || old.color != color;
}
