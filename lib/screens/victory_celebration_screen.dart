/// ═══════════════════════════════════════════════════════════════════════════
/// VICTORY CELEBRATION SCREEN - Pantalla de celebración estilo Duolingo
/// Se muestra tras registrar un día de victoria con animaciones orquestadas
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../services/victory_scoring_service.dart';
import '../services/feedback_engine.dart';
import '../services/audio_engine.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';
import '../widgets/escena_racha_papel.dart';

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
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _numberController;
  late final Animation<int> _numberAnimation;

  int get _streak => widget.streakDays;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

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
    _numberController.dispose();
    AudioEngine.I.unmuteForScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _getCelebrationMessage();
    final weeklyData = VictoryScoringService.I.getWeeklyStatus();
    return _buildPapel(message, weeklyData);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FONDO ANIMADO
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // SPEECH BUBBLE
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // JESÚS + FIRE AURA
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // NÚMERO GRANDE
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // LABEL
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // MINI CALENDARIO SEMANAL
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTÓN CONTINUAR
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // PAPEL RECORTADO — Jesús celebra sobre la escena de la racha
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPapel(String message, List<Map<String, dynamic>> weeklyData) {
    const dayLabels = ['L', 'Ma', 'Mi', 'J', 'V', 'S', 'D'];
    return FondoPapel(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
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
                  VecColores.terracota,
                  VecColores.mostaza,
                  VecColores.mostazaClaro,
                  VecColores.verde,
                  VecColores.azulClaro,
                ],
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  children: [
                    PopIn(child: Globo(texto: message.replaceAll('\n', ' '))),
                    const SizedBox(height: 26),
                    PopIn(
                      retraso: const Duration(milliseconds: 150),
                      child: EscenaRachaPapel(
                        streakDays: _streak,
                        completedToday: true,
                        isNewUser: widget.isNewUser,
                        ancho: 210,
                        alto: 270,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedBuilder(
                      animation: _numberAnimation,
                      builder: (context, _) => Letrero(
                        '${_numberAnimation.value}',
                        tamano: 88,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TituloVec(
                      _streak == 1 ? 'día de victoria' : 'días de victoria',
                      clave: 'victoria',
                      tamano: 26,
                      alineacion: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    PopIn(
                      retraso: const Duration(milliseconds: 400),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                        decoration: BoxDecoration(
                          color: VecColores.papel,
                          borderRadius: BorderRadius.circular(VecRadios.m),
                          boxShadow: VecSombras.papel,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(7, (i) {
                            final day = weeklyData[i];
                            final completed = day['completed'] as bool;
                            final isToday = day['isToday'] as bool;
                            final hecho = completed || isToday;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dayLabels[i],
                                  style: TextStyle(
                                    fontFamily: VecFuentes.titulo,
                                    fontSize: 14,
                                    color: isToday
                                        ? VecColores.terracota
                                        : VecColores.gris,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                hecho
                                    ? CirculoIcono(
                                        iconoVec: 'palomita',
                                        color: isToday
                                            ? VecColores.terracota
                                            : VecColores.verde,
                                        tamano: 34,
                                        giro: isToday ? -6 : 0,
                                      )
                                    : Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: VecColores.cremaOscuro,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    BotonVec(
                      texto: 'Continuar',
                      icono: Icons.arrow_forward_rounded,
                      color: VecColores.verde,
                      expandido: true,
                      onPressed: () {
                        FeedbackEngine.I.tap();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    if (_streak >= 365) {
      return '¡UN AÑO COMPLETO!\n¡Eres un guerrero eterno de la fe!';
    }
    if (_streak == 100) {
      return '¡CENTURIÓN DE LA FE!\n100 días caminando en victoria.';
    }
    if (_streak == 60) {
      return '¡Dos meses de batalla!\nTu armadura brilla con fuerza.';
    }
    if (_streak == 30) return '¡Un mes entero!\nCada día te hace más fuerte.';
    if (_streak == 21) return '¡21 días!\nUn nuevo hábito se ha formado en ti.';
    if (_streak == 14) {
      return '¡Dos semanas seguidas!\nEstás forjando una armadura.';
    }
    if (_streak == 7) return '¡Una semana completa!\n¡Sabía que volverías!';
    if (_streak == 3) return '¡Tres días seguidos!\nEstás tomando impulso.';
    if (_streak == 1) {
      return '¡Tu primera victoria!\nEl camino más largo empieza con un paso.';
    }

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
