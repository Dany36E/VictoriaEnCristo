import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../models/bible/highlight.dart';
import '../../../services/bible/bible_tts_service.dart';
import '../../../services/bible/bible_user_data_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../theme/bible_reader_theme.dart';
import '../cross_refs_panel.dart';
import '../chapter_tools_section.dart';
import 'reader_verse_item.dart';
import 'reader_study_section.dart';
import 'reader_bottom_nav.dart';
import 'reader_chapter_note.dart';

class ReaderContentView extends StatelessWidget {
  final BibleReaderThemeData theme;
  final BibleReaderController controller;
  final ScrollController scrollController;
  final VoidCallback onGoToNextBook;
  final void Function(int bookNum, String bookName, int chapter) onGoToBook;
  final void Function(int bookNum, String bookName, int chapter) onBottomNavBookTap;

  const ReaderContentView({
    super.key,
    required this.theme,
    required this.controller,
    required this.scrollController,
    required this.onGoToNextBook,
    required this.onGoToBook,
    required this.onBottomNavBookTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return ValueListenableBuilder<Map<String, Highlight>>(
      valueListenable: BibleUserDataService.I.highlightsNotifier,
      builder: (context, highlights, _) {
        return ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: BibleUserDataService.I.notesNotifier,
          builder: (context, notes, _) {
            return ValueListenableBuilder<double>(
              valueListenable: BibleUserDataService.I.fontSizeNotifier,
              builder: (context, fontSize, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: BibleTtsService.I.currentVerseIndex,
                  builder: (context, ttsVerseIdx, _) {
                    return CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 56)),
                        _buildOfflineBanner(t),
                        _buildChapterOrnament(t),
                        _buildVerseSliver(
                            t, highlights, notes, fontSize, ttsVerseIdx),
                        if (controller.selectedVerseIndex != null &&
                            controller.selectedVerseIndex! <
                                controller.verses.length &&
                            !controller.isSelectionMode)
                          SliverToBoxAdapter(
                            child: CrossRefsPanel(
                              key: ValueKey(
                                  'xref_${controller.verses[controller.selectedVerseIndex!].uniqueKey}'),
                              verse: controller
                                  .verses[controller.selectedVerseIndex!],
                              theme: t,
                              onNavigate: (bookNum, bookName, chapter) {
                                controller.clearSelection();
                                onGoToBook(bookNum, bookName, chapter);
                              },
                            ),
                          ),
                        SliverToBoxAdapter(
                            child: ReaderChapterNoteIndicator(
                                theme: t, controller: controller)),
                        SliverToBoxAdapter(
                          child: ChapterToolsSection(
                            bookNumber: controller.bookNumber,
                            bookName: controller.bookName,
                            chapter: controller.currentChapter,
                            theme: t,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: ReaderBottomNav(
                            theme: t,
                            controller: controller,
                            onGoToNextBook: onGoToNextBook,
                            onGoToBook: onBottomNavBookTap,
                          ),
                        ),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 80)),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  SliverToBoxAdapter _buildOfflineBanner(BibleReaderThemeData t) {
    return SliverToBoxAdapter(
      child: ValueListenableBuilder<bool>(
        valueListenable: ConnectivityService.I.isOnline,
        builder: (_, online, _) {
          if (online) return const SizedBox.shrink();
          return Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            color: const Color(0xFF1A1A2E),
            child: Row(children: [
              Icon(Icons.wifi_off_outlined,
                  size: 12, color: t.textSecondary.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(
                'Sin conexión · Funciones online no disponibles',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: t.textSecondary.withOpacity(0.5),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _buildChapterOrnament(BibleReaderThemeData t) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 32, right: 32, bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${controller.currentChapter}',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.25),
                fontSize: 64,
                fontWeight: FontWeight.w200,
                height: 1.0,
              ),
            ),
            if (controller.chapterIntro != null) ...[
              const SizedBox(height: 12),
              Text(
                controller.chapterIntro!,
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.5),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  SliverPadding _buildVerseSliver(
    BibleReaderThemeData t,
    Map<String, Highlight> highlights,
    Map<String, dynamic> notes,
    double fontSize,
    int ttsVerseIdx,
  ) {
    final useStudy =
        controller.studyModeEnabled && controller.studyItems.isNotEmpty;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (useStudy) {
              final item = controller.studyItems[index];
              switch (item.type) {
                case StudyItemType.banner:
                  return ReaderStudyBanner(theme: t);
                case StudyItemType.verse:
                  return _buildVerse(
                      item.index, t, highlights, notes, fontSize, ttsVerseIdx);
                case StudyItemType.annotation:
                  return ReaderAnnotationBlock(
                    sectionIndex: item.index,
                    theme: t,
                    fontSize: fontSize,
                    controller: controller,
                  );
                case StudyItemType.attribution:
                  return ReaderGuzikAttribution(theme: t);
              }
            }
            return _buildVerse(
                index, t, highlights, notes, fontSize, ttsVerseIdx);
          },
          childCount:
              useStudy ? controller.studyItems.length : controller.verses.length,
        ),
      ),
    );
  }

  Widget _buildVerse(
    int vi,
    BibleReaderThemeData t,
    Map<String, Highlight> highlights,
    Map<String, dynamic> notes,
    double fontSize,
    int ttsVerseIdx,
  ) {
    final verse = controller.verses[vi];
    final key = verse.uniqueKey;
    return ReaderVerseItem(
      verse: verse,
      index: vi,
      highlight: highlights[key],
      hasNote: notes.containsKey(key),
      isSelected: controller.selectedVerseIndex == vi,
      isMultiSelected: controller.isSelectionMode &&
          controller.selectedVerseNumbers.contains(verse.verse),
      isTtsActive: ttsVerseIdx == vi,
      fontSize: fontSize,
      theme: t,
      controller: controller,
    );
  }
}
