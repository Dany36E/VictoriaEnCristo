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
  final bool isTtsActive;
  final double fontSize;
  final BibleReaderThemeData theme;
  final BibleReaderController controller;

  /// Si este versículo está en modo palabra (subrayado token por token).
  final bool wordSelectionActive;

  /// Índices de palabra seleccionados (solo relevante si wordSelectionActive).
  final Set<int> selectedWords;

  const ReaderVerseItem({
    super.key,
    required this.verse,
    required this.index,
    required this.highlight,
    required this.hasNote,
    required this.isSelected,
    required this.isTtsActive,
    required this.fontSize,
    required this.theme,
    required this.controller,
    this.wordSelectionActive = false,
    this.selectedWords = const <int>{},
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
    // Modo palabra: el versículo se vuelve tappable token por token.
    if (wordSelectionActive) {
      return _buildWordSelectionBody(wordHighlights);
    }

    final highlightBg = highlight != null
        ? theme.highlightOverlay(highlight!.color)
        : null;

    return Semantics(
      label: 'Versículo ${verse.verse}. ${verse.text}',
      selected: isSelected,
      hint: isSelected
          ? 'Toca para deseleccionar'
          : 'Toca para seleccionar versículo',
      child: GestureDetector(
        onTap: () => controller.tapVerse(index),
        // Mantener presionado → entra al modo palabra (atajo directo).
        onLongPress: () => controller.enterWordSelection(verse.verse),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: isTtsActive ? 8 : 0,
          ),
          decoration: BoxDecoration(
            color: isTtsActive ? theme.selectionBg : null,
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
                    child: Text(
                      '${verse.verse} ',
                      style: GoogleFonts.manrope(
                        color: isSelected || isTtsActive
                            ? theme.accent
                            : theme.textSecondary.withValues(alpha: 0.5),
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
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.6),
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
                          color: const Color(0xFFFF7043).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          verse.bookNumber <= 39 ? '↗NT' : 'AT',
                          style: TextStyle(
                            color: const Color(0xFFFF7043).withValues(alpha: 0.7),
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

  // ── Modo palabra: verso como Wrap de tokens tappables ──────────────────

  Widget _buildWordSelectionBody(List<StudyWordHighlight> wordHighlights) {
    // Misma tokenización que StudyWordHighlight para que los índices coincidan.
    final tokens =
        verse.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    return Semantics(
      label: 'Versículo ${verse.verse}. Modo subrayado de palabras.',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 3),
              child: Text(
                '${verse.verse}',
                style: GoogleFonts.manrope(
                  color: theme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (int i = 0; i < tokens.length; i++)
              _buildWordChip(i, tokens[i], wordHighlights),
          ],
        ),
      ),
    );
  }

  Widget _buildWordChip(
    int i,
    String word,
    List<StudyWordHighlight> wordHighlights,
  ) {
    final selected = selectedWords.contains(i);
    // Color de subrayado ya existente en esta palabra (el más reciente gana).
    StudyWordHighlight? cover;
    for (final h in wordHighlights) {
      if (h.overlapsWord(i)) {
        cover = (cover == null || h.createdAt.isAfter(cover.createdAt))
            ? h
            : cover;
      }
    }
    final existingColor = cover?.codeEnum.color;
    return GestureDetector(
      onTap: () => controller.toggleWord(i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? theme.accent.withValues(alpha: 0.30)
              : existingColor?.withValues(alpha: theme.isDark ? 0.32 : 0.28),
          borderRadius: BorderRadius.circular(5),
          border: selected
              ? Border.all(color: theme.accent, width: 1.2)
              : null,
        ),
        child: Text(
          word,
          style: GoogleFonts.lora(
            color: theme.textPrimary,
            fontSize: fontSize,
            height: 1.35,
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
    // Selección = subrayado punteado (estilo YouVersion): marca clara sin
    // tapar el color de resaltado ni entorpecer la lectura.
    final baseStyle = GoogleFonts.lora(
      color: textColor,
      fontSize: fontSize,
      height: 1.8,
      backgroundColor: highlightBg,
      decoration: isSelected ? TextDecoration.underline : TextDecoration.none,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: theme.textSecondary.withValues(alpha: 0.75),
      decorationThickness: 1.5,
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
              backgroundColor: color.withValues(alpha: theme.isDark ? 0.32 : 0.28),
            ),
          ),
        );
      }
      wordIndex++;
    }
    return spans;
  }
}
