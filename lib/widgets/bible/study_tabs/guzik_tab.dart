import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_verse.dart';
import '../../../services/bible/enduring_word_service.dart';
import '../../../services/bible/bible_user_data_service.dart';
import '../../../theme/bible_reader_theme.dart';

/// Tab 3 del VerseStudySheet: comentario de David Guzik (Enduring Word).
class GuzikTab extends StatelessWidget {
  final BibleVerse verse;
  final ScrollController scrollController;

  const GuzikTab({
    super.key,
    required this.verse,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
        BibleReaderThemeData.migrateId(
            BibleUserDataService.I.readerThemeNotifier.value));

    return FutureBuilder<EWChapterCommentary?>(
      future: EnduringWordService.instance
          .getChapterCommentary(verse.bookNumber, verse.chapter),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: t.accent),
                const SizedBox(height: 12),
                Text(
                  'Cargando comentario de David Guzik…',
                  style: GoogleFonts.manrope(color: t.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final commentary = snapshot.data;
        if (commentary == null || commentary.isEmpty) {
          return _emptyState(t, 'Análisis no disponible para este capítulo.');
        }

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Attribution header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: t.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enduring Word — David Guzik',
                            style: GoogleFonts.manrope(
                                color: t.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('enduringword.com',
                            style: GoogleFonts.manrope(color: t.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sections
            ...commentary.sections.map((section) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: t.accent, width: 3)),
                        ),
                        child: Text(section.heading,
                            style: GoogleFonts.cinzel(
                                color: t.accent, fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 8),
                      ...section.paragraphs.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(p,
                                style: GoogleFonts.manrope(
                                    color: t.textPrimary.withValues(alpha: 0.85),
                                    fontSize: 14,
                                    height: 1.7)),
                          )),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _emptyState(BibleReaderThemeData t, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 40, color: t.accent.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                      color: t.textPrimary.withValues(alpha: 0.5), fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      );
}
