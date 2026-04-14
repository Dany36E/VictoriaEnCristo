/// ═══════════════════════════════════════════════════════════════════════════
/// BADGE CELEBRATION - Bottom sheet y snackbar para nuevas insignias
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../models/badge_definition.dart';
import '../services/badge_service.dart';
import '../theme/app_theme_data.dart';

class BadgeCelebration {
  BadgeCelebration._();

  /// Muestra celebración completa (primera vez): confetti + bottom sheet
  static void showFullCelebration(BuildContext context, BadgeUnlockEvent event) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BadgeCelebrationSheet(event: event),
    );
  }

  /// Muestra snackbar sutil (revisita)
  static void showSnackbar(BuildContext context, BadgeUnlockEvent event) {
    HapticFeedback.mediumImpact();
    final t = AppThemeData.of(context);
    final color = Color(event.level.colorValue);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: t.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        content: Row(
          children: [
            Text(event.level.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${event.category.displayName}: ¡${event.level.displayName}!',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _BadgeCelebrationSheet extends StatefulWidget {
  final BadgeUnlockEvent event;
  const _BadgeCelebrationSheet({required this.event});

  @override
  State<_BadgeCelebrationSheet> createState() => _BadgeCelebrationSheetState();
}

class _BadgeCelebrationSheetState extends State<_BadgeCelebrationSheet> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    Future.microtask(() => _confettiController.play());
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final color = Color(event.level.colorValue);
    final message = event.category.celebrationMessage(event.level);

    return Stack(
      children: [
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.06,
            numberOfParticles: 15,
            gravity: 0.1,
            shouldLoop: false,
            colors: [
              color,
              color.withOpacity(0.7),
              Colors.white,
              AppThemeData.of(context).accent,
            ],
          ),
        ),

        // Bottom sheet content
        Container(
          margin: const EdgeInsets.only(top: 100),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          decoration: BoxDecoration(
            color: AppThemeData.of(context).surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppThemeData.of(context).textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Badge icon big
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color.withOpacity(0.4), width: 3),
                ),
                child: Center(
                  child: Text(
                    event.level.emoji,
                    style: const TextStyle(fontSize: 42),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                '¡Nueva Insignia!',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppThemeData.of(context).textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              // Category + level
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(event.category.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    '${event.category.displayName} — ${event.level.displayName}',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Celebration message
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppThemeData.of(context).textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withOpacity(0.2),
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: color.withOpacity(0.3)),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '¡Gloria a Dios! 🙏',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
