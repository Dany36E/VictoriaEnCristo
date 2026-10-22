import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_fonts.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';
import 'app_theme_data.dart';
import 'contraste.dart';
import 'dart:ui';

/// ============================================================================
/// VICTORIA EN CRISTO - DESIGN SYSTEM
/// Award-Winning App Design Language
/// ============================================================================
/// 
/// Philosophy: "Sacred Elegance meets Modern Clarity"
/// 
/// This design system embodies:
/// - Reverence through typography (Cinzel for sacred moments)
/// - Modernity through clean UI (Manrope for interface)
/// - Depth through layered glassmorphism
/// - Soul through haptic feedback and fluid motion
/// ============================================================================

class AppDesignSystem {
  AppDesignSystem._();

  // ══════════════════════════════════════════════════════════════════════════
  // COLOR PALETTE - "Midnight Sanctuary"
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Primary: Midnight Blue - Represents depth, trust, the infinite
  static const Color midnight = Color(0xFF0D1B2A);
  static const Color midnightLight = Color(0xFF1B263B);
  static const Color midnightDeep = Color(0xFF050A12);
  
  /// Accent: Sacred Gold - Represents divinity, victory, hope
  static const Color gold = Color(0xFFD4A853);
  static const Color goldLight = Color(0xFFE8C97A);
  static const Color goldDark = Color(0xFFC19A3E);
  static const Color goldMuted = Color(0xFFB8956E);
  static const Color goldSubtle = Color(0x33D4A853); // 20% opacity

  /// [gold] para texto: en los temas claros se oscurece lo justo para leerse
  /// (WCAG AA) sobre el fondo de la página, o sobre una pastilla dorada de
  /// opacidad [pastilla] encima de ella. En los oscuros queda igual.
  /// Legible sobre la página y sobre las tarjetas: en los papeles oscuros las
  /// tarjetas son más claras que la hoja.
  static Color oroTexto(BuildContext context, {double pastilla = 0}) {
    final t = AppThemeData.of(context);
    return legibleEnPastilla(
      legibleEnPastilla(gold, pastilla, t.fondoVisible),
      pastilla,
      t.cardBg,
    );
  }
  
  /// Neutral: Pure Light - Represents purity, peace, clarity
  static const Color pureWhite = Color(0xFFFFFBF5);
  static const Color softWhite = Color(0xFFF5F1EA);
  static const Color warmGray = Color(0xFFE8E4DD);
  static const Color coolGray = Color(0xFFB8B5AF);
  
  /// Semantic Colors
  static const Color victory = Color(0xFF4CAF50);    // Success/Victory green
  static const Color victoryLight = Color(0xFF81C784);
  static const Color struggle = Color(0xFFE57373);    // Struggle/Alert red
  static const Color struggleLight = Color(0xFFFFCDD2);
  static const Color hope = Color(0xFF64B5F6);        // Hope/Info blue
  static const Color hopeLight = Color(0xFFBBDEFB);
  
