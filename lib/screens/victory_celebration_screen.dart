/// ═══════════════════════════════════════════════════════════════════════════
/// VICTORY CELEBRATION SCREEN - Pantalla de celebración estilo Duolingo
/// Se muestra tras registrar un día de victoria con animaciones orquestadas
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/jesus_widget_service.dart';
import '../services/victory_scoring_service.dart';
import '../services/feedback_engine.dart';
import '../services/audio_engine.dart';
import '../theme/app_theme.dart';

class VictoryCelebrationScreen extends StatefulWidget {
  final int streakDays;
  final bool isNewUser;

  const VictoryCelebrationScreen({
    super.key,
    required this.streakDays,
    this.isNewUser = false,
  });

  @override
  State<VictoryCelebrationScreen> createState() =>
      _VictoryCelebrationScreenState();
}

class _VictoryCelebrationScreenState extends State<VictoryCelebrationScreen>
    with TickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _fireController;
  late final AnimationController _numberController;
  late final Animation<int> _numberAnimation;

  int get _streak => widget.streakDays;

  @override
  void initState() {
    super.initState();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _numberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _numberAnimation = IntTween(begin: 0, end: _streak).animate(
      CurvedAnimation(parent: _numberController, curve: Curves.easeOutCubic),
    );

    // Orquestación temporal
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _numberController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _confettiController.play();
    });

    // Audio: mute BGM, play confirm SFX
    AudioEngine.I.muteForScreen();
    FeedbackEngine.I.confirm();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _fireController.dispose();
    _numberController.dispose();
    AudioEngine.I.unmuteForScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = JesusWidgetService.I;
    final streakColor = service.getStreakColor(_streak);
    final spritePath = service.getSprite(
      streakDays: _streak,
      completedToday: true,
      isNewUser: widget.isNewUser,
    );
    final message = _getCelebrationMessage();
    final weeklyData = VictoryScoringService.I.getWeeklyStatus();
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── CAPA 1: Fondo gradiente animado ───
          _buildAnimatedBackground(streakColor),

          // ─── CAPA 2: Confetti ───
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              gravity: 0.08,
              shouldLoop: false,
              colors: [
                streakColor,
                AppDesignSystem.gold,
                AppDesignSystem.goldLight,
                Colors.white,
                const Color(0xFFFFE4B5),
              ],
              createParticlePath: (size) {
                // Estrella de 4 puntas
                final path = Path();
                final w = size.width / 2;
                path.moveTo(0, -w);
                path.lineTo(w * 0.3, -w * 0.3);
                path.lineTo(w, 0);
                path.lineTo(w * 0.3, w * 0.3);
                path.lineTo(0, w);
                path.lineTo(-w * 0.3, w * 0.3);
                path.lineTo(-w, 0);
                path.lineTo(-w * 0.3, -w * 0.3);
                path.close();
                return path;
              },
            ),
          ),

          // ─── CAPA 3: Contenido principal ───
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.04),

                // ─── Speech Bubble ───
                _buildSpeechBubble(message)
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 500.ms)
                    .slideY(
                      begin: -0.3,
                      end: 0,
                      delay: 200.ms,
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),

                SizedBox(height: screenHeight * 0.02),

                // ─── Jesús con fire aura ───
                _buildJesusWithAura(spritePath, streakColor)
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .scale(
                      begin: const Offset(0.3, 0.3),
                      end: const Offset(1, 1),
                      delay: 400.ms,
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    ),

                SizedBox(height: screenHeight * 0.02),

                // ─── Número grande ───
                _buildStreakNumber(streakColor)
                    .animate()
                    .fadeIn(delay: 700.ms, duration: 500.ms),

                const SizedBox(height: 4),

                // ─── Label "días de victoria" ───
                _buildStreakLabel(streakColor)
                    .animate()
                    .fadeIn(delay: 900.ms, duration: 400.ms)
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      delay: 900.ms,
                      duration: 400.ms,
                    ),

                const Spacer(),

                // ─── Mini calendario semanal ───
                _buildWeeklyCalendar(weeklyData, streakColor)
                    .animate()
                    .fadeIn(delay: 1100.ms, duration: 500.ms)
                    .slideY(
                      begin: 0.3,
                      end: 0,
                      delay: 1100.ms,
                      duration: 500.ms,
                      curve: Curves.easeOut,
                    ),

                SizedBox(height: screenHeight * 0.04),

                // ─── Botón CONTINUAR ───
                _buildContinueButton(streakColor)
                    .animate()
                    .fadeIn(delay: 2000.ms, duration: 500.ms)
                    .slideY(
                      begin: 0.5,
                      end: 0,
                      delay: 2000.ms,
                      duration: 500.ms,
                      curve: Curves.easeOut,
                    ),

                SizedBox(height: screenHeight * 0.05),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FONDO ANIMADO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAnimatedBackground(Color streakColor) {
    return AnimatedBuilder(
      animation: _fireController,
      builder: (context, child) {
        final pulse = 0.15 + (_fireController.value * 0.1);
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: 1.2,
              colors: [
                streakColor.withOpacity(pulse),
                AppDesignSystem.midnightDeep.withOpacity(0.95),
                Colors.black,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SPEECH BUBBLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSpeechBubble(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppDesignSystem.pureWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppDesignSystem.midnightDeep,
          height: 1.4,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JESÚS + FIRE AURA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildJesusWithAura(String spritePath, Color streakColor) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fire aura (pulsante)
          AnimatedBuilder(
            animation: _fireController,
            builder: (context, child) {
              final scale = 1.0 + (_fireController.value * 0.08);
              final opacity = 0.3 + (_fireController.value * 0.2);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        streakColor.withOpacity(opacity),
                        streakColor.withOpacity(opacity * 0.5),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // Sprite
          Image.asset(
            spritePath,
            width: 160,
            height: 160,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => Icon(
              Icons.person,
              size: 100,
              color: streakColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NÚMERO GRANDE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStreakNumber(Color streakColor) {
    return AnimatedBuilder(
      animation: _numberAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              streakColor,
              AppDesignSystem.goldLight,
            ],
          ).createShader(bounds),
          child: Text(
            '${_numberAnimation.value}',
            style: GoogleFonts.cinzel(
              fontSize: _streak >= 100 ? 72 : 88,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LABEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStreakLabel(Color streakColor) {
    return Text(
      _streak == 1 ? 'día de victoria' : 'días de victoria',
      style: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: streakColor,
        letterSpacing: 1,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MINI CALENDARIO SEMANAL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWeeklyCalendar(
      List<Map<String, dynamic>> weeklyData, Color streakColor) {
    const dayLabels = ['L', 'Ma', 'Mi', 'J', 'V', 'S', 'D'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppDesignSystem.gold.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final day = weeklyData[i];
          final completed = day['completed'] as bool;
          final isToday = day['isToday'] as bool;
          final isFuture = (day['date'] as DateTime)
              .isAfter(DateTime.now());

          return _buildDayCircle(
            label: dayLabels[i],
            completed: completed,
            isToday: isToday,
            isFuture: isFuture,
            streakColor: streakColor,
            delayMs: 1100 + (i * 60),
          );
        }),
      ),
    );
  }

  Widget _buildDayCircle({
    required String label,
    required bool completed,
    required bool isToday,
    required bool isFuture,
    required Color streakColor,
    required int delayMs,
  }) {
    final Color circleColor;
    final Widget? centerWidget;

    if (completed) {
      circleColor = streakColor;
      centerWidget = const Icon(Icons.check, color: Colors.white, size: 16);
    } else if (isToday) {
      circleColor = streakColor;
      centerWidget = const Icon(Icons.check, color: Colors.white, size: 16);
    } else if (isFuture) {
      circleColor = Colors.white.withOpacity(0.08);
      centerWidget = null;
    } else {
      circleColor = Colors.white.withOpacity(0.12);
      centerWidget = null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            color: isToday
                ? streakColor
                : Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circleColor,
            border: isToday
                ? Border.all(color: streakColor, width: 2)
                : null,
          ),
          child: centerWidget != null
              ? Center(child: centerWidget)
              : null,
        ),
      ],
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delayMs), duration: 300.ms)
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
          delay: Duration(milliseconds: delayMs),
          duration: 300.ms,
          curve: Curves.easeOutBack,
        );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTÓN CONTINUAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildContinueButton(Color streakColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            FeedbackEngine.I.tap();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: streakColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            'CONTINUAR',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MENSAJES DE CELEBRACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  String _getCelebrationMessage() {
    if (widget.isNewUser) {
      return '¡Bienvenido, guerrero!\nTu camino de victoria comienza hoy.';
    }

    // Hitos especiales
    if (_streak >= 365) return '¡UN AÑO COMPLETO!\n¡Eres un guerrero eterno de la fe!';
    if (_streak == 100) return '¡CENTURIÓN DE LA FE!\n100 días caminando en victoria.';
    if (_streak == 60) return '¡Dos meses de batalla!\nTu armadura brilla con fuerza.';
    if (_streak == 30) return '¡Un mes entero!\nCada día te hace más fuerte.';
    if (_streak == 21) return '¡21 días!\nUn nuevo hábito se ha formado en ti.';
    if (_streak == 14) return '¡Dos semanas seguidas!\nEstás forjando una armadura.';
    if (_streak == 7) return '¡Una semana completa!\n¡Sabía que volverías!';
    if (_streak == 3) return '¡Tres días seguidos!\nEstás tomando impulso.';
    if (_streak == 1) return '¡Tu primera victoria!\nEl camino más largo empieza con un paso.';

    // Mensajes rotativos para rachas intermedias
    final messages = [
      '¡Sabía que volverías!\nMañana también te esperaré.',
      '¡Victoria registrada!\nCada día cuenta en esta batalla.',
      '¡Bien hecho, soldado!\nTu disciplina inspira al cielo.',
      '¡Otro día de victoria!\nLa constancia es tu mejor arma.',
      '¡Sigue adelante!\nDios se alegra de tu esfuerzo.',
    ];
    return messages[_streak % messages.length];
  }
}
