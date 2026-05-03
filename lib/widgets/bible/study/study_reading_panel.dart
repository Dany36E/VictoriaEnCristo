import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_verse.dart';
import '../../../models/bible/study_word_highlight.dart';
import '../../../services/bible/bible_user_data_service.dart';
import '../../../services/bible/study_mode_service.dart';
import '../../../theme/bible_reader_theme.dart';

/// Panel izquierdo (split) o tab de lectura del Modo Estudio.
///
/// Renderiza el capítulo con selección palabra-por-palabra:
///   - Tap en una palabra → se añade/quita al rango de selección.
///   - La barra inferior aparece cuando hay selección y permite aplicar
///     color (Rojo/Verde/Azul/Amarillo) o limpiar.
///   - Cada palabra muestra su color de subrayado actual (si lo tiene)
///     consultando `StudyModeService.highlightsForVerse(...)`.
class StudyReadingPanel extends StatefulWidget {
  final BibleReaderThemeData theme;
  final List<BibleVerse> verses;
  final int bookNumber;
  final int chapter;

  const StudyReadingPanel({
    super.key,
    required this.theme,
    required this.verses,
    required this.bookNumber,
    required this.chapter,
  });

  @override
  State<StudyReadingPanel> createState() => _StudyReadingPanelState();
}

class _StudyReadingPanelState extends State<StudyReadingPanel> {
  /// Versículo activo en selección (sólo se permite seleccionar dentro de un
  /// versículo a la vez para mantener la semántica de subrayado por verso).
  int? _activeVerse;

  /// Índices [start, end) de palabras seleccionadas en `_activeVerse`.
  int? _startWord;
  int? _endWord; // exclusive

