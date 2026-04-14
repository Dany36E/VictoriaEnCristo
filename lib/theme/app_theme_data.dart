import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// APP THEME DATA — 9 temas seleccionables para toda la app
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Extiende el concepto de BibleReaderThemeData a la UI general.
/// Mismos 9 IDs, paletas derivadas para scaffold, cards, texto, acentos.
///
/// Uso: final t = AppThemeData.of(context);
///      Scaffold(backgroundColor: t.scaffoldBg, ...)
/// ═══════════════════════════════════════════════════════════════════════════

class AppThemeData {
  final String id;
  final String name;
  final Color scaffoldBg;
  final Color surface;       // toolbars, appbar, nav
  final Color cardBg;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;        // gold / tema-color family
  final Color accentSoft;    // accent at ~20% opacity for subtle backgrounds
  final Color divider;
  final Color inputBg;       // text fields, search bars
  final bool isDark;

  const AppThemeData({
    required this.id,
    required this.name,
    required this.scaffoldBg,
    required this.surface,
    required this.cardBg,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentSoft,
    required this.divider,
    required this.inputBg,
    required this.isDark,
  });

  // Helpers derivados
  Color get overlayBg => isDark
      ? Colors.white.withOpacity(0.06)
      : Colors.black.withOpacity(0.04);

  Color get shimmerBase => isDark
      ? Colors.white.withOpacity(0.05)
      : Colors.black.withOpacity(0.04);

  Color get shimmerHighlight => isDark
      ? Colors.white.withOpacity(0.1)
      : Colors.black.withOpacity(0.08);

