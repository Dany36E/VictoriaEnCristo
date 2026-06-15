import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_verse.dart';
import '../../../models/bible/bible_version.dart';
import '../../../models/bible/book_introduction.dart';
import '../../../models/bible/study_room.dart';
import '../../../models/bible/study_word_highlight.dart';
import '../../../services/bible/bible_user_data_service.dart';
import '../../../services/bible/book_intro_service.dart';
import '../../../services/bible/study_mode_service.dart';
import '../../../services/bible/study_room_service.dart';
import '../../../theme/bible_reader_theme.dart';
import '../reading_highlight_store.dart';
import '../verse_study_sheet.dart';
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

  /// Almacen de resaltados a usar. Si es null (Modo Estudio), se usa el almacen
  /// global [StudyModeService]. Si se provee (Modo Predicacion), los resaltados
  /// son por apunte e independientes del Modo Estudio.
  final ReadingHighlightStore? highlightStore;

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
    this.highlightStore,
  });

  @override
  State<StudyReadingPanel> createState() => _StudyReadingPanelState();
}

class _StudyReadingPanelState extends State<StudyReadingPanel> {
  /// Versículo activo en selección (sólo se permite seleccionar dentro de un
  /// versículo a la vez para mantener la semántica de subrayado por verso).
  String? _activeVersionId;
  int? _activeBookNumber;
  int? _activeChapter;
  int? _activeVerse;

  /// Índices [start, end) de palabras seleccionadas en `_activeVerse`.
  int? _startWord;
  int? _endWord; // exclusive

