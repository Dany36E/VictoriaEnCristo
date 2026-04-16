import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/bible/bible_reading_stats_service.dart';
import '../../theme/app_theme_data.dart';

/// Mini-card que muestra racha de lectura bíblica y progreso.
/// Se alimenta del ValueNotifier de BibleReadingStatsService.
class BibleReadingStreak extends StatelessWidget {
  final VoidCallback? onTap;

  const BibleReadingStreak({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);

    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: BibleReadingStatsService.I.statsNotifier,
      builder: (context, stats, _) {
        final streak = (stats['streak'] as int?) ?? 0;
        final chaptersRead = (stats['chaptersRead'] as int?) ?? 0;
        final percentRead = (stats['percentRead'] as double?) ?? 0.0;

        // No mostrar si no hay actividad de lectura
        if (chaptersRead == 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.cardBg.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: t.accent.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                // Icono Biblia
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: t.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: t.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Stats text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        streak > 0
                            ? '$streak día${streak == 1 ? '' : 's'} leyendo la Biblia'
                            : '$chaptersRead capítulo${chaptersRead == 1 ? '' : 's'} leído${chaptersRead == 1 ? '' : 's'}',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Progress bar
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (percentRead / 100).clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: t.textSecondary.withOpacity(0.12),
                                valueColor: AlwaysStoppedAnimation(t.accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${percentRead.toStringAsFixed(1)}%',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: t.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: t.textSecondary.withOpacity(0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
