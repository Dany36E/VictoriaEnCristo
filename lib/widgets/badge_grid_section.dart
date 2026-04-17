/// ═══════════════════════════════════════════════════════════════════════════
/// BADGE GRID SECTION — resumen premium de insignias
/// ═══════════════════════════════════════════════════════════════════════════
/// • Ring hero con progreso global + "próxima insignia"
/// • Cada categoría con progreso visual por niveles
/// • Tooltip y microcopy cálida (sin "Sin desbloquear")
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/badge_definition.dart';
import '../services/badge_service.dart';
import '../theme/app_theme_data.dart';

class BadgeGridSection extends StatelessWidget {
  const BadgeGridSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final allProgress = BadgeService.I.getAllProgress();
    final totalUnlocked = BadgeService.I.totalUnlocked;
    final totalPossible = BadgeService.I.totalPossible;
    final overall = totalPossible == 0
        ? 0.0
        : (totalUnlocked / totalPossible).clamp(0.0, 1.0);

    // "Próxima insignia" = la que tiene mayor progresso relativo sin cumplirse
    BadgeProgress? nearest;
    double nearestPct = -1;
    for (final p in allProgress) {
      if (p.nextLevel == null) continue;
      final pct = p.progressToNext;
      if (pct > nearestPct) {
        nearestPct = pct;
        nearest = p;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: t.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroHeader(
            totalUnlocked: totalUnlocked,
            totalPossible: totalPossible,
            overall: overall,
            nearest: nearest,
            theme: t,
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: t.divider),
          const SizedBox(height: 16),
          ...allProgress.map((p) => _BadgeRow(progress: p, theme: t)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO HEADER — anillo + stats + próxima insignia
// ═══════════════════════════════════════════════════════════════════════════

class _HeroHeader extends StatelessWidget {
  final int totalUnlocked;
  final int totalPossible;
  final double overall;
  final BadgeProgress? nearest;
  final AppThemeData theme;

  const _HeroHeader({
    required this.totalUnlocked,
    required this.totalPossible,
    required this.overall,
    required this.nearest,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final nearestColor = nearest != null
        ? Color(nearest!.nextLevel!.colorValue)
        : theme.accent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 6,
                  backgroundColor: Colors.transparent,
                  color: theme.textSecondary.withOpacity(0.12),
                ),
              ),
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: overall,
                  strokeWidth: 6,
                  backgroundColor: Colors.transparent,
                  color: theme.accent,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$totalUnlocked',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                      height: 1,
                    ),
                  ),
                  Text(
                    'de $totalPossible',
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      color: theme.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Insignias',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              if (nearest != null)
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: nearestColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Próxima: ${nearest!.nextLevel!.displayName} • ${nearest!.category.displayName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  totalUnlocked == totalPossible && totalPossible > 0
                      ? '¡Todas las insignias obtenidas! 👑'
                      : 'Tu camino de fe en imágenes',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: theme.textSecondary,
                  ),
                ),
              const SizedBox(height: 6),
              if (nearest != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: nearest!.progressToNext,
                    minHeight: 4,
                    backgroundColor: theme.textSecondary.withOpacity(0.12),
                    color: nearestColor,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BADGE ROW
// ═══════════════════════════════════════════════════════════════════════════

class _BadgeRow extends StatelessWidget {
  final BadgeProgress progress;
  final AppThemeData theme;

  const _BadgeRow({required this.progress, required this.theme});

  @override
  Widget build(BuildContext context) {
    final cat = progress.category;
    final hasUnlocked = progress.unlockedLevel != null;
    final levelColor = hasUnlocked
        ? Color(progress.unlockedLevel!.colorValue)
        : theme.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: (hasUnlocked ? levelColor : theme.textSecondary)
                      .withOpacity(theme.isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(cat.emoji, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cat.displayName,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              if (hasUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(theme.isDark ? 0.22 : 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        progress.unlockedLevel!.emoji,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        progress.unlockedLevel!.displayName,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: levelColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'Aún en camino',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: theme.textSecondary.withOpacity(0.7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: List.generate(BadgeLevel.values.length, (i) {
              final level = BadgeLevel.values[i];
              final isUnlocked =
                  hasUnlocked && i <= progress.unlockedLevel!.index;
              final isNext = progress.nextLevel == level;
              final dotColor = Color(level.colorValue);

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                  child: Tooltip(
                    message:
                        '${level.displayName} • ${cat.thresholds[i]}${isUnlocked ? ' ✓' : ''}',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: isUnlocked ? 10 : (isNext ? 9 : 7),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? dotColor
                            : isNext
                                ? dotColor.withOpacity(0.28)
                                : theme.textSecondary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: isUnlocked
                            ? [
                                BoxShadow(
                                  color: dotColor.withOpacity(0.5),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),

          if (progress.nextLevel != null)
            Row(
              children: [
                Text(
                  '${progress.currentValue}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
                Text(
                  ' / ${progress.nextThreshold}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'para ${progress.nextLevel!.displayName} ${progress.nextLevel!.emoji}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: theme.textSecondary.withOpacity(0.85),
                    ),
                  ),
                ),
              ],
            )
          else if (hasUnlocked)
            Text(
              '¡Nivel máximo alcanzado! 👑',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.accent,
              ),
            ),
        ],
      ),
    );
  }
}
/// ═══════════════════════════════════════════════════════════════════════════