  void _toggleWord(String versionId, int bookNumber, int chapter, int verseNumber, int wordIndex) {
    setState(() {
      if (_activeVersionId != versionId ||
          _activeBookNumber != bookNumber ||
          _activeChapter != chapter ||
          _activeVerse != verseNumber) {
        _activeVersionId = versionId;
        _activeBookNumber = bookNumber;
        _activeChapter = chapter;
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
      _activeBookNumber = null;
      _activeChapter = null;
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
    final bookNumber = _activeBookNumber!;
    final chapter = _activeChapter!;
    final verse = _activeVerse!;
    final s = _startWord!;
    final e = _endWord!;
    _clearSelection();
    final store = widget.highlightStore;
    if (store != null) {
      await store.addHighlight(
        versionId: versionId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        startWord: s,
        endWord: e,
        code: code,
      );
    } else {
      await StudyModeService.I.addHighlight(
        versionId: versionId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        startWord: s,
        endWord: e,
        code: code,
      );
    }
  }

  Future<void> _clearSelectedWords() async {
    if (_activeVersionId == null || _activeVerse == null) return;
    final versionId = _activeVersionId!;
    final bookNumber = _activeBookNumber!;
    final chapter = _activeChapter!;
    final verse = _activeVerse!;
    final s = _startWord;
    final e = _endWord;
    if (s == null || e == null) return;
    _clearSelection();
    final store = widget.highlightStore;
    if (store != null) {
      await store.clearRange(
        versionId: versionId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        startWord: s,
        endWord: e,
      );
    } else {
      await StudyModeService.I.clearHighlightRange(
        versionId: versionId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        startWord: s,
        endWord: e,
      );
    }
  }

  Future<void> _undo() =>
      widget.highlightStore?.undo() ?? StudyModeService.I.undoHighlightChange();

  Future<void> _redo() =>
      widget.highlightStore?.redo() ?? StudyModeService.I.redoHighlightChange();

  void _openVerseHelp(BibleVerse verse) {
    HapticFeedback.selectionClick();
    if (_activeVersionId != null || _activeVerse != null) {
      setState(() {
        _activeVersionId = null;
        _activeBookNumber = null;
        _activeChapter = null;
        _activeVerse = null;
        _startWord = null;
        _endWord = null;
      });
    }
    VerseStudySheet.show(context, verse, initialTab: 3);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return ValueListenableBuilder<StudyRoom?>(
      valueListenable: StudyRoomService.I.currentRoomNotifier,
      builder: (_, room, _) {
        return ValueListenableBuilder<List<StudyWordHighlight>>(
          valueListenable:
              widget.highlightStore?.highlightsListenable ??
              StudyModeService.I.highlightsNotifier,
          builder: (_, personalHighlights, _) {
            return ValueListenableBuilder<List<StudyWordHighlight>>(
              valueListenable: StudyRoomService.I.roomHighlightsNotifier,
              builder: (_, roomHighlights, _) {
                final allHighlights = widget.highlightStore != null
                    ? personalHighlights
                    : _effectiveHighlights(
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
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ReadingControlsRow(
                                    theme: t,
                                    onShowLegend: () => _openLegendSheet(t),
                                    onUndo: _undo,
                                    onRedo: _redo,
                                    canUndo:
                                        widget.highlightStore?.canUndoListenable ??
                                        StudyModeService.I.canUndoHighlightsNotifier,
                                    canRedo:
                                        widget.highlightStore?.canRedoListenable ??
                                        StudyModeService.I.canRedoHighlightsNotifier,
                                  ),
                                  _ChapterContextStrip(
                                    theme: t,
                                    bookNumber: widget.bookNumber,
                                    chapter: widget.chapter,
                                  ),
                                ],
                              );
                            }
                            final v = widget.verses[i - 1];
                            final secondary = widget.showSecondary ? _secondaryForVerse(v) : null;
                            final showPassageHeader =
                                i == 1 || _isNewPassage(widget.verses[i - 2], v);
                            final primaryHighlights = allHighlights
                                .where(
                                  (h) =>
                                      h.versionId == widget.primaryVersion.id &&
                                      h.bookNumber == v.bookNumber &&
                                      h.chapter == v.chapter &&
                                      h.verse == v.verse,
                                )
                                .toList();
                            final secondaryHighlights = allHighlights
                                .where(
                                  (h) =>
                                      h.versionId == widget.secondaryVersion.id &&
                                      h.bookNumber == v.bookNumber &&
                                      h.chapter == v.chapter &&
                                      h.verse == v.verse,
                                )
                                .toList();
                            final verseRow = _VerseComparisonRow(
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
                              activeBookNumber: _activeBookNumber,
                              activeChapter: _activeChapter,
                              activeVerse: _activeVerse,
                              startWord: _startWord,
                              endWord: _endWord,
                              onTapPrimaryWord: (idx) => _toggleWord(
                                widget.primaryVersion.id,
                                v.bookNumber,
                                v.chapter,
                                v.verse,
                                idx,
                              ),
                              onOpenVerseHelp: () => _openVerseHelp(v),
                              onTapSecondaryWord: secondary == null
                                  ? null
                                  : (idx) => _toggleWord(
                                      widget.secondaryVersion.id,
                                      secondary.bookNumber,
                                      secondary.chapter,
                                      secondary.verse,
                                      idx,
                                    ),
                            );
                            if (!showPassageHeader) return verseRow;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _PassageHeader(verse: v, theme: t),
                                verseRow,
                              ],
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

  BibleVerse? _secondaryForVerse(BibleVerse primary) {
    for (final verse in widget.secondaryVerses) {
      if (verse.bookNumber == primary.bookNumber &&
          verse.chapter == primary.chapter &&
          verse.verse == primary.verse) {
        return verse;
      }
    }
    return null;
  }

  bool _isNewPassage(BibleVerse previous, BibleVerse current) {
    return previous.bookNumber != current.bookNumber || previous.chapter != current.chapter;
  }

  Future<void> _openLegendSheet(BibleReaderThemeData t) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LegendSheet(theme: t),
    );
  }
}

class _PassageHeader extends StatelessWidget {
  final BibleVerse verse;
  final BibleReaderThemeData theme;

  const _PassageHeader({required this.verse, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(
        children: [
          Icon(Icons.menu_book_outlined, size: 14, color: t.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${verse.bookName} ${verse.chapter}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: t.textSecondary.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
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
  final int? activeBookNumber;
  final int? activeChapter;
  final int? activeVerse;
  final int? startWord;
  final int? endWord;
  final ValueChanged<int> onTapPrimaryWord;
  final VoidCallback onOpenVerseHelp;
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
    required this.activeBookNumber,
    required this.activeChapter,
    required this.activeVerse,
    required this.startWord,
    required this.endWord,
    required this.onTapPrimaryWord,
    required this.onOpenVerseHelp,
    required this.onTapSecondaryWord,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: t.isDark ? Colors.white.withValues(alpha: 0.025) : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.textSecondary.withValues(alpha: 0.08)),
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
            activeVerse:
                activeVersionId == primaryVersion.id &&
                    activeBookNumber == primary.bookNumber &&
                    activeChapter == primary.chapter
                ? activeVerse
                : null,
            startWord: startWord,
            endWord: endWord,
            onTapWord: onTapPrimaryWord,
            onOpenVerseHelp: onOpenVerseHelp,
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
                activeVerse:
                    activeVersionId == secondaryVersion.id &&
                        activeBookNumber == secondary!.bookNumber &&
                        activeChapter == secondary!.chapter
                    ? activeVerse
                    : null,
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
        color: muted ? t.textSecondary.withValues(alpha: 0.55) : t.accent,
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
          color: t.textPrimary.withValues(alpha: 0.78),
          fontSize: fontSize * 0.92,
          height: 1.55,
        ),
        children: [
          TextSpan(
            text: '$verseNumber ',
            style: GoogleFonts.cinzel(
              color: t.textSecondary.withValues(alpha: 0.7),
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
  final VoidCallback? onOpenVerseHelp;
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
    this.onOpenVerseHelp,
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
                color: muted ? t.textSecondary.withValues(alpha: 0.7) : t.accent,
                fontSize: fontSize * 0.65,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!muted && onOpenVerseHelp != null)
            _VerseHelpButton(theme: t, onTap: onOpenVerseHelp!),
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

class _VerseHelpButton extends StatelessWidget {
  final BibleReaderThemeData theme;
  final VoidCallback onTap;

  const _VerseHelpButton({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Tooltip(
      message: 'Ayuda del versículo',
      child: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 2),
        child: InkResponse(
          radius: 17,
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: t.accent.withValues(alpha: 0.24)),
              ),
              child: Icon(Icons.school_outlined, size: 16, color: t.accent),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterContextStrip extends StatefulWidget {
  final BibleReaderThemeData theme;
  final int bookNumber;
  final int chapter;

  const _ChapterContextStrip({
    required this.theme,
    required this.bookNumber,
    required this.chapter,
  });

  @override
  State<_ChapterContextStrip> createState() => _ChapterContextStripState();
}

class _ChapterContextStripState extends State<_ChapterContextStrip> {
  late Future<BookIntroduction?> _introFuture;

  @override
  void initState() {
    super.initState();
    _introFuture = BookIntroService.instance.getIntroduction(widget.bookNumber);
  }

  @override
  void didUpdateWidget(covariant _ChapterContextStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookNumber != widget.bookNumber) {
      _introFuture = BookIntroService.instance.getIntroduction(widget.bookNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BookIntroduction?>(
      future: _introFuture,
      builder: (context, snapshot) {
        final intro = snapshot.data;
        if (intro == null) return const SizedBox.shrink();
        final author = intro.author.trim();
        final date = intro.writtenDate.trim();
        final chapterIntro = intro.chapterIntros[widget.chapter]?.trim() ?? '';
        final hasDetails =
            intro.authorDetails.trim().isNotEmpty ||
            intro.period.trim().isNotEmpty ||
            intro.historicalContext.trim().isNotEmpty ||
            chapterIntro.isNotEmpty;
        if (author.isEmpty && date.isEmpty && !hasDetails) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            decoration: BoxDecoration(
              color: widget.theme.surface.withValues(alpha: widget.theme.isDark ? 0.72 : 0.62),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.theme.textSecondary.withValues(alpha: 0.10)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (author.isNotEmpty)
                        _ContextChip(
                          theme: widget.theme,
                          icon: Icons.edit_note_outlined,
                          label: 'Autor: $author',
                        ),
                      if (date.isNotEmpty)
                        _ContextChip(
                          theme: widget.theme,
                          icon: Icons.calendar_today_outlined,
                          label: 'Fecha: $date',
                        ),
                    ],
                  ),
                ),
                if (hasDetails)
                  IconButton(
                    tooltip: 'Contexto del capítulo',
                    icon: Icon(Icons.info_outline, color: widget.theme.accent, size: 19),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 36, height: 34),
                    padding: EdgeInsets.zero,
                    onPressed: () => _openContextSheet(context, intro, chapterIntro),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openContextSheet(BuildContext context, BookIntroduction intro, String chapterIntro) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, scrollController) => _ChapterContextSheet(
          theme: widget.theme,
          intro: intro,
          chapter: widget.chapter,
          chapterIntro: chapterIntro,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icon;
  final String label;

  const _ContextChip({required this.theme, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: theme.textSecondary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.textSecondary.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: theme.textSecondary.withValues(alpha: 0.82)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: theme.textPrimary.withValues(alpha: 0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterContextSheet extends StatelessWidget {
  final BibleReaderThemeData theme;
  final BookIntroduction intro;
  final int chapter;
  final String chapterIntro;
  final ScrollController scrollController;

  const _ChapterContextSheet({
    required this.theme,
    required this.intro,
    required this.chapter,
    required this.chapterIntro,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final details = <Widget>[
      if (intro.author.trim().isNotEmpty)
        _ContextDetail(theme: theme, title: 'Autor', body: intro.author.trim()),
      if (intro.authorDetails.trim().isNotEmpty)
        _ContextDetail(theme: theme, title: 'Sobre el autor', body: intro.authorDetails.trim()),
      if (intro.writtenDate.trim().isNotEmpty)
        _ContextDetail(theme: theme, title: 'Fecha', body: intro.writtenDate.trim()),
      if (intro.period.trim().isNotEmpty)
        _ContextDetail(theme: theme, title: 'Periodo', body: intro.period.trim()),
      if (chapterIntro.isNotEmpty)
        _ContextDetail(theme: theme, title: 'Capítulo $chapter', body: chapterIntro),
      if (intro.historicalContext.trim().isNotEmpty)
        _ContextDetail(
          theme: theme,
          title: 'Contexto histórico',
          body: intro.historicalContext.trim(),
        ),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.textSecondary.withValues(alpha: 0.12)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: theme.textSecondary.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.accent, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${intro.name} $chapter',
                    style: GoogleFonts.manrope(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...details,
          ],
        ),
      ),
    );
  }
}

class _ContextDetail extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String title;
  final String body;

  const _ContextDetail({required this.theme, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              color: theme.accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: GoogleFonts.manrope(
              color: theme.textPrimary.withValues(alpha: 0.84),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
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
        ? t.accent.withValues(alpha: 0.35)
        : ownHighlights.isNotEmpty
        ? ownHighlights.last.color.withValues(alpha: 0.20)
        : friendHighlights.isNotEmpty
        ? friendHighlights.last.color.withValues(alpha: 0.10)
        : Colors.transparent;
    final border = selected
        ? Border.all(color: t.accent, width: 1)
        : friendHighlights.isNotEmpty
        ? Border.all(color: friendHighlights.last.color.withValues(alpha: 0.65), width: 0.8)
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
                color: muted ? t.textPrimary.withValues(alpha: 0.78) : t.textPrimary,
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
                              color: highlight.color.withValues(alpha: highlight.isMine ? 0.9 : 0.45),
                              borderRadius: BorderRadius.circular(2),
                              border: highlight.isMine
                                  ? null
                                  : Border.all(color: highlight.color.withValues(alpha: 0.8), width: 0.6),
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
          border: Border.all(color: t.textSecondary.withValues(alpha: 0.12)),
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
              color: t.textSecondary.withValues(alpha: 0.15),
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
  final ValueListenable<bool> canUndo;
  final ValueListenable<bool> canRedo;

  const _ReadingControlsRow({
    required this.theme,
    required this.onShowLegend,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
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
                side: BorderSide(color: t.textSecondary.withValues(alpha: 0.14)),
              ),
            ),
          ),
          const Spacer(),
          _UndoRedoBar(
            theme: t,
            onUndo: onUndo,
            onRedo: onRedo,
            canUndo: canUndo,
            canRedo: canRedo,
          ),
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
    final stroke = t.textPrimary.withValues(alpha: t.isDark ? 0.76 : 0.64);
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
              color: t.textPrimary.withValues(alpha: t.isDark ? 0.08 : 0.05),
              shape: BoxShape.circle,
              border: Border.all(color: stroke, width: 1.6),
              boxShadow: [BoxShadow(color: stroke.withValues(alpha: 0.16), blurRadius: 6)],
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
  final ValueListenable<bool> canUndo;
  final ValueListenable<bool> canRedo;

  const _UndoRedoBar({
    required this.theme,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Material(
      color: t.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.textSecondary.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: canUndo,
              builder: (_, enabled, _) => IconButton(
                tooltip: 'Deshacer',
                icon: const Icon(Icons.undo, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 34),
                color: enabled ? t.accent : t.textSecondary.withValues(alpha: 0.35),
                onPressed: enabled ? onUndo : null,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: canRedo,
              builder: (_, enabled, _) => IconButton(
                tooltip: 'Rehacer',
                icon: const Icon(Icons.redo, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 34),
                color: enabled ? t.accent : t.textSecondary.withValues(alpha: 0.35),
                onPressed: enabled ? onRedo : null,
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
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
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
          border: Border.all(color: t.textSecondary.withValues(alpha: 0.1)),
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
