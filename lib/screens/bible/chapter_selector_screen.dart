import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_fonts.dart';
import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bible_reading_stats_service.dart';
import '../../services/bible/reading_history_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';

/// Pantalla dedicada de selección de capítulo.
/// Grid 7 columnas, sin cards, sin bordes.
class ChapterSelectorScreen extends StatelessWidget {
  final BibleBook book;
  final BibleVersion version;

  const ChapterSelectorScreen({
    super.key,
    required this.book,
    required this.version,
  });

  /// Hasta [max] capítulos distintos de [bookNumber], del más reciente al
  /// más antiguo según el historial de lectura.
  static List<int> recentChaptersFor(
    int bookNumber,
    List<ReadingHistoryEntry> history, {
    int max = 5,
  }) {
    final out = <int>[];
    for (final e in history) {
      if (e.bookNumber != bookNumber || out.contains(e.chapter)) continue;
      out.add(e.chapter);
      if (out.length >= max) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    ReadingHistoryService.I.ensureLoaded();
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (context, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );

        SystemChrome.setSystemUIOverlayStyle(
          t.oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );

        return Scaffold(
          backgroundColor: t.pageBg,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios,
                            color: t.textSecondary, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.name,
                              style: AppFonts.cinzel(
                                color: t.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${book.totalChapters} capítulos',
                              style: AppFonts.manrope(
                                color: t.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Recientes — capítulos de este libro visitados hace poco, del
                // más reciente al más antiguo (antes: los 5 de número más
                // alto entre los leídos, que no eran «recientes»).
                ValueListenableBuilder<List<ReadingHistoryEntry>>(
                  valueListenable: ReadingHistoryService.I.historyNotifier,
                  builder: (context, history, _) {
                    final recent = ChapterSelectorScreen.recentChaptersFor(
                      book.number,
                      history,
                    );
                    if (recent.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RECIENTES',
                            style: AppFonts.manrope(
                              color: t.textoTenue(0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: recent.map((ch) {
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pushReplacement(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (c, a1, a2) =>
                                          BibleReaderScreen(
                                        bookNumber: book.number,
                                        bookName: book.name,
                                        chapter: ch,
                                        version: version,
                                      ),
                                      transitionDuration:
                                          const Duration(milliseconds: 150),
                                      transitionsBuilder:
                                          (ctx, a, sa, child) =>
                                              FadeTransition(
                                                  opacity: a, child: child),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: t.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Cap. $ch',
                                    style: AppFonts.manrope(
                                      color: t.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Grid
                Expanded(
                  child: ValueListenableBuilder<Set<String>>(
                    valueListenable: BibleReadingStatsService.I.readChaptersNotifier,
                    builder: (context, readChapters, _) {
                      return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: book.totalChapters,
                    itemBuilder: (context, index) {
                      final chapter = index + 1;
                      final isRead = readChapters.contains('${book.number}:$chapter');
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          splashColor: t.accent.withValues(alpha: 0.25),
                          highlightColor: t.accent.withValues(alpha: 0.1),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (c, a1, a2) => BibleReaderScreen(
                                  bookNumber: book.number,
                                  bookName: book.name,
                                  chapter: chapter,
                                  version: version,
                                ),
                                transitionDuration:
                                    const Duration(milliseconds: 150),
                                transitionsBuilder: (ctx, a, sa, child) =>
                                    FadeTransition(opacity: a, child: child),
                              ),
                            );
                          },
                          child: Center(
                            child: Text(
                              '$chapter',
                              style: AppFonts.manrope(
                                color: isRead ? t.accent : t.textSecondary,
                                fontSize: 15,
                                fontWeight: isRead ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
}
