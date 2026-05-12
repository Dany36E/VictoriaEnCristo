import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_verse.dart';
import '../../../models/bible/bible_version.dart';
import '../../../models/bible/study_room.dart';
import '../../../models/bible/study_word_highlight.dart';
import '../../../services/bible/bible_user_data_service.dart';
import '../../../services/bible/study_mode_service.dart';
import '../../../services/bible/study_room_service.dart';
import '../../../theme/bible_reader_theme.dart';
import 'study_color_legend.dart';

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
  final List<BibleVerse> secondaryVerses;
  final BibleVersion primaryVersion;
  final BibleVersion secondaryVersion;
  final int bookNumber;
  final int chapter;
  final bool showSecondary;

  const StudyReadingPanel({
    super.key,
    required this.theme,
    required this.verses,
    required this.secondaryVerses,
    required this.primaryVersion,
    required this.secondaryVersion,
    required this.bookNumber,
    required this.chapter,
    this.showSecondary = true,
  });

  @override
  State<StudyReadingPanel> createState() => _StudyReadingPanelState();
}

class _StudyReadingPanelState extends State<StudyReadingPanel> {
  /// Versículo activo en selección (sólo se permite seleccionar dentro de un
  /// versículo a la vez para mantener la semántica de subrayado por verso).
  String? _activeVersionId;
  int? _activeVerse;

  /// Índices [start, end) de palabras seleccionadas en `_activeVerse`.
  int? _startWord;
  int? _endWord; // exclusive

