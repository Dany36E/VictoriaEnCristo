/// ═══════════════════════════════════════════════════════════════════════════
/// GameDifficultySelector — tarjeta con las 3 dificultades (fácil/medio/difícil).
///
/// Reutilizada por los juegos de preguntas (Carrera de la Fe, Duelo Relámpago).
/// Opcionalmente muestra cuántas preguntas hay disponibles por dificultad.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/game_difficulty.dart';
import '../../services/feedback_engine.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class GameDifficultySelector extends StatelessWidget {
  final GameDifficulty selected;
  final ValueChanged<GameDifficulty> onSelected;

  /// Conteo opcional de preguntas disponibles por dificultad.
  final Map<GameDifficulty, int>? counts;

  const GameDifficultySelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: t.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dificultad',
            style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          for (final difficulty in GameDifficulty.values) ...[
            _option(context, t, difficulty),
            if (difficulty != GameDifficulty.values.last)
              const SizedBox(height: AppDesignSystem.spacingS),
          ],
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context,
    AppThemeData t,
    GameDifficulty difficulty,
  ) {
    final isSelected = selected == difficulty;
    final count = counts?[difficulty];
    final subtitle = count != null
        ? '${difficulty.description} · $count preguntas'
        : difficulty.description;
    return InkWell(
      onTap: () {
        if (selected == difficulty) return;
        FeedbackEngine.I.select();
        onSelected(difficulty);
      },
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          color: isSelected
              ? difficulty.color.withValues(alpha: 0.14)
              : t.inputBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: isSelected
                ? difficulty.color.withValues(alpha: 0.72)
                : t.cardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(difficulty.icon, color: difficulty.color),
            const SizedBox(width: AppDesignSystem.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficulty.label,
                    style: AppDesignSystem.labelLarge(
                      context,
                      color: t.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppDesignSystem.bodyMedium(
                      context,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? difficulty.color : t.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
