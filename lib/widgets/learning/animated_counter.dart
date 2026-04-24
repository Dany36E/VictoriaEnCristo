/// AnimatedCounter — anima un número entero hacia un valor objetivo.
///
/// Uso típico: dopamina al ganar XP / talentos / estrellas.
///
///   AnimatedCounter(value: 125, duration: 700.ms)
///
/// Por defecto cuenta de 0 → value en `easeOutBack` (overshoot suave).
library;

import 'package:flutter/material.dart';

class AnimatedCounter extends StatelessWidget {
  /// Valor final.
  final int value;

  /// Valor inicial. Por defecto 0 — útil para celebraciones de "+25 XP".
  final int from;

  /// Duración de la cuenta.
  final Duration duration;

  /// Curva de la animación.
  final Curve curve;

  /// Estilo del texto.
  final TextStyle? style;

  /// Prefijo (ej. '+' para "+25 XP").
  final String prefix;

  /// Sufijo (ej. ' XP', ' ★', ' talentos').
  final String suffix;

  /// Alineación horizontal del Text.
  final TextAlign? textAlign;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.from = 0,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutBack,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder<int> garantiza que solo este Text se reconstruye
    // ~60 veces, sin tocar el árbol que lo contiene.
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: from, end: value),
      duration: duration,
      curve: curve,
      builder: (context, displayed, _) {
        // Clamp a >= 0 por si la curva genera overshoot negativo en bajos.
        final v = displayed < 0 ? 0 : displayed;
        return Text(
          '$prefix$v$suffix',
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }
}