  /// Gradients
  static const LinearGradient goldShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldMuted],
    stops: [0.0, 0.5, 1.0],
  );
  
  static const LinearGradient midnightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [midnightLight, midnight, midnightDeep],
  );
  
  static const LinearGradient holyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFBF5), Color(0xFFF5EFE0)],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY - "Sacred Hierarchy"
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Display - For hero moments, scripture headers
  /// Cinzel: Elegant, timeless, sacred feeling
  static TextStyle displayLarge(BuildContext context, {Color? color}) {
    return AppFonts.cinzel(
      fontSize: 48,
      fontWeight: FontWeight.w300, // Light - elegant
      letterSpacing: 2.0,
      height: 1.1,
      color: color ?? midnight,
    );
  }
  
  static TextStyle displayMedium(BuildContext context, {Color? color}) {
    return AppFonts.cinzel(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 1.5,
      height: 1.2,
      color: color ?? midnight,
    );
  }
  
  static TextStyle displaySmall(BuildContext context, {Color? color}) {
    return AppFonts.cinzel(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 1.0,
      height: 1.2,
      color: color ?? midnight,
    );
  }
  
  /// Headlines - Section titles, card headers
  static TextStyle headlineLarge(BuildContext context, {Color? color}) {
    return AppFonts.manrope(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      height: 1.3,
      color: color ?? midnight,
    );
  }
  
  static TextStyle headlineMedium(BuildContext context, {Color? color}) {
    return AppFonts.manrope(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.3,
      color: color ?? midnight,
    );
  }
  
  static TextStyle headlineSmall(BuildContext context, {Color? color}) {
    return AppFonts.manrope(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.4,
      color: color ?? midnight,
    );
  }
  
  /// Labels - Buttons, tags, small UI elements
  static TextStyle labelLarge(BuildContext context, {Color? color}) {
    return AppFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2, // Wide tracking for elegance
      height: 1.4,
      color: color ?? midnight,
    );
  }
  
  static TextStyle labelMedium(BuildContext context, {Color? color}) {
    return AppFonts.manrope(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.5,
      height: 1.4,
      color: color ?? coolGray,
    );
  }
  
  static TextStyle labelSmall(BuildContext context, {Color? color}) {
    return AppFonts.manrope(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 2.0, // Very wide for tiny text
      height: 1.5,
      color: color ?? coolGray,
    );
  }
  
  /// Body - Reading text, descriptions
  static TextStyle bodyLarge(BuildContext context, {Color? color}) {
    return AppFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      height: 1.6, // Generous line height for readability
      color: color ?? midnightLight,
    );
  }
  
  static TextStyle bodyMedium(BuildContext context, {Color? color}) {
    return AppFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.1,
      height: 1.5,
      color: color ?? midnightLight,
    );
  }
  
  /// Scripture - Special style for Bible verses
  static TextStyle scripture(BuildContext context, {Color? color}) {
    return AppFonts.crimsonPro(
      fontSize: 20,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      letterSpacing: 0.3,
      height: 1.7,
      color: color ?? midnight,
    );
  }
  
  static TextStyle scriptureReference(BuildContext context, {Color? color}) {
    return AppFonts.manrope(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.0,
      height: 1.5,
      color: color ?? gold,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPACING - 8pt Grid System
  // ══════════════════════════════════════════════════════════════════════════
  
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  static const double spacingHero = 64.0;

  // ══════════════════════════════════════════════════════════════════════════
  // RADIUS - Consistent corner rounding
  // ══════════════════════════════════════════════════════════════════════════
  
  static const double radiusS = 8.0;
  static const double radiusM = 16.0;
  static const double radiusL = 24.0;
  static const double radiusXL = 32.0;
  static const double radiusFull = 999.0;

  // ══════════════════════════════════════════════════════════════════════════
  // SHADOWS - Colored, diffuse shadows (never pure black)
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Soft elevation for cards
  static List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: midnight.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: midnight.withValues(alpha: 0.02),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];
  
  /// Medium elevation for floating elements
  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: midnight.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: midnight.withValues(alpha: 0.04),
      blurRadius: 40,
      offset: const Offset(0, 16),
      spreadRadius: -8,
    ),
  ];
  
  /// Golden glow for premium elements
  static List<BoxShadow> shadowGold = [
    BoxShadow(
      color: gold.withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 4),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: gold.withValues(alpha: 0.15),
      blurRadius: 40,
      offset: const Offset(0, 8),
      spreadRadius: -8,
    ),
  ];
  
  /// Victory glow for success states
  static List<BoxShadow> shadowVictory = [
    BoxShadow(
      color: victory.withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 4),
      spreadRadius: -4,
    ),
  ];
  
  /// Struggle glow for emergency/alert states
  static List<BoxShadow> shadowStruggle = [
    BoxShadow(
      color: struggle.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // BORDERS - Subtle gradient borders
  // ══════════════════════════════════════════════════════════════════════════
  
  static Border borderSubtle = Border.all(
    color: midnight.withValues(alpha: 0.06),
    width: 1,
  );
  
  static Border borderGold = Border.all(
    color: gold.withValues(alpha: 0.3),
    width: 1,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // HAPTICS - "Feel the Spirit"
  // ══════════════════════════════════════════════════════════════════════════
  
  /// Light tap feedback
  static void hapticLight() {
    HapticFeedback.lightImpact();
  }
  
  /// Medium feedback for important actions
  static void hapticMedium() {
    HapticFeedback.mediumImpact();
  }
  
  /// Heavy feedback for significant moments (victory, etc.)
  static void hapticHeavy() {
    HapticFeedback.heavyImpact();
  }
  
  /// Selection feedback
  static void hapticSelection() {
    HapticFeedback.selectionClick();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ANIMATION DURATIONS
  // ══════════════════════════════════════════════════════════════════════════
  
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationHero = Duration(milliseconds: 800);
  
  /// Stagger delay for list animations
  static const Duration staggerDelay = Duration(milliseconds: 50);

  // ══════════════════════════════════════════════════════════════════════════
  // CURVES - Smooth, natural motion
  // ══════════════════════════════════════════════════════════════════════════
  
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveBounce = Curves.elasticOut;
  static const Curve curveSharp = Curves.easeOutExpo;
}

/// ============================================================================
/// GLASSMORPHISM CONTAINER
/// ============================================================================

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  final double blur;
  final Color? backgroundColor;
  final bool hasBorder;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blur = 8,
    this.backgroundColor,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    if (AppThemeData.of(context).isPaper) {
      // Tema papel: sin vidrio esmerilado; recorte de papel con su sombra.
      return Container(
        padding: padding ?? const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          color: VecColores.papel,
          borderRadius: BorderRadius.circular(VecRadios.m),
          boxShadow: VecSombras.papel,
        ),
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusM),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: backgroundColor ?? AppDesignSystem.pureWhite.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusM),
            border: hasBorder
                ? Border.all(
                    color: AppDesignSystem.midnight.withValues(alpha: 0.08),
                    width: 1,
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// ============================================================================
/// PREMIUM BUTTON WITH SCALE ANIMATION
/// ============================================================================

class PremiumButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final List<BoxShadow>? shadow;
  final EdgeInsets? padding;
  final double? borderRadius;
  final bool isOutlined;
  final Gradient? gradient;
  final double? width;

  const PremiumButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.shadow,
    this.padding,
    this.borderRadius,
    this.isOutlined = false,
    this.gradient,
    this.width,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    AppDesignSystem.hapticLight();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (AppThemeData.of(context).isPaper) return _buildPapel();
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              padding: widget.padding ??
                  const EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.spacingL,
                    vertical: AppDesignSystem.spacingM,
                  ),
              decoration: BoxDecoration(
                color: widget.isOutlined
                    ? Colors.transparent
                    : (widget.backgroundColor ?? AppDesignSystem.midnight),
                gradient: widget.gradient,
                borderRadius: BorderRadius.circular(
                    widget.borderRadius ?? AppDesignSystem.radiusM),
                border: widget.isOutlined
                    ? Border.all(color: AppDesignSystem.midnight, width: 1.5)
                    : null,
                boxShadow: widget.isOutlined ? null : (widget.shadow ?? AppDesignSystem.shadowMedium),
              ),
              child: Center(child: widget.child),
            ),
          );
        },
      ),
    );
  }
}

