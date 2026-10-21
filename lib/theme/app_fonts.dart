import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/theme_service.dart';
import 'app_theme_data.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// APP FONTS — Tipografía dependiente del tema
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Reemplazo directo de `GoogleFonts.manrope(...)` / `GoogleFonts.cinzel(...)`
/// (misma firma). En los temas normales devuelve exactamente lo mismo; con el
/// tema "Papel recortado" usa Baloo 2 (redondeada, estilo papercraft).
///
/// Las fuentes están bundled en `google_fonts/` (runtime fetching apagado).
/// ═══════════════════════════════════════════════════════════════════════════
class AppFonts {
  AppFonts._();

  static const String _paperFamily = 'Baloo 2';

  static bool get _isPaper => ThemeService().themeId == AppThemeData.paper.id;

  /// Fuente de interfaz (Manrope → Baloo 2 en tema papel).
  static TextStyle manrope({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final paper = _isPaper;
    return GoogleFonts.getFont(
      paper ? _paperFamily : 'Manrope',
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      // Baloo 2 se ve más ligera que Manrope al mismo peso: un punto más.
      fontWeight: paper ? _oneStepBolder(fontWeight) : fontWeight,
      fontStyle: fontStyle,
      letterSpacing: paper ? _tight(letterSpacing, 0.2) : letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// Fuente de títulos "sagrados" (Cinzel → Baloo 2 gruesa en tema papel).
  static TextStyle cinzel({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final paper = _isPaper;
    return GoogleFonts.getFont(
      paper ? _paperFamily : 'Cinzel',
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      // Los títulos del estilo papel son gruesos y sin tracking amplio.
      fontWeight: paper ? _atLeastBold(fontWeight) : fontWeight,
      fontStyle: fontStyle,
      letterSpacing: paper ? _tight(letterSpacing, 0.3) : letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
  }

  /// El tracking amplio de Manrope/Cinzel separa demasiado a Baloo 2.
  static double? _tight(double? letterSpacing, double max) {
    if (letterSpacing == null || letterSpacing <= max) return letterSpacing;
    return max;
  }

  static FontWeight _oneStepBolder(FontWeight? weight) {
    final value = (weight ?? FontWeight.w400).value;
    // FontWeight.values[i] = w(i+1)00 → índice value/100 es un paso arriba.
    return FontWeight.values[(value ~/ 100).clamp(3, 8)];
  }

  static FontWeight _atLeastBold(FontWeight? weight) {
    if (weight == null || weight.value < FontWeight.w700.value) {
      return FontWeight.w700;
    }
    return weight;
  }
}
