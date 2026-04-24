import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
    return GoogleFonts.cinzel(
      fontSize: 48,
      fontWeight: FontWeight.w300, // Light - elegant
      letterSpacing: 2.0,
      height: 1.1,
      color: color ?? midnight,
    );
  }
  
  static TextStyle displayMedium(BuildContext context, {Color? color}) {
    return GoogleFonts.cinzel(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 1.5,
      height: 1.2,
      color: color ?? midnight,
    );
  }
  
  static TextStyle displaySmall(BuildContext context, {Color? color}) {
    return GoogleFonts.cinzel(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 1.0,
      height: 1.2,
      color: color ?? midnight,
    );
  }
  
  /// Headlines - Section titles, card headers
  static TextStyle headlineLarge(BuildContext context, {Color? color}) {
    return GoogleFonts.manrope(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      height: 1.3,
      color: color ?? midnight,
    );
  }
  
  static TextStyle headlineMedium(BuildContext context, {Color? color}) {
    return GoogleFonts.manrope(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.3,
      color: color ?? midnight,
    );
  }
  
  static TextStyle headlineSmall(BuildContext context, {Color? color}) {
    return GoogleFonts.manrope(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.4,
      color: color ?? midnight,
    );
  }
  
  /// Labels - Buttons, tags, small UI elements
  static TextStyle labelLarge(BuildContext context, {Color? color}) {
    return GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2, // Wide tracking for elegance
      height: 1.4,
      color: color ?? midnight,
    );
  }
  
  static TextStyle labelMedium(BuildContext context, {Color? color}) {
    return GoogleFonts.manrope(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.5,
      height: 1.4,
      color: color ?? coolGray,
    );
  }
  
  static TextStyle labelSmall(BuildContext context, {Color? color}) {
    return GoogleFonts.manrope(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 2.0, // Very wide for tiny text
      height: 1.5,
      color: color ?? coolGray,
    );
  }
  
  /// Body - Reading text, descriptions
  static TextStyle bodyLarge(BuildContext context, {Color? color}) {
    return GoogleFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      height: 1.6, // Generous line height for readability
      color: color ?? midnightLight,
    );
  }
  
  static TextStyle bodyMedium(BuildContext context, {Color? color}) {
    return GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.1,
      height: 1.5,
      color: color ?? midnightLight,
    );
  }
  
  /// Scripture - Special style for Bible verses
  static TextStyle scripture(BuildContext context, {Color? color}) {
    return GoogleFonts.crimsonPro(
      fontSize: 20,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      letterSpacing: 0.3,
      height: 1.7,
      color: color ?? midnight,
    );
  }
  
  static TextStyle scriptureReference(BuildContext context, {Color? color}) {
    return GoogleFonts.manrope(
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
      color: midnight.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: midnight.withOpacity(0.02),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];
  
  /// Medium elevation for floating elements
  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: midnight.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: midnight.withOpacity(0.04),
      blurRadius: 40,
      offset: const Offset(0, 16),
      spreadRadius: -8,
    ),
  ];
  
  /// Golden glow for premium elements
  static List<BoxShadow> shadowGold = [
    BoxShadow(
      color: gold.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 4),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: gold.withOpacity(0.15),
      blurRadius: 40,
      offset: const Offset(0, 8),
      spreadRadius: -8,
    ),
  ];
  
  /// Victory glow for success states
  static List<BoxShadow> shadowVictory = [
    BoxShadow(
      color: victory.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 4),
      spreadRadius: -4,
    ),
  ];
  
  /// Struggle glow for emergency/alert states
  static List<BoxShadow> shadowStruggle = [
    BoxShadow(
      color: struggle.withOpacity(0.35),
      blurRadius: 24,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // BORDERS - Subtle gradient borders
  // ══════════════════════════════════════════════════════════════════════════
  
  static Border borderSubtle = Border.all(
    color: midnight.withOpacity(0.06),
    width: 1,
  );
  
  static Border borderGold = Border.all(
    color: gold.withOpacity(0.3),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusM),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: backgroundColor ?? AppDesignSystem.pureWhite.withOpacity(0.7),
            borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusM),
            border: hasBorder
                ? Border.all(
                    color: AppDesignSystem.midnight.withOpacity(0.08),
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
        titleTextStyle: GoogleFonts.manrope(
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
            color: AppDesignSystem.midnight.withOpacity(0.06),
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
          textStyle: GoogleFonts.manrope(
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
          textStyle: GoogleFonts.manrope(
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
          textStyle: GoogleFonts.manrope(
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
            color: AppDesignSystem.midnight.withOpacity(0.1),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          borderSide: BorderSide(
            color: AppDesignSystem.midnight.withOpacity(0.1),
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
        labelStyle: GoogleFonts.manrope(
          color: AppDesignSystem.coolGray,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.manrope(
          color: AppDesignSystem.coolGray.withOpacity(0.6),
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppDesignSystem.pureWhite,
        selectedItemColor: AppDesignSystem.midnight,
        unselectedItemColor: AppDesignSystem.coolGray,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
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
            return AppDesignSystem.gold.withOpacity(0.3);
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
        contentTextStyle: GoogleFonts.manrope(
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
        color: AppDesignSystem.midnight.withOpacity(0.06),
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
        titleTextStyle: GoogleFonts.manrope(
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
            color: AppDesignSystem.pureWhite.withOpacity(0.08),
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
          textStyle: GoogleFonts.manrope(
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
          textStyle: GoogleFonts.manrope(
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
          textStyle: GoogleFonts.manrope(
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
            color: AppDesignSystem.pureWhite.withOpacity(0.1),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          borderSide: BorderSide(
            color: AppDesignSystem.pureWhite.withOpacity(0.1),
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
        labelStyle: GoogleFonts.manrope(
          color: AppDesignSystem.coolGray,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.manrope(
          color: AppDesignSystem.coolGray.withOpacity(0.6),
        ),
      ),
      
      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppDesignSystem.midnight,
        selectedItemColor: AppDesignSystem.gold,
        unselectedItemColor: AppDesignSystem.coolGray,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
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
            return AppDesignSystem.gold.withOpacity(0.3);
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
        contentTextStyle: GoogleFonts.manrope(
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
        color: AppDesignSystem.pureWhite.withOpacity(0.08),
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
}