/// Tema papel: píldora de color sólido del kit que se hunde 5 px al tocarla.
extension on _PremiumButtonState {
  Widget _buildPapel() {
    final fondo = widget.isOutlined
        ? VecColores.papel
        : widget.backgroundColor == AppDesignSystem.victory
        ? VecColores.verde
        : VecColores.terracota;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final abajo = _controller.value > 0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            width: widget.width,
            transform: Matrix4.translationValues(0, abajo ? 5 : 0, 0),
            padding: widget.padding ??
                const EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.spacingL,
                  vertical: AppDesignSystem.spacingM,
                ),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(VecRadios.pildora),
              boxShadow: abajo ? VecSombras.presionado : VecSombras.chip,
            ),
            child: child,
          );
        },
        child: Center(child: widget.child),
      ),
    );
  }
}

/// ============================================================================
/// THEME DATA - Light & Dark
/// ============================================================================

class AppTheme {
  // Legacy colors for backward compatibility
  static const Color primaryColor = AppDesignSystem.midnight;
  static const Color secondaryColor = AppDesignSystem.midnightLight;
  static const Color accentColor = AppDesignSystem.gold;
  static const Color backgroundColor = AppDesignSystem.softWhite;
  static const Color cardColor = AppDesignSystem.pureWhite;
  static const Color emergencyColor = AppDesignSystem.struggle;
  static const Color successColor = AppDesignSystem.victory;
  static const Color textPrimary = AppDesignSystem.midnight;
  static const Color textSecondary = AppDesignSystem.coolGray;
  
