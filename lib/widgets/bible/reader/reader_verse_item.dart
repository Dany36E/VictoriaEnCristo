import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../models/bible/bible_verse.dart';
import '../../../models/bible/highlight.dart';
import '../../../models/bible/study_word_highlight.dart';
import '../../../services/bible/bible_search_service.dart';
import '../../../services/bible/red_letter_service.dart';
import '../../../services/bible/study_mode_service.dart';
import '../../../theme/bible_reader_theme.dart';

class ReaderVerseItem extends StatelessWidget {
  final BibleVerse verse;
  final int index;
  final Highlight? highlight;
  final bool hasNote;
  final bool isSelected;
  final bool isMultiSelected;
  final bool isTtsActive;
  final double fontSize;
  final BibleReaderThemeData theme;
  final BibleReaderController controller;

  const ReaderVerseItem({
    super.key,
    required this.verse,
    required this.index,
    required this.highlight,
    required this.hasNote,
    required this.isSelected,
    required this.isMultiSelected,
    required this.isTtsActive,
    required this.fontSize,
    required this.theme,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<StudyWordHighlight>>(
      valueListenable: StudyModeService.I.highlightsNotifier,
      builder: (context, allWordHighlights, _) {
        final versionId = controller.currentVersion.id;
        final wordHighlights = allWordHighlights
            .where(
              (h) =>
                  h.versionId == versionId &&
                  h.bookNumber == verse.bookNumber &&
                  h.chapter == verse.chapter &&
                  h.verse == verse.verse,
            )
            .toList(growable: false);
        return _buildBody(context, wordHighlights);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<StudyWordHighlight> wordHighlights,
  ) {
    final highlightBg = highlight != null
        ? theme.highlightOverlay(highlight!.color)
        : null;
    final showSelected = isSelected || isMultiSelected || isTtsActive;

    return Semantics(
      label: 'Versículo ${verse.verse}. ${verse.text}',
      selected: isSelected || isMultiSelected,
      hint: isSelected
          ? 'Toca de nuevo para selección múltiple'
          : controller.isSelectionMode
          ? (isMultiSelected
                ? 'Toca para deseleccionar'
                : 'Toca para seleccionar')
          : 'Toca para seleccionar versículo',
      child: GestureDetector(
        onTap: () => controller.tapVerse(index),
        onLongPress: () => controller.longPressVerse(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: isTtsActive ? 8 : 0,
          ),
          decoration: BoxDecoration(
            color: showSelected
                ? (isMultiSelected
                      ? theme.accent.withOpacity(0.12)
                      : theme.selectionBg)
                : null,
            border: isTtsActive
                ? const Border(
                    left: BorderSide(color: Color(0xFFD4AF37), width: 3),
                  )
                : null,
          ),
          child: RichText(
            text: TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Transform.translate(
                    offset: const Offset(0, -2),
                    child: isMultiSelected
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.only(right: 2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD4AF37),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 9,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '${verse.verse} ',
                                style: GoogleFonts.manrope(
                                  color: const Color(0xFFD4AF37),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            '${verse.verse} ',
                            style: GoogleFonts.manrope(
                              color: showSelected
                                  ? theme.accent
                                  : theme.textSecondary.withOpacity(0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                ..._buildVerseTextSpans(
                  verse.text,
                  fontSize: fontSize,
                  theme: theme,
                  highlightBg: highlightBg,
                  wordHighlights: wordHighlights,
                  isSearchMatch:
                      controller.searchQuery.length >= 2 &&
                      controller.searchMatchIndices.contains(index),
                  isRedLetter:
                      controller.redLettersEnabled &&
                      RedLetterService.instance.isRedLetter(
                        verse.bookNumber,
                        verse.chapter,
                        verse.verse,
                      ),
                ),
                if (hasNote)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.top,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(Icons.circle, color: theme.accent, size: 5),
                    ),
                  ),
                if (controller.harmonyVerses.contains(verse.verse))
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Text(
                        '⊞',
                        style: TextStyle(
                          color: const Color(0xFF42A5F5).withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                if (controller.quoteVerses.contains(verse.verse))
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 0.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7043).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          verse.bookNumber <= 39 ? '↗NT' : 'AT',
                          style: TextStyle(
                            color: const Color(0xFFFF7043).withOpacity(0.7),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildVerseTextSpans(
    String text, {
    required double fontSize,
    required BibleReaderThemeData theme,
    required Color? highlightBg,
    required List<StudyWordHighlight> wordHighlights,
    required bool isSearchMatch,
    bool isRedLetter = false,
  }) {
    final textColor = isRedLetter ? theme.redLetterColor : theme.textPrimary;
    final baseStyle = GoogleFonts.lora(
      color: textColor,
      fontSize: fontSize,
      height: 1.8,
      backgroundColor: highlightBg,
    );

    // Si hay subrayados granulares (palabra/frase) del Modo Estudio, los
    // rendereamos por encima del color de versículo, palabra por palabra.
    if (wordHighlights.isNotEmpty &&
        !(isSearchMatch && controller.searchQuery.length >= 2)) {
      return _buildWordHighlightedSpans(
        text,
        baseStyle: baseStyle,
        theme: theme,
        wordHighlights: wordHighlights,
      );
    }

    if (!isSearchMatch || controller.searchQuery.length < 2) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final normalizedText = BibleSearchService.normalize(text);
    final normalizedQuery = BibleSearchService.normalize(
      controller.searchQuery,
    );
    final idx = normalizedText.indexOf(normalizedQuery);
    if (idx < 0) return [TextSpan(text: text, style: baseStyle)];

    final end = idx + normalizedQuery.length;
    final spans = <InlineSpan>[];
    if (idx > 0) {
      spans.add(TextSpan(text: text.substring(0, idx), style: baseStyle));
    }
    spans.add(
      TextSpan(
        text: text.substring(idx, end.clamp(0, text.length)),
        style: baseStyle.copyWith(
          color: theme.background,
          backgroundColor: const Color(0xFFD4AF37),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (end < text.length) {
      spans.add(TextSpan(text: text.substring(end), style: baseStyle));
    }
    return spans;
  }

  /// Tokeniza el texto en palabras (separadas por espacios) y aplica el
  /// color de subrayado por palabra cuando hay highlights granulares.
  /// Si una palabra está cubierta por varios códigos, mezcla la opacidad
  /// del último (consistente con el render del Modo Estudio).
  List<InlineSpan> _buildWordHighlightedSpans(
    String text, {
    required TextStyle baseStyle,
    required BibleReaderThemeData theme,
    required List<StudyWordHighlight> wordHighlights,
  }) {
    final spans = <InlineSpan>[];
    // Split preservando espacios para mantener fielmente el texto original.
    final regex = RegExp(r'(\s+)');
    final parts = <String>[];
    int last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) parts.add(text.substring(last, m.start));
      parts.add(text.substring(m.start, m.end));
      last = m.end;
    }
    if (last < text.length) parts.add(text.substring(last));

    int wordIndex = 0;
    for (final part in parts) {
      final isWhitespace = part.trim().isEmpty;
      if (isWhitespace) {
        spans.add(TextSpan(text: part, style: baseStyle));
        continue;
      }
      // Buscar el último highlight que cubre esta palabra (orden de creación).
      StudyWordHighlight? cover;
      for (final h in wordHighlights) {
        if (h.overlapsWord(wordIndex)) {
          cover = (cover == null || h.createdAt.isAfter(cover.createdAt))
              ? h
              : cover;
        }
      }
      if (cover == null) {
        spans.add(TextSpan(text: part, style: baseStyle));
      } else {
        final color = cover.codeEnum.color;
        spans.add(
          TextSpan(
            text: part,
            style: baseStyle.copyWith(
              backgroundColor: color.withOpacity(theme.isDark ? 0.32 : 0.28),
            ),
          ),
        );
      }
      wordIndex++;
    }
    return spans;
  }
}
