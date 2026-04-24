/// LearningHomeCard — entry point compacto para la Escuela del Reino desde Home.
library;

import 'package:flutter/material.dart';

import '../../models/learning/learning_models.dart';
import '../../services/learning/learning_progress_service.dart';
import '../../services/learning/verse_memory_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class LearningHomeCard extends StatefulWidget {
  final VoidCallback onTap;

  const LearningHomeCard({super.key, required this.onTap});

  @override
  State<LearningHomeCard> createState() => _LearningHomeCardState();
}

class _LearningHomeCardState extends State<LearningHomeCard> {
  @override
  void initState() {
    super.initState();
    // Inits centralizados en LearningRegistry (main.dart FASE 3).
    // Estos servicios ya están listos cuando se monta la card.
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return ValueListenableBuilder<LearningProgress>(
      valueListenable: LearningProgressService.I.progressNotifier,
      builder: (context, p, _) {
        return ValueListenableBuilder<int>(
          valueListenable: VerseMemoryService.I.changeTickNotifier,
          builder: (context, _, _) {
            final due = VerseMemoryService.I.dueToday().length;
            final level = p.level;
            return InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
              child: Container(
                padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
                  border: Border.all(
                    color: AppDesignSystem.gold.withOpacity(0.25),
                  ),
                  boxShadow: t.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppDesignSystem.gold.withOpacity(0.35),
                            AppDesignSystem.gold.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: AppDesignSystem.gold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppDesignSystem.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Escuela del Reino',
                            style: AppDesignSystem.headlineSmall(
                              context,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            due > 0
                                ? 'Tienes $due versículo${due == 1 ? '' : 's'} para repasar'
                                : 'Maná del día + Armadura · ${level.emoji} ${level.displayName}',
                            style: AppDesignSystem.bodyMedium(
                              context,
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _Pill(
                                icon: Icons.stars_rounded,
                                label: '${p.totalXp} XP',
                              ),
                              const SizedBox(width: 6),
                              _Pill(
                                icon: Icons.favorite_rounded,
                                label: '${p.hearts}',
                                iconColor: const Color(0xFFE57373),
                              ),
                              const SizedBox(width: 6),
                              _Pill(
                                icon: Icons.local_fire_department_rounded,
                                label: '${p.studyStreak}d',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: t.textSecondary),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _Pill({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.textSecondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? AppDesignSystem.gold),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppDesignSystem.labelSmall(context, color: t.textPrimary),
          ),
        ],
      ),
    );
  }
}