  void _toggleWord(int verseNumber, int wordIndex) {
    setState(() {
      if (_activeVerse != verseNumber) {
        _activeVerse = verseNumber;
        _startWord = wordIndex;
        _endWord = wordIndex + 1;
        return;
      }
      // mismo versículo: extender o reducir rango contiguo
      if (_startWord == null || _endWord == null) {
        _startWord = wordIndex;
        _endWord = wordIndex + 1;
        return;
      }
      if (wordIndex < _startWord!) {
        _startWord = wordIndex;
      } else if (wordIndex >= _endWord!) {
        _endWord = wordIndex + 1;
      } else {
        // dentro del rango: si es el extremo, lo recorta; si no, no hace nada
        if (wordIndex == _startWord) {
          _startWord = _startWord! + 1;
        } else if (wordIndex == _endWord! - 1) {
          _endWord = _endWord! - 1;
        }
        if (_startWord! >= _endWord!) {
          _clearSelection();
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _activeVerse = null;
      _startWord = null;
      _endWord = null;
    });
  }

  Future<void> _applyColor(StudyHighlightCode code) async {
    if (_activeVerse == null || _startWord == null || _endWord == null) return;
    HapticFeedback.selectionClick();
    final verse = _activeVerse!;
    final s = _startWord!;
    final e = _endWord!;
    _clearSelection();
    await StudyModeService.I.addHighlight(
      bookNumber: widget.bookNumber,
      chapter: widget.chapter,
      verse: verse,
      startWord: s,
      endWord: e,
      code: code,
    );
  }

  Future<void> _clearVerse() async {
    if (_activeVerse == null) return;
    final verse = _activeVerse!;
    _clearSelection();
    await StudyModeService.I
        .clearVerseHighlights(widget.bookNumber, widget.chapter, verse);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return ValueListenableBuilder<List<StudyWordHighlight>>(
      valueListenable: StudyModeService.I.highlightsNotifier,
      builder: (_, allHighlights, _) {
        return ValueListenableBuilder<double>(
          valueListenable: BibleUserDataService.I.fontSizeNotifier,
          builder: (_, fontSize, _) {
            return Stack(
              children: [
                ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  itemCount: widget.verses.length,
                  itemBuilder: (_, i) {
                    final v = widget.verses[i];
                    final highlights = allHighlights
                        .where((h) =>
                            h.bookNumber == widget.bookNumber &&
                            h.chapter == widget.chapter &&
                            h.verse == v.verse)
                        .toList();
                    return _VerseRow(
                      verse: v,
                      theme: t,
                      fontSize: fontSize,
                      highlights: highlights,
                      activeVerse: _activeVerse,
                      startWord: _startWord,
                      endWord: _endWord,
                      onTapWord: (idx) => _toggleWord(v.verse, idx),
                    );
                  },
                ),
                if (_activeVerse != null && _startWord != null && _endWord != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: _ColorToolbar(
                      theme: t,
                      onPick: _applyColor,
                      onClear: _clearVerse,
                      onCancel: _clearSelection,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _VerseRow extends StatelessWidget {
  final BibleVerse verse;
  final BibleReaderThemeData theme;
  final double fontSize;
  final List<StudyWordHighlight> highlights;
  final int? activeVerse;
  final int? startWord;
  final int? endWord;
  final ValueChanged<int> onTapWord;

  const _VerseRow({
    required this.verse,
    required this.theme,
    required this.fontSize,
    required this.highlights,
    required this.activeVerse,
    required this.startWord,
    required this.endWord,
    required this.onTapWord,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final tokens = verse.text.split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final isSelectingHere = activeVerse == verse.verse;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, top: 2),
            child: Text(
              '${verse.verse}',
              style: GoogleFonts.cinzel(
                color: t.accent,
                fontSize: fontSize * 0.65,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (int i = 0; i < tokens.length; i++)
            _WordChip(
              text: tokens[i],
              theme: t,
              fontSize: fontSize,
              color: _colorForWord(i),
              selected: isSelectingHere &&
                  startWord != null &&
                  endWord != null &&
                  i >= startWord! &&
                  i < endWord!,
              onTap: () => onTapWord(i),
            ),
        ],
      ),
    );
  }

  Color? _colorForWord(int wordIndex) {
    StudyWordHighlight? hit;
    for (final h in highlights) {
      if (h.overlapsWord(wordIndex)) {
        hit = h;
        break; // primer match (en colisión, el más reciente queda al final;
        // bastará para Fase 1)
      }
    }
    return hit?.codeEnum.color;
  }
}

class _WordChip extends StatelessWidget {
  final String text;
  final BibleReaderThemeData theme;
  final double fontSize;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _WordChip({
    required this.text,
    required this.theme,
    required this.fontSize,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final bg = selected
        ? t.accent.withOpacity(0.35)
        : (color != null ? color!.withOpacity(0.35) : Colors.transparent);
    final border = selected
        ? Border.all(color: t.accent, width: 1)
        : null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: border,
        ),
        child: Text(
          '$text ',
          style: GoogleFonts.lora(
            color: t.textPrimary,
            fontSize: fontSize,
            height: 1.55,
          ),
        ),
      ),
    );
  }
}

class _ColorToolbar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final void Function(StudyHighlightCode) onPick;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  const _ColorToolbar({
    required this.theme,
    required this.onPick,
    required this.onClear,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(28),
      color: t.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: t.textSecondary.withOpacity(0.12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final code in StudyHighlightCode.values)
              _ColorButton(
                color: code.color,
                label: code.label,
                onTap: () => onPick(code),
              ),
            Container(
              width: 1,
              height: 24,
              color: t.textSecondary.withOpacity(0.15),
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            IconButton(
              tooltip: 'Borrar marcas del versículo',
              icon: Icon(Icons.clear_all,
                  color: t.textSecondary, size: 22),
              onPressed: onClear,
            ),
            IconButton(
              tooltip: 'Cancelar selección',
              icon: Icon(Icons.close,
                  color: t.textSecondary, size: 20),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ColorButton({
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
