import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/bible/bible_reading_stats_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE STATS SCREEN — Reading progress & streak overview
/// ═══════════════════════════════════════════════════════════════════════════
class BibleStatsScreen extends StatelessWidget {
  const BibleStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (context, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, t),
            Expanded(
              child: ValueListenableBuilder<Map<String, dynamic>>(
                valueListenable: BibleReadingStatsService.I.statsNotifier,
                builder: (context, stats, _) {
                  final streak = stats['streak'] as int? ?? 0;
                  final pct = stats['percentRead'] as double? ?? 0.0;
                  final chaptersRead = stats['chaptersRead'] as int? ?? 0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Streak card
                        _buildStatCard(
                          t,
                          icon: Icons.local_fire_department,
                          iconColor: const Color(0xFFFF6B35),
                          title: 'Racha de Lectura',
                          value: '$streak',
                          subtitle: streak == 1 ? 'día consecutivo' : 'días consecutivos',
                        ),
                        const SizedBox(height: 20),

                        // Chapters card
                        _buildStatCard(
                          t,
                          icon: Icons.menu_book_outlined,
                          iconColor: t.accent,
                          title: 'Capítulos Leídos',
                          value: '$chaptersRead',
                          subtitle: 'de ${BibleReadingStatsService.totalBibleChapters} capítulos',
                        ),
                        const SizedBox(height: 20),

                        // Progress card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_graph, color: t.accent, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Progreso Total',
                                    style: GoogleFonts.manrope(
                                      color: t.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Large percentage
                              Center(
                                child: Text(
                                  '${pct.toStringAsFixed(1)}%',
                                  style: GoogleFonts.instrumentSerif(
                                    color: t.accent,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct / 100,
                                  minHeight: 8,
                                  backgroundColor: t.textSecondary.withOpacity(0.1),
                                  color: t.accent,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$chaptersRead / ${BibleReadingStatsService.totalBibleChapters} capítulos',
                                style: GoogleFonts.manrope(
                                  color: t.textSecondary.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Motivational text
                        if (chaptersRead == 0)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Comienza a leer y tu progreso aparecerá aquí',
                                style: GoogleFonts.manrope(
                                  color: t.textSecondary.withOpacity(0.4),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildHeader(BuildContext context, BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  color: t.textSecondary, size: 14),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Estadísticas de Lectura',
            style: GoogleFonts.instrumentSerif(
              color: t.textPrimary,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BibleReaderThemeData t, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.instrumentSerif(
                        color: t.textPrimary,
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
