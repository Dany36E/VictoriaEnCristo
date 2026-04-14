/// ═══════════════════════════════════════════════════════════════════════════
/// BADGE GRID SECTION - Sección de insignias para el perfil
/// Diseño cálido y luminoso con progreso visual
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: t.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('🏅', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insignias',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: t.textPrimary,
                      ),
                    ),
                    Text(
                      '$totalUnlocked de $totalPossible desbloqueadas',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Badge rows
          ...allProgress.map((p) => _buildBadgeRow(context, p)),
        ],
      ),
    );
  }

  Widget _buildBadgeRow(BuildContext context, BadgeProgress progress) {
    final t = AppThemeData.of(context);
    final cat = progress.category;
    final hasUnlocked = progress.unlockedLevel != null;
    final levelColor = hasUnlocked
        ? Color(progress.unlockedLevel!.colorValue)
        : t.textSecondary.withOpacity(0.3);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category label + level
          Row(
            children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cat.displayName,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
              ),
              if (hasUnlocked) ...[
                Text(
                  progress.unlockedLevel!.emoji,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                Text(
                  progress.unlockedLevel!.displayName,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: levelColor,
                  ),
                ),
              ] else
                Text(
                  'Sin desbloquear',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: t.textSecondary.withOpacity(0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // 7 level dots
          Row(
            children: List.generate(BadgeLevel.values.length, (i) {
              final level = BadgeLevel.values[i];
              final isUnlocked = hasUnlocked && i <= progress.unlockedLevel!.index;
              final isNext = progress.nextLevel == level;
              final dotColor = Color(level.colorValue);

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                  child: Tooltip(
                    message: '${level.displayName}: ${cat.thresholds[i]}',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 8,
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? dotColor
                            : isNext
                                ? dotColor.withOpacity(0.20)
                                : t.textSecondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),

          // Progress text
          if (progress.nextLevel != null)
            Text(
              '${progress.currentValue} / ${progress.nextThreshold} para ${progress.nextLevel!.displayName}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: t.textSecondary.withOpacity(0.5),
              ),
            )
          else if (hasUnlocked)
            Text(
              '¡Nivel máximo alcanzado! 👑',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: t.accent.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }
}