  // Dark theme colors
  static const Color darkBackground = AppDesignSystem.midnightDeep;
  static const Color darkSurface = AppDesignSystem.midnight;
  static const Color darkCard = AppDesignSystem.midnightLight;
  static const Color darkTextPrimary = AppDesignSystem.pureWhite;
  static const Color darkTextSecondary = AppDesignSystem.coolGray;
  static const Color darkPrimary = AppDesignSystem.goldLight;
  static const Color darkAccent = AppDesignSystem.gold;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppDesignSystem.midnight,
        primary: AppDesignSystem.midnight,
        secondary: AppDesignSystem.gold,
        surface: AppDesignSystem.softWhite,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppDesignSystem.softWhite,
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppDesignSystem.softWhite,
        foregroundColor: AppDesignSystem.midnight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: AppDesignSystem.midnight,
        ),
        iconTheme: const IconThemeData(
          color: AppDesignSystem.midnight,
          size: 24,
        ),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: AppDesignSystem.pureWhite,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          side: BorderSide(
            color: AppDesignSystem.midnight.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      
      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDesignSystem.midnight,
          foregroundColor: AppDesignSystem.pureWhite,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.spacingL,
            vertical: AppDesignSystem.spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          ),
          textStyle: AppFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ),
      
      // Text Buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppDesignSystem.midnight,
          textStyle: AppFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Outlined Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppDesignSystem.midnight,
          side: const BorderSide(
            color: AppDesignSystem.midnight,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.spacingL,
            vertical: AppDesignSystem.spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          ),
          textStyle: AppFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ),
      
      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppDesignSystem.gold,
        foregroundColor: AppDesignSystem.midnight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        ),
      ),
      
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDesignSystem.pureWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingM,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          borderSide: BorderSide(
            color: AppDesignSystem.midnight.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          borderSide: BorderSide(
            color: AppDesignSystem.midnight.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          borderSide: const BorderSide(
            color: AppDesignSystem.gold,
            width: 2,
          ),
        ),
        labelStyle: AppFonts.manrope(
          color: AppDesignSystem.coolGray,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: AppFonts.manrope(
          color: AppDesignSystem.coolGray.withValues(alpha: 0.6),
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppDesignSystem.pureWhite,
        selectedItemColor: AppDesignSystem.midnight,
        unselectedItemColor: AppDesignSystem.coolGray,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: AppFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppDesignSystem.gold;
          }
          return AppDesignSystem.coolGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppDesignSystem.gold.withValues(alpha: 0.3);
          }
          return AppDesignSystem.warmGray;
        }),
      ),
      
      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppDesignSystem.pureWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        ),
      ),
      
      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppDesignSystem.midnight,
        contentTextStyle: AppFonts.manrope(
          color: AppDesignSystem.pureWhite,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: AppDesignSystem.midnight.withValues(alpha: 0.06),
        thickness: 1,
        space: 1,
      ),
      
      // Icon
      iconTheme: const IconThemeData(
        color: AppDesignSystem.midnight,
        size: 24,
      ),
      
      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppDesignSystem.gold,
        linearTrackColor: AppDesignSystem.warmGray,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppDesignSystem.gold,
        primary: AppDesignSystem.goldLight,
        secondary: AppDesignSystem.gold,
        surface: AppDesignSystem.midnight,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppDesignSystem.midnightDeep,
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppDesignSystem.midnightDeep,
        foregroundColor: AppDesignSystem.pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: AppDesignSystem.pureWhite,
        ),
        iconTheme: const IconThemeData(
          color: AppDesignSystem.pureWhite,
          size: 24,
        ),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: AppDesignSystem.midnightLight,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          side: BorderSide(
            color: AppDesignSystem.pureWhite.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      
      // Elevated Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDesignSystem.gold,
          foregroundColor: AppDesignSystem.midnightDeep,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.spacingL,
            vertical: AppDesignSystem.spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          ),
          textStyle: AppFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ),
      
      // Text Buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppDesignSystem.goldLight,
          textStyle: AppFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Outlined Buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppDesignSystem.goldLight,
          side: const BorderSide(
            color: AppDesignSystem.gold,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.spacingL,
            vertical: AppDesignSystem.spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          ),
          textStyle: AppFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ),
      
      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppDesignSystem.gold,
        foregroundColor: AppDesignSystem.midnightDeep,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        ),
      ),
      
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDesignSystem.midnight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingM,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          borderSide: BorderSide(
            color: AppDesignSystem.pureWhite.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          borderSide: BorderSide(
            color: AppDesignSystem.pureWhite.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          borderSide: const BorderSide(
            color: AppDesignSystem.gold,
            width: 2,
          ),
        ),
        labelStyle: AppFonts.manrope(
          color: AppDesignSystem.coolGray,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: AppFonts.manrope(
          color: AppDesignSystem.coolGray.withValues(alpha: 0.6),
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppDesignSystem.midnight,
        selectedItemColor: AppDesignSystem.gold,
        unselectedItemColor: AppDesignSystem.coolGray,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: AppFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      
      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppDesignSystem.gold;
          }
          return AppDesignSystem.coolGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppDesignSystem.gold.withValues(alpha: 0.3);
          }
          return AppDesignSystem.midnightLight;
        }),
      ),
      
      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppDesignSystem.midnightLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        ),
      ),
      
      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppDesignSystem.gold,
        contentTextStyle: AppFonts.manrope(
          color: AppDesignSystem.midnightDeep,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: AppDesignSystem.pureWhite.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      
      // Icon
      iconTheme: const IconThemeData(
        color: AppDesignSystem.pureWhite,
        size: 24,
      ),
      
      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppDesignSystem.gold,
        linearTrackColor: AppDesignSystem.midnightLight,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAPER THEME — «papel recortado» (kit victoria-en-cristo-estilo)
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Parte de vecTema() del kit y lo extiende a todos los componentes de
  // Material con los mismos tokens (VecColores, VecFuentes, VecSombras,
  // VecRadios). Se usa cuando AppThemeData.isPaper es true.

  static TextStyle get _vecTitulo => TextStyle(
    fontFamily: VecFuentes.titulo,
    color: VecColores.tinta,
  );
  static TextStyle get _vecTexto => TextStyle(
    fontFamily: VecFuentes.texto,
    color: VecColores.tinta,
  );

  /// Botón de píldora: color sólido, texto crema en Lilita One y sombra
  /// sólida que baja de 8 a 3 px al presionarlo.
  static ButtonStyle _vecBoton({
    required Color fondo,
    required Color texto,
  }) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? VecColores.cremaOscuro : fondo,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? VecColores.gris : texto,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? VecColores.gris : texto,
      ),
      overlayColor: WidgetStatePropertyAll(texto.withValues(alpha: 0.08)),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.fromLTRB(26, 14, 26, 12),
      ),
      shape: WidgetStateProperty.resolveWith(
        (s) => BordeConSombraVec.pildora(
          presionado: s.contains(WidgetState.pressed),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontFamily: VecFuentes.titulo, fontSize: 18),
      ),
    );
  }

  static ThemeData get paperTheme {
    final base = vecTema();
    final tituloTema = base.textTheme;

    return base.copyWith(
      // Cada página pinta su papel con textura (TransicionPapel/FondoPapel).
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: VecColores.papel,
      textTheme: tituloTema.copyWith(
        displayMedium: _vecTitulo.copyWith(fontSize: 38, height: 1.05),
        displaySmall: _vecTitulo.copyWith(fontSize: 32, height: 1.05),
        headlineLarge: _vecTitulo.copyWith(fontSize: 32, height: 1.05),
        headlineSmall: _vecTitulo.copyWith(fontSize: 24, height: 1.05),
        titleSmall: _vecTitulo.copyWith(fontSize: 16),
        labelMedium: _vecTitulo.copyWith(fontSize: 14),
        labelSmall: _vecTitulo.copyWith(fontSize: 12),
        bodySmall: _vecTexto.copyWith(fontSize: 15, color: VecColores.gris),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: TransicionPapel(
            PredictiveBackPageTransitionsBuilder(),
          ),
          TargetPlatform.iOS: TransicionPapel(CupertinoPageTransitionsBuilder()),
          TargetPlatform.macOS: TransicionPapel(
            CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.windows: TransicionPapel(ZoomPageTransitionsBuilder()),
          TargetPlatform.linux: TransicionPapel(ZoomPageTransitionsBuilder()),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: VecColores.tinta,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: VecFuentes.titulo,
          fontSize: 24,
          color: VecColores.tinta,
        ),
        iconTheme: IconThemeData(color: VecColores.tinta, size: 26),
      ),

      cardTheme: CardThemeData(
        color: VecColores.papel,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: BordeConSombraVec.tarjeta(),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _vecBoton(fondo: VecColores.terracota, texto: VecColores.papel),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _vecBoton(fondo: VecColores.terracota, texto: VecColores.papel),
      ),
      // Botón secundario (.vec-boton.secundario): papel con texto tinta.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _vecBoton(
          fondo: VecColores.papel,
          texto: VecColores.tinta,
        ).copyWith(side: const WidgetStatePropertyAll(BorderSide.none)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VecColores.terracota,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: VecFuentes.titulo, fontSize: 17),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: VecColores.terracota,
        foregroundColor: VecColores.papel,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        // Estadio: círculo en el FAB normal y píldora en el extendido.
        shape: BordeConSombraVec(
          forma: const StadiumBorder(),
          sombras: VecSombras.chip,
        ),
        extendedTextStyle: const TextStyle(
          fontFamily: VecFuentes.titulo,
          fontSize: 18,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: VecColores.cremaOscuro,
        selectedColor: VecColores.terracota,
        disabledColor: VecColores.cremaOscuro,
        checkmarkColor: VecColores.papel,
        labelStyle: TextStyle(
          fontFamily: VecFuentes.titulo,
          fontSize: 15,
          color: VecColores.tinta,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: VecFuentes.titulo,
          fontSize: 15,
          color: VecColores.papel,
        ),
        side: BorderSide.none,
        shape: BordeConSombraVec(
          forma: const StadiumBorder(),
          sombras: VecSombras.presionado,
        ),
        elevation: 0,
        pressElevation: 0,
      ),

      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VecRadios.s),
          borderSide: BorderSide(color: VecColores.tinta, width: 4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VecRadios.s),
          borderSide: BorderSide(color: VecColores.terracota, width: 4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VecRadios.s),
          borderSide: BorderSide(color: VecColores.terracota, width: 4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VecRadios.s),
          borderSide: BorderSide(color: VecColores.cremaOscuro, width: 4),
        ),
        labelStyle: _vecTexto.copyWith(color: VecColores.gris, fontSize: 18),
        floatingLabelStyle: _vecTitulo.copyWith(
          color: VecColores.terracota,
          fontSize: 16,
        ),
        errorStyle: _vecTexto.copyWith(color: VecColores.terracota, fontSize: 15),
        prefixIconColor: VecColores.gris,
        suffixIconColor: VecColores.gris,
      ),

      switchTheme: base.switchTheme.copyWith(
        trackOutlineWidth: const WidgetStatePropertyAll(3),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VecColores.verde
              : VecColores.papel,
        ),
        checkColor: WidgetStatePropertyAll(VecColores.papel),
        side: BorderSide(color: VecColores.tinta, width: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VecColores.verde
              : VecColores.tinta,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: VecColores.terracota,
        inactiveTrackColor: VecColores.cremaOscuro,
        thumbColor: VecColores.terracota,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: VecColores.papel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: BordeConSombraVec.tarjeta(radio: VecRadios.l),
        titleTextStyle: _vecTitulo.copyWith(fontSize: 24),
        contentTextStyle: _vecTexto.copyWith(fontSize: 18, height: 1.3),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: VecColores.papel,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: VecColores.papel,
        dragHandleColor: VecColores.cremaOscuro,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VecRadios.l),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: VecColores.papel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: BordeConSombraVec.tarjeta(),
        textStyle: _vecTexto.copyWith(fontSize: 18),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: VecColores.tinta,
        contentTextStyle: _vecTitulo.copyWith(
          color: VecColores.papel,
          fontSize: 16,
        ),
        actionTextColor: VecColores.mostazaClaro,
        shape: BordeConSombraVec.pildora(presionado: true),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: VecColores.tinta,
          borderRadius: BorderRadius.circular(VecRadios.s),
        ),
        textStyle: _vecTitulo.copyWith(color: VecColores.papel, fontSize: 14),
      ),

      // Barra inferior (.vec-tabbar): papel, activo en terracota.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: VecColores.papel,
        selectedItemColor: VecColores.terracota,
        unselectedItemColor: VecColores.gris,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontFamily: VecFuentes.titulo, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontFamily: VecFuentes.titulo, fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: VecColores.papel,
        surfaceTintColor: Colors.transparent,
        indicatorColor: VecColores.terracota,
        indicatorShape: const CircleBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? VecColores.papel
                : VecColores.gris,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => _vecTitulo.copyWith(
            fontSize: 13,
            color: s.contains(WidgetState.selected)
                ? VecColores.terracota
                : VecColores.gris,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: VecColores.terracota,
        unselectedLabelColor: VecColores.gris,
        indicatorColor: VecColores.terracota,
        dividerColor: VecColores.cremaOscuro,
        labelStyle: _vecTitulo.copyWith(fontSize: 16),
        unselectedLabelStyle: _vecTitulo.copyWith(fontSize: 16),
      ),

      dividerTheme: DividerThemeData(
        color: VecColores.cremaOscuro,
        thickness: 2,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: VecColores.tinta,
        textColor: VecColores.tinta,
        titleTextStyle: _vecTitulo.copyWith(fontSize: 17),
        subtitleTextStyle: _vecTexto.copyWith(
          fontSize: 16,
          color: VecColores.gris,
        ),
      ),
      iconTheme: IconThemeData(color: VecColores.tinta, size: 24),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: VecColores.terracota,
        linearTrackColor: VecColores.cremaOscuro,
        circularTrackColor: VecColores.cremaOscuro,
      ),
    );
  }
}
