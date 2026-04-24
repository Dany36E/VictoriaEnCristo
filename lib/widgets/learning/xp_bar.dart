/// Widget compacto: XP bar con nivel actual, XP actual y siguiente nivel.
library;

import 'package:flutter/material.dart';

import '../../models/learning/learning_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class XpBar extends StatelessWidget {
  final LearningProgress progress;
  final bool compact;

  const XpBar({super.key, required this.progress, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final level = progress.level;
    final next = level.next;
    final p = progress.progressToNext.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(level.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              level.displayName,
              style: AppDesignSystem.labelLarge(context, color: t.textPrimary),
            ),
            const Spacer(),
            Text(
              '${progress.totalXp} XP',
              style:
                  AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
          child: LinearProgressIndicator(
            value: p,
            minHeight: compact ? 4 : 6,
            backgroundColor: t.textSecondary.withOpacity(0.15),
            valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
          ),
        ),
        if (!compact && next != null) ...[
          const SizedBox(height: 4),
          Text(
            'Siguiente: ${next.displayName} (${next.xpRequired - progress.totalXp} XP)',
            style:
                AppDesignSystem.labelSmall(context, color: t.textSecondary),
          ),
        ],
      ],
    );
  }
}

class HeartsDisplay extends StatelessWidget {
  final int hearts;
  final int max;

  const HeartsDisplay({super.key, required this.hearts, this.max = 3});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < hearts;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            filled ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 20,
            color: filled ? const Color(0xFFE57373) : t.textSecondary.withOpacity(0.4),
          ),
        );
      }),
    );
  }
}
