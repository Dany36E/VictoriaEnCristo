/// Botón flotante SOS con animación de respiración y glow neón.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../screens/emergency_screen.dart';

class BreathingSosButton extends StatefulWidget {
  const BreathingSosButton({super.key});

  @override
  State<BreathingSosButton> createState() => _BreathingSosButtonState();
}

class _BreathingSosButtonState extends State<BreathingSosButton>
    with TickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breatheController, _glowController]),
      builder: (context, child) {
        final breatheCurve =
            Curves.easeInOutSine.transform(_breatheController.value);
        final glowCurve =
            Curves.easeInOut.transform(_glowController.value);

        final scale = 1.0 + (breatheCurve * 0.05);
        final glowOpacity = 0.5 + (glowCurve * 0.3);

        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(glowOpacity * 0.6),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.deepOrange.withOpacity(glowOpacity * 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color:
                      const Color(0xFFFF5722).withOpacity(glowOpacity * 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Semantics(
        button: true,
        label: 'Botón de emergencia, necesito ayuda ahora',
        child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.heavyImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmergencyScreen()),
            );
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppDesignSystem.spacingM,
              horizontal: AppDesignSystem.spacingXL,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.redAccent.withOpacity(0.95),
                  Colors.deepOrange.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emergency_outlined, color: Colors.white, size: 24),
                SizedBox(width: AppDesignSystem.spacingS),
                Text(
                  '¡NECESITO AYUDA!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 600.ms)
        .slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack);
  }
}
