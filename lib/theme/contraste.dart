import 'package:flutter/material.dart';

/// Contraste WCAG entre dos colores (1 a 21). Los colores con transparencia
/// se mezclan primero sobre [fondo].
double contrasteWcag(Color texto, Color fondo) {
  final lt = Color.alphaBlend(texto, fondo).computeLuminance();
  final lf = fondo.computeLuminance();
  return lt > lf ? (lt + 0.05) / (lf + 0.05) : (lf + 0.05) / (lt + 0.05);
}

/// [color] ajustado para leerse sobre [fondo] con al menos [minimo] de
/// contraste (WCAG AA: 4.5 en texto normal, 3 en texto grande). Conserva el
/// tono: lo oscurece sobre fondos claros y lo aclara sobre oscuros, solo lo
/// necesario. Si ya se lee, lo devuelve igual.
///
/// Sirve para los colores fijos de categorías, insignias y dorados, que se
/// ven bien en los temas oscuros pero se pierden en los claros.
Color legibleSobre(Color color, Color fondo, {double minimo = 4.5}) {
  if (contrasteWcag(color, fondo) >= minimo) return color;
  // Un poco de margen: el fondo real varía (textura, mezclas, redondeo).
  final meta = minimo + 0.2;
  final hsl = HSLColor.fromColor(Color.alphaBlend(color, fondo));
  // Por encima de esta luminancia el texto oscuro contrasta más que el claro.
  final oscurecer = fondo.computeLuminance() > 0.179;
  for (var paso = 1; paso <= 20; paso++) {
    final l = oscurecer
        ? hsl.lightness * (1 - paso / 20)
        : hsl.lightness + (1 - hsl.lightness) * paso / 20;
    final candidato = hsl.withLightness(l).toColor();
    if (contrasteWcag(candidato, fondo) >= meta) return candidato;
  }
  return oscurecer ? Colors.black : Colors.white;
}

/// Texto de [color] sobre una pastilla del mismo color al [alpha] de
/// opacidad encima de [base] (insignias y chips de categoría). También sirve
/// como fondo de la pastilla seleccionada con texto del color de [base].
Color legibleEnPastilla(Color color, double alpha, Color base) =>
    legibleSobre(color, Color.alphaBlend(color.withValues(alpha: alpha), base));