  void _toggleWord(String versionId, int verseNumber, int wordIndex) {
    setState(() {
      if (_activeVersionId != versionId || _activeVerse != verseNumber) {
        _activeVersionId = versionId;
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
      _activeVersionId = null;
      _activeVerse = null;
      _startWord = null;
      _endWord = null;
    });
  }

  Future<void> _applyColor(StudyHighlightCode code) async {
    if (_activeVersionId == null ||
        _activeVerse == null ||
        _startWord == null ||
        _endWord == null) {
      return;
    }
    HapticFeedback.selectionClick();
    final versionId = _activeVersionId!;
    final verse = _activeVerse!;
    final s = _startWord!;
    final e = _endWord!;
    _clearSelection();
    await StudyModeService.I.addHighlight(
      versionId: versionId,
      bookNumber: widget.bookNumber,
      chapter: widget.chapter,
      verse: verse,
      startWord: s,
      endWord: e,
      code: code,
    );
  }

  Future<void> _clearSelectedWords() async {
    if (_activeVersionId == null || _activeVerse == null) return;
    final versionId = _activeVersionId!;
    final verse = _activeVerse!;
    final s = _startWord;
    final e = _endWord;
    if (s == null || e == null) return;
    _clearSelection();
    await StudyModeService.I.clearHighlightRange(
      versionId: versionId,
      bookNumber: widget.bookNumber,
      chapter: widget.chapter,
      verse: verse,
      startWord: s,
      endWord: e,
    );
  }

  Future<void> _undo() => StudyModeService.I.undoHighlightChange();

  Future<void> _redo() => StudyModeService.I.redoHighlightChange();

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return ValueListenableBuilder<StudyRoom?>(
      valueListenable: StudyRoomService.I.currentRoomNotifier,
      builder: (_, room, _) {
        return ValueListenableBuilder<List<StudyWordHighlight>>(
          valueListenable: StudyModeService.I.highlightsNotifier,
          builder: (_, personalHighlights, _) {
            return ValueListenableBuilder<List<StudyWordHighlight>>(
              valueListenable: StudyRoomService.I.roomHighlightsNotifier,
              builder: (_, roomHighlights, _) {
                final allHighlights = _effectiveHighlights(
                  personalHighlights: personalHighlights,
                  roomHighlights: roomHighlights,
                  inRoom: room != null,
                );
                return ValueListenableBuilder<double>(
                  valueListenable: BibleUserDataService.I.fontSizeNotifier,
                  builder: (_, fontSize, _) {
                    return Stack(
                      children: [
                        ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          itemCount: widget.verses.length + 1,
                          itemBuilder: (_, i) {
                            if (i == 0) {
                              return _ReadingControlsRow(
                                theme: t,
                                onShowLegend: () => _openLegendSheet(t),
                                onUndo: _undo,
                                onRedo: _redo,
                              );
                            }
                            final v = widget.verses[i - 1];
                            final secondary = widget.showSecondary
                                ? _secondaryForVerse(v.verse)
                                : null;
                            final primaryHighlights = allHighlights
                                .where(
                                  (h) =>
                                      h.versionId == widget.primaryVersion.id &&
                                      h.bookNumber == widget.bookNumber &&
                                      h.chapter == widget.chapter &&
                                      h.verse == v.verse,
                                )
                                .toList();
                            final secondaryHighlights = allHighlights
                                .where(
                                  (h) =>
                                      h.versionId == widget.secondaryVersion.id &&
                                      h.bookNumber == widget.bookNumber &&
                                      h.chapter == widget.chapter &&
                                      h.verse == v.verse,
                                )
                                .toList();
                            return _VerseComparisonRow(
                              primary: v,
                              secondary: secondary,
                              primaryVersion: widget.primaryVersion,
                              secondaryVersion: widget.secondaryVersion,
                              showSecondary: widget.showSecondary,
                              theme: t,
                              fontSize: fontSize,
                              primaryHighlights: primaryHighlights,
                              secondaryHighlights: secondaryHighlights,
                              activeVersionId: _activeVersionId,
                              activeVerse: _activeVerse,
                              startWord: _startWord,
                              endWord: _endWord,
                              onTapPrimaryWord: (idx) =>
                                  _toggleWord(widget.primaryVersion.id, v.verse, idx),
                              onTapSecondaryWord: secondary == null
                                  ? null
                                  : (idx) => _toggleWord(
                                      widget.secondaryVersion.id,
                                      secondary.verse,
                                      idx,
                                    ),
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
                              onClear: _clearSelectedWords,
                              onCancel: _clearSelection,
                            ),
                          ),
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

  List<StudyWordHighlight> _effectiveHighlights({
    required List<StudyWordHighlight> personalHighlights,
    required List<StudyWordHighlight> roomHighlights,
    required bool inRoom,
  }) {
    // El Modo Estudio en sala es colaborativo a nivel de lectura/swap, pero el
    // subrayado y las respuestas se mantienen privados durante la sesión. Cada
    // usuario solo ve su propia tinta; los resaltados de los compañeros se
    // consolidan únicamente al exportar el PDF final.
    return personalHighlights;
  }

  BibleVerse? _secondaryForVerse(int verseNumber) {
    for (final verse in widget.secondaryVerses) {
      if (verse.verse == verseNumber) return verse;
    }
    return null;
  }

  Future<void> _openLegendSheet(BibleReaderThemeData t) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LegendSheet(theme: t),
    );
  }
}

class _VerseComparisonRow extends StatelessWidget {
  final BibleVerse primary;
  final BibleVerse? secondary;
  final BibleVersion primaryVersion;
  final BibleVersion secondaryVersion;
  final bool showSecondary;
  final BibleReaderThemeData theme;
  final double fontSize;
  final List<StudyWordHighlight> primaryHighlights;
  final List<StudyWordHighlight> secondaryHighlights;
  final String? activeVersionId;
  final int? activeVerse;
  final int? startWord;
  final int? endWord;
  final ValueChanged<int> onTapPrimaryWord;
  final ValueChanged<int>? onTapSecondaryWord;

  const _VerseComparisonRow({
    required this.primary,
    required this.secondary,
    required this.primaryVersion,
    required this.secondaryVersion,
    required this.showSecondary,
    required this.theme,
    required this.fontSize,
    required this.primaryHighlights,
    required this.secondaryHighlights,
    required this.activeVersionId,
    required this.activeVerse,
    required this.startWord,
    required this.endWord,
    required this.onTapPrimaryWord,
    required this.onTapSecondaryWord,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: t.isDark ? Colors.white.withOpacity(0.025) : Colors.black.withOpacity(0.025),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.textSecondary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VersionLabel(version: primaryVersion, theme: t),
          _VerseRow(
            verse: primary,
            theme: t,
            fontSize: fontSize,
            highlights: primaryHighlights,
            activeVerse: activeVersionId == primaryVersion.id ? activeVerse : null,
            startWord: startWord,
            endWord: endWord,
            onTapWord: onTapPrimaryWord,
          ),
          if (showSecondary) ...[
            const SizedBox(height: 8),
            _VersionLabel(version: secondaryVersion, theme: t, muted: true),
            const SizedBox(height: 4),
            if (secondary == null)
              _SecondaryVerseText(
                verseNumber: primary.verse,
                text: 'Versículo no disponible en esta versión.',
                theme: t,
                fontSize: fontSize,
              )
            else
              _VerseRow(
                verse: secondary!,
                theme: t,
                fontSize: fontSize * 0.92,
                highlights: secondaryHighlights,
                activeVerse: activeVersionId == secondaryVersion.id ? activeVerse : null,
                startWord: startWord,
                endWord: endWord,
                onTapWord: onTapSecondaryWord!,
                muted: true,
              ),
          ],
        ],
      ),
    );
  }
}

class _VersionLabel extends StatelessWidget {
  final BibleVersion version;
  final BibleReaderThemeData theme;
  final bool muted;

  const _VersionLabel({required this.version, required this.theme, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Text(
      version.shortName,
      style: GoogleFonts.manrope(
        color: muted ? t.textSecondary.withOpacity(0.55) : t.accent,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _SecondaryVerseText extends StatelessWidget {
  final int verseNumber;
  final String text;
  final BibleReaderThemeData theme;
  final double fontSize;

  const _SecondaryVerseText({
    required this.verseNumber,
    required this.text,
    required this.theme,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return RichText(
      text: TextSpan(
        style: GoogleFonts.lora(
          color: t.textPrimary.withOpacity(0.78),
          fontSize: fontSize * 0.92,
          height: 1.55,
        ),
        children: [
          TextSpan(
            text: '$verseNumber ',
            style: GoogleFonts.cinzel(
              color: t.textSecondary.withOpacity(0.7),
              fontSize: fontSize * 0.62,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
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
  final bool muted;

  const _VerseRow({
    required this.verse,
    required this.theme,
    required this.fontSize,
    required this.highlights,
    required this.activeVerse,
    required this.startWord,
    required this.endWord,
    required this.onTapWord,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final tokens = verse.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final isSelectingHere = activeVerse == verse.verse;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

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
                color: muted ? t.textSecondary.withOpacity(0.7) : t.accent,
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
              highlights: _highlightsForWord(i, currentUid),
              muted: muted,
              selected:
                  isSelectingHere &&
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

  List<_WordHighlightPaint> _highlightsForWord(int wordIndex, String? currentUid) {
    final paints = <_WordHighlightPaint>[];
    for (final h in highlights) {
      if (h.overlapsWord(wordIndex)) {
        final isMine = h.ownerUid == null || h.ownerUid == currentUid;
        final owner = isMine
            ? 'Tú'
            : (h.ownerName?.trim().isNotEmpty == true ? h.ownerName! : 'Compañero');
        paints.add(_WordHighlightPaint(color: h.codeEnum.color, isMine: isMine, owner: owner));
      }
    }
    return paints;
  }
}

class _WordHighlightPaint {
  final Color color;
  final bool isMine;
  final String owner;

  const _WordHighlightPaint({required this.color, required this.isMine, required this.owner});
}

class _WordChip extends StatelessWidget {
  final String text;
  final BibleReaderThemeData theme;
  final double fontSize;
  final List<_WordHighlightPaint> highlights;
  final bool muted;
  final bool selected;
  final VoidCallback onTap;

  const _WordChip({
    required this.text,
    required this.theme,
    required this.fontSize,
    required this.highlights,
    required this.muted,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final ownHighlights = highlights.where((highlight) => highlight.isMine).toList();
    final friendHighlights = highlights.where((highlight) => !highlight.isMine).toList();
    final bg = selected
        ? t.accent.withOpacity(0.35)
        : ownHighlights.isNotEmpty
        ? ownHighlights.last.color.withOpacity(0.20)
        : friendHighlights.isNotEmpty
        ? friendHighlights.last.color.withOpacity(0.10)
        : Colors.transparent;
    final border = selected
        ? Border.all(color: t.accent, width: 1)
        : friendHighlights.isNotEmpty
        ? Border.all(color: friendHighlights.last.color.withOpacity(0.65), width: 0.8)
        : null;
    final chip = GestureDetector(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$text ',
              style: GoogleFonts.lora(
                color: muted ? t.textPrimary.withOpacity(0.78) : t.textPrimary,
                fontSize: fontSize,
                height: 1.35,
              ),
            ),
            if (highlights.isNotEmpty)
              SizedBox(
                height: 4,
                width: (text.length * fontSize * 0.48).clamp(12.0, 80.0),
                child: Row(
                  children: [
                    for (final highlight in highlights)
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: highlight.isMine ? 3 : 2,
                            decoration: BoxDecoration(
                              color: highlight.color.withOpacity(highlight.isMine ? 0.9 : 0.45),
                              borderRadius: BorderRadius.circular(2),
                              border: highlight.isMine
                                  ? null
                                  : Border.all(color: highlight.color.withOpacity(0.8), width: 0.6),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    if (highlights.isEmpty) return chip;
    final owners = highlights.map((highlight) => highlight.owner).toSet().join(' / ');
    return Tooltip(message: 'Subrayado: $owners', child: chip);
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
          border: Border.all(color: t.textSecondary.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final code in StudyHighlightCode.values)
              _ColorButton(color: code.color, label: code.label, onTap: () => onPick(code)),
            _TransparentColorButton(theme: t, onTap: onClear),
            Container(
              width: 1,
              height: 24,
              color: t.textSecondary.withOpacity(0.15),
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            IconButton(
              tooltip: 'Cancelar selección',
              icon: Icon(Icons.close, color: t.textSecondary, size: 20),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingControlsRow extends StatelessWidget {
  final BibleReaderThemeData theme;
  final VoidCallback onShowLegend;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const _ReadingControlsRow({
    required this.theme,
    required this.onShowLegend,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onShowLegend,
            icon: Icon(Icons.palette_outlined, size: 16, color: t.accent),
            label: const Text('Leyenda'),
            style: TextButton.styleFrom(
              foregroundColor: t.textPrimary,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: t.textSecondary.withOpacity(0.14)),
              ),
            ),
          ),
          const Spacer(),
          _UndoRedoBar(theme: t, onUndo: onUndo, onRedo: onRedo),
        ],
      ),
    );
  }
}

class _TransparentColorButton extends StatelessWidget {
  final BibleReaderThemeData theme;
  final VoidCallback onTap;

  const _TransparentColorButton({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final stroke = t.textPrimary.withOpacity(t.isDark ? 0.76 : 0.64);
    return Tooltip(
      message: 'Borrar color seleccionado',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: t.textPrimary.withOpacity(t.isDark ? 0.08 : 0.05),
              shape: BoxShape.circle,
              border: Border.all(color: stroke, width: 1.6),
              boxShadow: [BoxShadow(color: stroke.withOpacity(0.16), blurRadius: 6)],
            ),
            child: CustomPaint(painter: _TransparentSwatchPainter(stroke)),
          ),
        ),
      ),
    );
  }
}

class _TransparentSwatchPainter extends CustomPainter {
  final Color color;

  const _TransparentSwatchPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UndoRedoBar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const _UndoRedoBar({required this.theme, required this.onUndo, required this.onRedo});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Material(
      color: t.surface.withOpacity(0.92),
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.textSecondary.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: StudyModeService.I.canUndoHighlightsNotifier,
              builder: (_, canUndo, _) => IconButton(
                tooltip: 'Deshacer',
                icon: const Icon(Icons.undo, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 34),
                color: canUndo ? t.accent : t.textSecondary.withOpacity(0.35),
                onPressed: canUndo ? onUndo : null,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: StudyModeService.I.canRedoHighlightsNotifier,
              builder: (_, canRedo, _) => IconButton(
                tooltip: 'Rehacer',
                icon: const Icon(Icons.redo, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 34),
                color: canRedo ? t.accent : t.textSecondary.withOpacity(0.35),
                onPressed: canRedo ? onRedo : null,
              ),
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

  const _ColorButton({required this.color, required this.label, required this.onTap});

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
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendSheet extends StatelessWidget {
  final BibleReaderThemeData theme;
  const _LegendSheet({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.textSecondary.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: t.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Leyenda de colores',
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            StudyColorLegend(theme: t),
          ],
        ),
      ),
    );
  }
}
