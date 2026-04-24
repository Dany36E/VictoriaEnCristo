import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/content_item.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

/// Widget guía de respiración con círculo animado.
///
/// Recorre cíclicamente las [phases] anunciando la fase actual con un
/// círculo que crece (inhala), se mantiene (mantén) o decrece (exhala).
/// Da un haptic ligero al cambio de fase para reforzar la sensación corporal.
///
/// Diseñado como widget autónomo: el padre decide cuándo iniciar/detener
/// vía la propiedad [isRunning].
class BreathingGuide extends StatefulWidget {
  /// Fases del ciclo respiratorio (al menos una).
  final List<BreathingPhase> phases;

  /// Color de acento del círculo y los textos.
  final Color color;

  /// Si está corriendo. Cuando se pausa, el círculo se queda en su estado actual.
  final bool isRunning;

  /// Tamaño máximo del círculo en píxeles (lado mayor).
  final double size;

  /// Callback cuando se completa un ciclo entero.
  final VoidCallback? onCycleComplete;

  const BreathingGuide({
    super.key,
    required this.phases,
    required this.color,
    this.isRunning = true,
    this.size = 220,
    this.onCycleComplete,
  });

  @override
  State<BreathingGuide> createState() => _BreathingGuideState();
}

class _BreathingGuideState extends State<BreathingGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _phaseTicker;
  int _phaseIndex = 0;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _resetToPhase(0, autostart: widget.isRunning);
  }

  @override
  void didUpdateWidget(covariant BreathingGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRunning != widget.isRunning) {
      if (widget.isRunning) {
        _runCurrentPhase();
      } else {
        _phaseTicker?.cancel();
        _controller.stop();
      }
    }
    if (oldWidget.phases != widget.phases) {
      _resetToPhase(0, autostart: widget.isRunning);
    }
  }

  @override
  void dispose() {
    _phaseTicker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _resetToPhase(int index, {required bool autostart}) {
    _phaseTicker?.cancel();
    _controller.stop();
    if (widget.phases.isEmpty) return;
    _phaseIndex = index;
    _secondsLeft = widget.phases[_phaseIndex].seconds;
    if (autostart) {
      _runCurrentPhase();
    } else {
      _applyStaticPosition();
      setState(() {});
    }
  }

  void _applyStaticPosition() {
    if (widget.phases.isEmpty) return;
    final phase = widget.phases[_phaseIndex];
    switch (phase.action) {
      case BreathingAction.expand:
        _controller.value = 0.0;
        break;
      case BreathingAction.contract:
        _controller.value = 1.0;
        break;
      case BreathingAction.hold:
        _controller.value = 1.0;
        break;
    }
  }

  void _runCurrentPhase() {
    if (widget.phases.isEmpty) return;
    if (!mounted) return;

    final phase = widget.phases[_phaseIndex];
    final durationMs = phase.seconds * 1000;
    _controller.duration = Duration(milliseconds: durationMs);

    switch (phase.action) {
      case BreathingAction.expand:
        _controller.forward(from: 0.0);
        break;
      case BreathingAction.contract:
        _controller.reverse(from: 1.0);
        break;
      case BreathingAction.hold:
        // Mantiene la posición actual, no anima.
        break;
    }

    HapticFeedback.lightImpact();

    _secondsLeft = phase.seconds;
    setState(() {});

    _phaseTicker?.cancel();
    _phaseTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _secondsLeft--;
      if (_secondsLeft <= 0) {
        timer.cancel();
        final nextIndex = (_phaseIndex + 1) % widget.phases.length;
        if (nextIndex == 0) {
          widget.onCycleComplete?.call();
        }
        _phaseIndex = nextIndex;
        _runCurrentPhase();
      } else {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    if (widget.phases.isEmpty) {
      return const SizedBox.shrink();
    }
    final phase = widget.phases[_phaseIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.size,
          width: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // Tamaño relativo: 0.45 → 1.0 del tamaño máximo.
              final scale = 0.45 + (_controller.value * 0.55);
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Halo exterior estático (referencia visual del tamaño máx)
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  // Círculo respirante
                  Container(
                    width: widget.size * scale,
                    height: widget.size * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.color.withOpacity(0.55),
                          widget.color.withOpacity(0.15),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(0.35),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  // Texto central
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        phase.label,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_secondsLeft',
                        style: TextStyle(
                          color: widget.color,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        // Indicador de fases (puntos)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.phases.length, (i) {
            final isActive = i == _phaseIndex;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? widget.color
                    : widget.color.withOpacity(0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}
