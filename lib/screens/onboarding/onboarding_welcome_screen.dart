import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_fonts.dart';
import '../../services/audio_engine.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';
import 'giant_selection_screen.dart';
import 'onboarding_papel.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PANTALLA 1: BIENVENIDA - "El Triage Espiritual"
/// Prepara el terreno y explica el propósito del cuestionario
/// ═══════════════════════════════════════════════════════════════════════════

class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  State<OnboardingWelcomeScreen> createState() =>
      _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

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
              position:
                  Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
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
    return _buildPapel();
  }

  /// Tema papel: Timoteo y Victoria dan la bienvenida, letrero de portada
  /// y la explicación en una tarjeta de papel.
  Widget _buildPapel() {
    return FondoPapel(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 64, 22, 32),
                child: Column(
                  children: [
                    const PopIn(
                      child: Letrero(
                        'PREPÁRATE PARA LA BATALLA',
                        clave: 'BATALLA',
                        tamano: 38,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const PopIn(
                      retraso: Duration(milliseconds: 120),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Sticker(
                            'assets/vec/personajes/timoteo_explica.png',
                            alto: 200,
                            giro: -2,
                          ),
                          Sticker(
                            'assets/vec/personajes/victoria_presenta.png',
                            alto: 200,
                            giro: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    PopIn(
                      retraso: const Duration(milliseconds: 200),
                      child: Subtitulo(
                        quien: 'Timoteo',
                        color: VecColores.azul,
                        texto: 'Bienvenido, guerrero.',
                        clave: 'guerrero',
                      ),
                    ),
                    const SizedBox(height: 28),
                    PopIn(
                      retraso: const Duration(milliseconds: 280),
                      child: TarjetaPapel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Esta aplicación es tu arsenal. Para darte las armas correctas, necesitamos saber contra qué gigante te enfrentas hoy.',
                              style: AppFonts.manrope(
                                fontSize: 18,
                                color: VecColores.tinta,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CirculoIcono(
                                  iconoVec: 'candado',
                                  color: VecColores.verde,
                                  tamano: 36,
                                  giro: -4,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Tu respuesta es privada entre tú y Dios.',
                                    style: AppFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: VecColores.verde,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    PopIn(
                      retraso: const Duration(milliseconds: 360),
                      child: BotonVec(
                        texto: 'Elegir mis gigantes',
                        icono: Icons.arrow_forward_rounded,
                        expandido: true,
                        onPressed: _navigateToGiantSelection,
                      ),
                    ),
                  ],
                ),
              ),
              const Positioned(top: 12, right: 16, child: BotonAudioPapel()),
            ],
          ),
        ),
      ),
    );
  }
}
