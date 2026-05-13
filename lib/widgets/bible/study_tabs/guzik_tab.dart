import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_verse.dart';
import '../../../services/bible/enduring_word_service.dart';
import '../../../services/bible/bible_user_data_service.dart';
import '../../../theme/bible_reader_theme.dart';

/// Tab 3 del VerseStudySheet: comentario de David Guzik (Enduring Word).
class GuzikTab extends StatefulWidget {
  final BibleVerse verse;
  final ScrollController scrollController;

  const GuzikTab({
    super.key,
    required this.verse,
    required this.scrollController,
  });

  @override
  State<GuzikTab> createState() => _GuzikTabState();
}

class _GuzikTabState extends State<GuzikTab> {
  static final _verseRangeRegex = RegExp(r'\((\d+)(?:\s*-\s*(\d+))?\)');

  bool _showFullChapter = false;

  @override
  void didUpdateWidget(covariant GuzikTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verse.bookNumber != widget.verse.bookNumber ||
        oldWidget.verse.chapter != widget.verse.chapter ||
        oldWidget.verse.verse != widget.verse.verse) {
      _showFullChapter = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
        BibleUserDataService.I.readerThemeNotifier.value,
      ),
    );

    return FutureBuilder<EWChapterCommentary?>(
      future: EnduringWordService.instance.getChapterCommentary(
        widget.verse.bookNumber,
        widget.verse.chapter,
      ),
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
                  style: GoogleFonts.manrope(
                    color: t.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        final commentary = snapshot.data;
        if (commentary == null || commentary.isEmpty) {
          return _emptyState(t, 'Análisis no disponible para este capítulo.');
        }

        final focusedSections = _sectionsForVerse(
          commentary,
          widget.verse.verse,
        );
        final hasFocusedSections = focusedSections.isNotEmpty;
        final showFocused = hasFocusedSections && !_showFullChapter;
        final sections = showFocused ? focusedSections : commentary.sections;

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            _attributionHeader(t),
            const SizedBox(height: 16),
            if (hasFocusedSections) ...[
              _scopeSelector(t),
              const SizedBox(height: 14),
            ],
            ...sections.map((section) => _sectionBlock(t, section)),
          ],
        );
      },
    );
  }

  List<EWSection> _sectionsForVerse(
    EWChapterCommentary commentary,
    int verseNumber,
  ) {
    final sections = <EWSection>[];
    for (final section in commentary.sections) {
      final match = _verseRangeRegex.firstMatch(section.heading);
      if (match == null) continue;
      final start = int.tryParse(match.group(1) ?? '');
      final end = int.tryParse(match.group(2) ?? '') ?? start;
      if (start == null || end == null) continue;
      if (verseNumber >= start && verseNumber <= end) {
        sections.add(section);
      }
    }
    return sections;
  }

  Widget _attributionHeader(BibleReaderThemeData t) {
    return Container(
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
                Text(
                  'Enduring Word — David Guzik',
                  style: GoogleFonts.manrope(
                    color: t.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'enduringword.com',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scopeSelector(BibleReaderThemeData t) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _scopeChip(
          t,
          label: 'v. ${widget.verse.verse}',
          selected: !_showFullChapter,
          onTap: () => setState(() => _showFullChapter = false),
        ),
        _scopeChip(
          t,
          label: 'Capítulo completo',
          selected: _showFullChapter,
          onTap: () => setState(() => _showFullChapter = true),
        ),
      ],
    );
  }

  Widget _scopeChip(
    BibleReaderThemeData t, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: selected ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? t.accent.withValues(alpha: 0.55)
                : t.textPrimary.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: selected ? t.accent : t.textPrimary.withValues(alpha: 0.64),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _sectionBlock(BibleReaderThemeData t, EWSection section) {
    return Padding(
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
            child: Text(
              section.heading,
              style: GoogleFonts.cinzel(
                color: t.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...section.paragraphs.map(
            (paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                paragraph,
                style: GoogleFonts.manrope(
                  color: t.textPrimary.withValues(alpha: 0.85),
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BibleReaderThemeData t, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 40,
            color: t.accent.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: t.textPrimary.withValues(alpha: 0.5),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}
