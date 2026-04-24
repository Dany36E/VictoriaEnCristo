/// ═══════════════════════════════════════════════════════════════════════════
/// MilestoneBanner — Pequeño banner contextual en Home que combina:
///   - Hito alcanzado (3, 7, 14, 30, 60, 90, 180, 365): mensaje + versículo
///   - Próximo hito visible: "X días para tu próxima montaña"
///   - Si hay recaída pendiente: nada (lo maneja RelapseRecoveryScreen)
///   - Si streak = 0 sin recaída: mensaje de normalización (no empieza de cero)
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/streak_milestones.dart';
import '../services/victory_scoring_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

class MilestoneBanner extends StatelessWidget {
  final int streak;

  const MilestoneBanner({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);

    // Si hay recaída pendiente, no mostrar nada (otro flujo se encarga).
    if (VictoryScoringService.I.hasPendingRelapseAck) {
      return const SizedBox.shrink();
    }

    final milestone = StreakMilestones.milestoneFor(streak);
    final next = StreakMilestones.nextMilestone(streak);

    // Caso 1: día de hito exacto → celebración en banner (dorado).
    if (milestone != null) {
      return _buildMilestone(context, t, milestone).animate().fadeIn();
    }

    // Caso 2: streak 0 → mensaje de normalización (no condenatorio).
    if (streak == 0) {
      return _buildEncouragement(
        context,
        t,
        icon: Icons.wb_twilight_rounded,
        message: StreakMilestones.encouragementFor(0),
      );
    }

    // Caso 3: entre hitos → mostrar próximo objetivo + ánimo.
    if (next != null) {
      final daysTo = next.day - streak;
      return _buildProgress(
        context,
        t,
        current: streak,
        daysToNext: daysTo,
        nextTitle: next.title,
        encouragement: StreakMilestones.encouragementFor(streak),
      );
    }

    // Caso 4: después del último hito (365+) → ánimo general.
    return _buildEncouragement(
      context,
      t,
      icon: Icons.auto_awesome_rounded,
      message: StreakMilestones.encouragementFor(streak),
    );
  }

  Widget _buildMilestone(
    BuildContext context,
    AppThemeData t,
    StreakMilestone m,
  ) {
    return Semantics(
      label: 'Hito alcanzado: ${m.title}',
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppDesignSystem.gold.withOpacity(0.18),
              AppDesignSystem.goldLight.withOpacity(0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: AppDesignSystem.gold.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(m.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m.title,
                    style: AppDesignSystem.headlineSmall(
                      context,
                      color: AppDesignSystem.gold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              m.message,
              style:
                  AppDesignSystem.bodyMedium(context, color: t.textPrimary),
            ),
            const SizedBox(height: AppDesignSystem.spacingS),
            Text(
              m.verse,
              style:
                  AppDesignSystem.scripture(context, color: t.textSecondary),
            ),
            Text(
              m.reference,
              style: AppDesignSystem.scriptureReference(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(
    BuildContext context,
    AppThemeData t, {
    required int current,
    required int daysToNext,
    required String nextTitle,
    required String encouragement,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(
          color: AppDesignSystem.gold.withOpacity(0.14),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.trending_up_rounded,
            color: AppDesignSystem.gold,
            size: 28,
          ),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$daysToNext día${daysToNext == 1 ? '' : 's'} para $nextTitle',
                  style: AppDesignSystem.labelLarge(
                    context,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  encouragement,
                  style: AppDesignSystem.bodyMedium(
                    context,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncouragement(
    BuildContext context,
    AppThemeData t, {
    required IconData icon,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(
          color: t.textSecondary.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppDesignSystem.gold, size: 24),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Text(
              message,
              style: AppDesignSystem.bodyMedium(
                context,
                color: t.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
