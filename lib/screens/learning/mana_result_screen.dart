/// ═══════════════════════════════════════════════════════════════════════════
/// ManaResultScreen — pantalla de cierre tras sesión de Maná
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/learning/learning_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../widgets/learning/animated_counter.dart';

class ManaResultScreen extends StatelessWidget {
  final int total;
  final int correct;
  final int wrong;
  final int xpEarned;
  /// Desglose opcional para mostrar bonus + escudo de gracia.
  final SessionXpReward? reward;

  const ManaResultScreen({
    super.key,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.xpEarned,
    this.reward,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final pct = total == 0 ? 0 : ((correct / total) * 100).round();
    final title = correct == total
        ? '¡Sesión perfecta!'
        : correct >= total / 2
            ? '¡Buen trabajo!'
            : 'Sigue entrenando';
    final subtitle = correct == total
        ? 'Dominaste cada pregunta. La Palabra se arraiga en ti.'
        : 'Cada día rinde fruto. Lo que aprendiste queda.';

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppDesignSystem.gold.withOpacity(0.15),
                    border: Border.all(
                      color: AppDesignSystem.gold.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: AppDesignSystem.gold,
                    size: 64,
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              ),
              const SizedBox(height: AppDesignSystem.spacingL),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppDesignSystem.displaySmall(
                  context,
                  color: t.textPrimary,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: AppDesignSystem.spacingS),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppDesignSystem.bodyLarge(
                  context,
                  color: t.textSecondary,
                ),
              ).animate().fadeIn(delay: 260.ms),
              const SizedBox(height: AppDesignSystem.spacingXL),
              Row(
                children: [
                  _Stat(label: 'Correctas', value: '$correct/$total'),
                  const SizedBox(width: AppDesignSystem.spacingM),
                  _Stat(label: 'Precisión', value: '$pct%'),
                  const SizedBox(width: AppDesignSystem.spacingM),
                  _Stat(
                    label: 'XP ganado',
                    value: '+$xpEarned',
                    highlight: true,
                    animatedValue: xpEarned,
                  ),
                ],
              ).animate().fadeIn(delay: 340.ms),
              if (reward?.usedGraceShield ?? false) ...[
                const SizedBox(height: AppDesignSystem.spacingM),
                Container(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.gold.withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(AppDesignSystem.radiusM),
                    border: Border.all(
                      color: AppDesignSystem.gold.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_rounded,
                          color: AppDesignSystem.gold, size: 22),
                      const SizedBox(width: AppDesignSystem.spacingS),
                      Expanded(
                        child: Text(
                          'Escudo de gracia activado: tu racha continuó a pesar del día perdido.',
                          style: AppDesignSystem.bodyMedium(
                            context,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  gradient: const LinearGradient(
                    colors: [AppDesignSystem.gold, AppDesignSystem.goldLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  child: Text(
                    'Terminar',
                    style: AppDesignSystem.labelLarge(
                      context,
                      color: AppDesignSystem.midnightDeep,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  /// Si se provee, el valor se anima con [AnimatedCounter] (anteponiendo "+").
  final int? animatedValue;

  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
    this.animatedValue,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final textStyle = AppDesignSystem.headlineMedium(
      context,
      color: highlight ? AppDesignSystem.gold : t.textPrimary,
    );
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: highlight ? AppDesignSystem.gold.withOpacity(0.5) : t.cardBorder,
          ),
        ),
        child: Column(
          children: [
            if (animatedValue != null)
              AnimatedCounter(
                value: animatedValue!,
                prefix: '+',
                duration: const Duration(milliseconds: 900),
                style: textStyle,
              )
            else
              Text(value, style: textStyle),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppDesignSystem.labelSmall(
                context,
                color: t.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
