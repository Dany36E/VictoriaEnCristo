/// ═══════════════════════════════════════════════════════════════════════════
/// DailyChecklistCard — Checklist "X/4 hoy" con las 4 prácticas espirituales
///
/// Se auto-actualiza vía [DailyPracticeService.snapshotNotifier]. Cuando todas
/// están completas muestra un estado sutilmente dorado (sin confetti — el
/// confetti se reserva para hitos de racha).
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/daily_practice_service.dart';
import '../services/feedback_engine.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

class DailyChecklistCard extends StatefulWidget {
  /// Callbacks para navegar cuando el usuario toca un item no completado.
  final VoidCallback? onTapDevotional;
  final VoidCallback? onTapPrayer;
  final VoidCallback? onTapJournal;
  final VoidCallback? onTapVictory;
  final VoidCallback? onTapStudy;

  const DailyChecklistCard({
    super.key,
    this.onTapDevotional,
    this.onTapPrayer,
    this.onTapJournal,
    this.onTapVictory,
    this.onTapStudy,
  });

  @override
  State<DailyChecklistCard> createState() => _DailyChecklistCardState();
}

class _DailyChecklistCardState extends State<DailyChecklistCard> {
  @override
  void initState() {
    super.initState();
    DailyPracticeService.I.init();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return ValueListenableBuilder<DailyPracticeSnapshot>(
      valueListenable: DailyPracticeService.I.snapshotNotifier,
      builder: (context, snap, _) {
        final complete = snap.isComplete;
        return Semantics(
          label:
              'Prácticas de hoy: ${snap.completedCount} de ${snap.total} completas',
          child: Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius:
                  BorderRadius.circular(AppDesignSystem.radiusM),
              border: Border.all(
                color: complete
                    ? AppDesignSystem.gold.withOpacity(0.55)
                    : t.textSecondary.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      complete
                          ? Icons.check_circle_rounded
                          : Icons.playlist_add_check_rounded,
                      color: complete
                          ? AppDesignSystem.gold
                          : t.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Hoy',
                      style: AppDesignSystem.labelLarge(
                        context,
                        color: t.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${snap.completedCount}/${snap.total}',
                      style: AppDesignSystem.labelLarge(
                        context,
                        color: complete
                            ? AppDesignSystem.gold
                            : t.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesignSystem.spacingS),
                Row(
                  children: [
                    _Item(
                      icon: Icons.auto_stories_rounded,
                      label: 'Devocional',
                      done: snap.devotional,
                      onTap: () => _handleTap(
                        DailyPractice.devotional,
                        widget.onTapDevotional,
                        snap.devotional,
                      ),
                    ),
                    _Item(
                      icon: Icons.self_improvement_rounded,
                      label: 'Oración',
                      done: snap.prayer,
                      onTap: () => _handleTap(
                        DailyPractice.prayer,
                        widget.onTapPrayer,
                        snap.prayer,
                      ),
                    ),
                    _Item(
                      icon: Icons.menu_book_rounded,
                      label: 'Diario',
                      done: snap.journal,
                      onTap: () => _handleTap(
                        DailyPractice.journal,
                        widget.onTapJournal,
                        snap.journal,
                      ),
                    ),
                    _Item(
                      icon: Icons.emoji_events_rounded,
                      label: 'Victoria',
                      done: snap.victory,
                      onTap: () => _handleTap(
                        DailyPractice.victory,
                        widget.onTapVictory,
                        snap.victory,
                      ),
                    ),
                    _Item(
                      icon: Icons.school_rounded,
                      label: 'Aprender',
                      done: snap.study,
                      onTap: () => _handleTap(
                        DailyPractice.study,
                        widget.onTapStudy,
                        snap.study,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
              .animate(target: complete ? 1 : 0)
              .tint(
                color: AppDesignSystem.gold.withOpacity(0.05),
                duration: 400.ms,
              ),
        );
      },
    );
  }

  void _handleTap(
    DailyPractice practice,
    VoidCallback? onTap,
    bool currentlyDone,
  ) {
    FeedbackEngine.I.tap();
    // Si no está hecho y hay acción de navegación asociada, navegamos.
    if (!currentlyDone && onTap != null) {
      onTap();
      return;
    }
    // De lo contrario, toggle manual: permite marcar/desmarcar con tap largo.
    // (tap simple sin onTap = toggle).
    if (currentlyDone) {
      DailyPracticeService.I.unmark(practice);
    } else {
      DailyPracticeService.I.mark(practice);
    }
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final VoidCallback onTap;

  const _Item({
    required this.icon,
    required this.label,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: done,
        label: '$label ${done ? 'hecho' : 'pendiente'}',
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppDesignSystem.gold.withOpacity(0.18)
                        : t.textSecondary.withOpacity(0.06),
                    border: Border.all(
                      color: done
                          ? AppDesignSystem.gold.withOpacity(0.7)
                          : t.textSecondary.withOpacity(0.18),
                    ),
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : icon,
                    size: 18,
                    color: done
                        ? AppDesignSystem.gold
                        : t.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.labelSmall(
                    context,
                    color: done ? t.textPrimary : t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
