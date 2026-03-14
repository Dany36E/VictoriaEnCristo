import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../services/audio_engine.dart';
import 'giant_selection_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PANTALLA 1: BIENVENIDA - "El Triage Espiritual"
/// Prepara el terreno y explica el propósito del cuestionario
/// ═══════════════════════════════════════════════════════════════════════════

class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  State<OnboardingWelcomeScreen> createState() => _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScaleAnimation;

  // Imagen de fondo: Montaña épica con luz dorada
  static const String _heroImageUrl = 
      'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    
    // BGM ya inicia desde main.dart - no duplicar aquí
    // AudioEngine ya está corriendo si bgmEnabled=true
    
    // Iniciar animación de entrada
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _animationController.forward();
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _buttonScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToGiantSelection() {
    HapticFeedback.mediumImpact();
    AudioEngine.I.playTap();
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GiantSelectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnight,
      body: Stack(
        children: [
          // ═══════════════════════════════════════════════════════════════════
          // FONDO: Imagen de montaña con overlay
          // ═══════════════════════════════════════════════════════════════════
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: _heroImageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppDesignSystem.midnight,
              ),
              errorWidget: (context, url, error) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppDesignSystem.midnight,
                      AppDesignSystem.midnightLight,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Overlay gradiente oscuro para legibilidad
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppDesignSystem.midnight.withOpacity(0.3),
                    AppDesignSystem.midnight.withOpacity(0.7),
                    AppDesignSystem.midnight.withOpacity(0.95),
                    AppDesignSystem.midnight,
                  ],
                  stops: const [0.0, 0.3, 0.5, 0.7, 0.85],
                ),
              ),
            ),
          ),

          // Efecto de luz dorada en la cima (simulado)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.2,
                  colors: [
                    AppDesignSystem.gold.withOpacity(0.25),
                    AppDesignSystem.gold.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          // ═══════════════════════════════════════════════════════════════════
          // CONTENIDO PRINCIPAL
          // ═══════════════════════════════════════════════════════════════════
          SafeArea(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const Spacer(flex: 3),
                          
                          // ═══════════════════════════════════════════════════
                          // ICONO DECORATIVO
                          // ═══════════════════════════════════════════════════
                          _buildDecorativeIcon(),
                          
                          const SizedBox(height: 32),
                          
                          // ═══════════════════════════════════════════════════
                          // TÍTULO PRINCIPAL
                          // ═══════════════════════════════════════════════════
                          _buildTitle(),
                          
                          const SizedBox(height: 24),
                          
                          // ═══════════════════════════════════════════════════
                          // TEXTO EXPLICATIVO
                          // ═══════════════════════════════════════════════════
                          _buildDescription(),
                          
                          const Spacer(flex: 2),
                          
                          // ═══════════════════════════════════════════════════
                          // BOTÓN PRINCIPAL
                          // ═══════════════════════════════════════════════════
                          ScaleTransition(
                            scale: _buttonScaleAnimation,
                            child: _buildMainButton(),
                          ),
                          
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // ═══════════════════════════════════════════════════════════════════
          // BOTÓN DE AUDIO (Toggle música)
          // ═══════════════════════════════════════════════════════════════════
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: _buildAudioToggleButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioToggleButton() {
    // Usar ValueListenableBuilder para reactividad real
    return ValueListenableBuilder<bool>(
      valueListenable: AudioEngine.I.bgmEnabled,
      builder: (context, isBgmEnabled, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBgmEnabled 
                ? AppDesignSystem.gold.withOpacity(0.9)
                : AppDesignSystem.midnight.withOpacity(0.9),
            border: Border.all(
              color: isBgmEnabled 
                  ? AppDesignSystem.gold
                  : Colors.white.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isBgmEnabled 
                    ? AppDesignSystem.gold.withOpacity(0.4)
                    : Colors.black.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async {
                HapticFeedback.mediumImpact();
                // setBgmEnabled maneja start/stop internamente
                await AudioEngine.I.setBgmEnabled(!isBgmEnabled);
              },
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isBgmEnabled ? Icons.music_note_rounded : Icons.music_off_rounded,
                    key: ValueKey(isBgmEnabled),
                    color: isBgmEnabled ? AppDesignSystem.midnight : Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDecorativeIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppDesignSystem.gold.withOpacity(0.3),
            AppDesignSystem.gold.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: AppDesignSystem.gold.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.shield_outlined,
          color: AppDesignSystem.gold,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          AppDesignSystem.gold,
          AppDesignSystem.goldLight,
          AppDesignSystem.gold,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bounds),
      child: Text(
        'PREPÁRATE\nPARA LA BATALLA',
        textAlign: TextAlign.center,
        style: GoogleFonts.cinzel(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.2,
          letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      children: [
        Text(
          'Bienvenido, guerrero.',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppDesignSystem.pureWhite,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Esta aplicación es tu arsenal. Para darte las armas correctas, necesitamos saber contra qué gigante te enfrentas hoy.',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppDesignSystem.pureWhite.withOpacity(0.85),
            height: 1.7,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        // Nota de privacidad
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppDesignSystem.gold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppDesignSystem.gold.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                color: AppDesignSystem.gold,
                size: 18,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Tu respuesta es privada entre tú y Dios.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppDesignSystem.gold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: AppDesignSystem.goldShimmer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.gold.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppDesignSystem.gold.withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _navigateToGiantSelection,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ELEGIR MIS GIGANTES',
                  style: GoogleFonts.cinzel(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.midnight,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppDesignSystem.midnight,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