  /// Gradient para headers (sutil, del surface hacia scaffoldBg)
  LinearGradient get headerGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surface, scaffoldBg],
  );

  /// Shadow adaptativo
  List<BoxShadow> get cardShadow => isDark
      ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ];

  /// Card decoration completa
  BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: cardBorder, width: 1),
    boxShadow: cardShadow,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // 9 TEMAS — mismos IDs que BibleReaderThemeData
  // ══════════════════════════════════════════════════════════════════════════

  // ─── DARK THEMES ───────────────────────────────────────────────────────

  static const nightPure = AppThemeData(
    id: 'night_pure',
    name: 'Noche pura',
    scaffoldBg: Color(0xFF050A12),
    surface: Color(0xFF0D1B2A),
    cardBg: Color(0xFF1B263B),
    cardBorder: Color(0x14FFFBF5), // pureWhite 8%
    textPrimary: Color(0xFFFFFBF5),
    textSecondary: Color(0xFFB8B5AF),
    accent: Color(0xFFD4A853),
    accentSoft: Color(0x33D4A853),
    divider: Color(0x14FFFBF5),
    inputBg: Color(0xFF1B263B),
    isDark: true,
  );

  static const charcoalEditorial = AppThemeData(
    id: 'charcoal',
    name: 'Carbón editorial',
    scaffoldBg: Color(0xFF141414),
    surface: Color(0xFF1A1A1A),
    cardBg: Color(0xFF242424),
    cardBorder: Color(0x14E8E8E8),
    textPrimary: Color(0xFFE8E8E8),
    textSecondary: Color(0xFF888888),
    accent: Color(0xFFD4AF37),
    accentSoft: Color(0x33D4AF37),
    divider: Color(0x14E8E8E8),
    inputBg: Color(0xFF242424),
    isDark: true,
  );

  static const sepiaNocturno = AppThemeData(
    id: 'sepia_night',
    name: 'Sepia nocturno',
    scaffoldBg: Color(0xFF12100A),
    surface: Color(0xFF1C1408),
    cardBg: Color(0xFF261C0E),
    cardBorder: Color(0x14E8D5A3),
    textPrimary: Color(0xFFE8D5A3),
    textSecondary: Color(0xFF8B7355),
    accent: Color(0xFFD4AF37),
    accentSoft: Color(0x33D4AF37),
    divider: Color(0x14E8D5A3),
    inputBg: Color(0xFF261C0E),
    isDark: true,
  );

  // ─── LIGHT THEMES ──────────────────────────────────────────────────────

  static const cleanPage = AppThemeData(
    id: 'clean_page',
    name: 'Página limpia',
    scaffoldBg: Color(0xFFF8F8F8),
    surface: Color(0xFFFFFFFF),
    cardBg: Color(0xFFFFFFFF),
    cardBorder: Color(0x0F1A1A1A),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF757575),
    accent: Color(0xFFB8960C),
    accentSoft: Color(0x1AB8960C),
    divider: Color(0x0F1A1A1A),
    inputBg: Color(0xFFF2F2F2),
    isDark: false,
  );

  static const parchment = AppThemeData(
    id: 'parchment',
    name: 'Pergamino',
    scaffoldBg: Color(0xFFF5F0E8),
    surface: Color(0xFFFAF6EF),
    cardBg: Color(0xFFFFFBF5),
    cardBorder: Color(0x143E2723),
    textPrimary: Color(0xFF3E2723),
    textSecondary: Color(0xFF795548),
    accent: Color(0xFF8B6914),
    accentSoft: Color(0x1A8B6914),
    divider: Color(0x143E2723),
    inputBg: Color(0xFFFAF6EF),
    isDark: false,
  );

  static const greyEditorial = AppThemeData(
    id: 'grey_editorial',
    name: 'Gris editorial',
    scaffoldBg: Color(0xFFF0F0F0),
    surface: Color(0xFFFFFFFF),
    cardBg: Color(0xFFFAFAFA),
    cardBorder: Color(0x0F212121),
    textPrimary: Color(0xFF212121),
    textSecondary: Color(0xFF757575),
    accent: Color(0xFFB8960C),
    accentSoft: Color(0x1AB8960C),
    divider: Color(0x0F212121),
    inputBg: Color(0xFFE8E8E8),
    isDark: false,
  );

  static const lavender = AppThemeData(
    id: 'lavender',
    name: 'Lavanda suave',
    scaffoldBg: Color(0xFFEDE7F6),
    surface: Color(0xFFF3EDF7),
    cardBg: Color(0xFFFFFBFF),
    cardBorder: Color(0x14311B92),
    textPrimary: Color(0xFF311B92),
    textSecondary: Color(0xFF6A1B9A),
    accent: Color(0xFF7B1FA2),
    accentSoft: Color(0x1A7B1FA2),
    divider: Color(0x14311B92),
    inputBg: Color(0xFFF3EDF7),
    isDark: false,
  );

  static const mint = AppThemeData(
    id: 'mint',
    name: 'Menta editorial',
    scaffoldBg: Color(0xFFE8F5E9),
    surface: Color(0xFFEEF7EF),
    cardBg: Color(0xFFFAFDFA),
    cardBorder: Color(0x141B5E20),
    textPrimary: Color(0xFF1B5E20),
    textSecondary: Color(0xFF2E7D32),
    accent: Color(0xFF2E7D32),
    accentSoft: Color(0x1A2E7D32),
    divider: Color(0x141B5E20),
    inputBg: Color(0xFFEEF7EF),
    isDark: false,
  );

  static const peach = AppThemeData(
    id: 'peach',
    name: 'Durazno suave',
    scaffoldBg: Color(0xFFFFF3E0),
    surface: Color(0xFFFFF8EE),
    cardBg: Color(0xFFFFFDF9),
    cardBorder: Color(0x14BF360C),
    textPrimary: Color(0xFFBF360C),
    textSecondary: Color(0xFFBF6B00),
    accent: Color(0xFFE65100),
    accentSoft: Color(0x1AE65100),
    divider: Color(0x14BF360C),
    inputBg: Color(0xFFFFF8EE),
    isDark: false,
  );

  /// Todos los temas disponibles
  static const List<AppThemeData> all = [
    nightPure,
    charcoalEditorial,
    sepiaNocturno,
    cleanPage,
    parchment,
    greyEditorial,
    lavender,
    mint,
    peach,
  ];

  /// Obtener tema por ID (default: noche pura)
  static AppThemeData fromId(String id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => nightPure,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INHERITED WIDGET — Acceso via AppThemeData.of(context)
  // ══════════════════════════════════════════════════════════════════════════

  static AppThemeData of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<_AppThemeInherited>();
    return inherited?.theme ?? nightPure;
  }

  /// Wrap your MaterialApp's child with this to provide the theme
  static Widget provider({
    required AppThemeData theme,
    required Widget child,
  }) {
    return _AppThemeInherited(theme: theme, child: child);
  }
}

class _AppThemeInherited extends InheritedWidget {
  final AppThemeData theme;

  const _AppThemeInherited({
    required this.theme,
    required super.child,
  });

  @override
  bool updateShouldNotify(_AppThemeInherited oldWidget) {
    return theme.id != oldWidget.theme.id;
  }
}
