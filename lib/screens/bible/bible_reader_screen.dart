import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/highlight.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../widgets/bible/verse_actions_toolbar.dart';
import '../../widgets/bible/version_selector_sheet.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE READER SCREEN - Edición premium editorial
///
/// Principios:
///   - El texto es el diseño (UI casi invisible)
///   - Prosa continua (no lista de items)
///   - Header desaparece al scroll, reaparece al subir
///   - Toolbar flotante solo al seleccionar versículo
///   - Navegación por swipe horizontal
///   - Sin cards, sin bordes, sin separadores
/// ═══════════════════════════════════════════════════════════════════════════
class BibleReaderScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final BibleVersion version;

  const BibleReaderScreen({
    super.key,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.version,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  List<BibleVerse> _verses = [];
  bool _loading = true;
  late int _currentChapter;
  late BibleVersion _currentVersion;
  int _totalChapters = 1;
  final _scrollController = ScrollController();

  // UI state
  int? _selectedVerseIndex;
  double _headerOpacity = 1.0;
  double _lastScrollOffset = 0;
  bool _showTypography = false;

  // Book list for chapter selector
  List<BibleBook> _allBooks = [];

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _currentVersion = widget.version;
    _scrollController.addListener(_onScroll);
    _loadChapter();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;

    double newOpacity = _headerOpacity;
    if (delta > 0 && offset > 20) {
      newOpacity = (_headerOpacity - 0.08).clamp(0.0, 1.0);
    } else if (delta < -2) {
      newOpacity = (_headerOpacity + 0.12).clamp(0.0, 1.0);
    }

    if (newOpacity != _headerOpacity) {
      setState(() => _headerOpacity = newOpacity);
    }
  }

  Future<void> _loadChapter() async {
    setState(() {
      _loading = true;
      _selectedVerseIndex = null;
    });

    final books = await BibleParserService.I.getBooks(_currentVersion);
    _allBooks = books;
    final book = books.where((b) => b.number == widget.bookNumber).firstOrNull;
    if (book != null) _totalChapters = book.totalChapters;

    final verses = await BibleParserService.I.getChapter(
      version: _currentVersion,
      bookNumber: widget.bookNumber,
      chapter: _currentChapter,
    );

    if (mounted) {
      setState(() {
        _verses = verses;
        _loading = false;
        _headerOpacity = 1.0;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  void _goToChapter(int chapter) {
    if (chapter < 1 || chapter > _totalChapters) return;
    _currentChapter = chapter;
    _loadChapter();
  }

  void _goToBook(int bookNumber, String bookName, int chapter) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a1, a2) => BibleReaderScreen(
          bookNumber: bookNumber,
          bookName: bookName,
          chapter: chapter,
          version: _currentVersion,
        ),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (ctx, a, sa, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (context, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );

        SystemChrome.setSystemUIOverlayStyle(
          t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );

        return Scaffold(
          backgroundColor: t.background,
          body: GestureDetector(
            onTap: () {
              if (_selectedVerseIndex != null) {
                setState(() => _selectedVerseIndex = null);
              } else if (_showTypography) {
                setState(() => _showTypography = false);
              } else {
                setState(() =>
                    _headerOpacity = _headerOpacity > 0.5 ? 0.0 : 1.0);
              }
            },
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < -200) {
                _goToChapter(_currentChapter + 1);
              } else if (details.primaryVelocity! > 200) {
                _goToChapter(_currentChapter - 1);
              }
            },
            child: SafeArea(
              child: Stack(
                children: [
                  _loading
                      ? Center(
                          child: CircularProgressIndicator(
                              color: t.accent, strokeWidth: 1.5))
                      : _buildContent(t),

                  if (!_loading)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        ignoring: _headerOpacity < 0.1,
                        child: AnimatedOpacity(
                          opacity: _headerOpacity,
                          duration: const Duration(milliseconds: 100),
                          child: _buildHeader(t),
                        ),
                      ),
                    ),

                  if (_showTypography) _buildTypographyPanel(t),

                  if (_selectedVerseIndex != null && !_loading)
                    _buildToolbarOverlay(t),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader(BibleReaderThemeData t) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: t.background.withOpacity(0.95),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios,
                color: t.textSecondary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _showBookChapterSelector,
              child: Text(
                '${widget.bookName} $_currentChapter',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: t.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => showVersionSelectorSheet(
              context,
              onChanged: () {
                setState(() {
                  _currentVersion =
                      BibleUserDataService.I.preferredVersionNotifier.value;
                });
                _loadChapter();
              },
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                _currentVersion.shortName,
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.text_fields,
                color: t.textSecondary.withOpacity(0.6), size: 18),
            onPressed: () =>
                setState(() => _showTypography = !_showTypography),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CONTENT — Prosa continua
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildContent(BibleReaderThemeData t) {
    return ValueListenableBuilder<Map<String, Highlight>>(
      valueListenable: BibleUserDataService.I.highlightsNotifier,
      builder: (context, highlights, _) {
        return ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: BibleUserDataService.I.notesNotifier,
          builder: (context, notes, _) {
            return ValueListenableBuilder<double>(
              valueListenable: BibleUserDataService.I.fontSizeNotifier,
              builder: (context, fontSize, _) {
                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 56)),

                    // Chapter number ornament
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: 32, right: 32, bottom: 28),
                        child: Text(
                          '$_currentChapter',
                          style: GoogleFonts.manrope(
                            color: t.textSecondary.withOpacity(0.25),
                            fontSize: 64,
                            fontWeight: FontWeight.w200,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),

                    // Verses
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final verse = _verses[index];
                            final key = verse.uniqueKey;
                            final highlight = highlights[key];
                            final hasNote = notes.containsKey(key);
                            final isSelected =
                                _selectedVerseIndex == index;

                            return _buildVerseParagraph(
                              verse: verse,
                              index: index,
                              highlight: highlight,
                              hasNote: hasNote,
                              isSelected: isSelected,
                              fontSize: fontSize,
                              theme: t,
                            );
                          },
                          childCount: _verses.length,
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(child: _buildBottomNav(t)),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildVerseParagraph({
    required BibleVerse verse,
    required int index,
    required Highlight? highlight,
    required bool hasNote,
    required bool isSelected,
    required double fontSize,
    required BibleReaderThemeData theme,
  }) {
    final highlightBg =
        highlight != null ? theme.highlightOverlay(highlight.color) : null;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVerseIndex =
              _selectedVerseIndex == index ? null : index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration:
            isSelected ? BoxDecoration(color: theme.selectionBg) : null,
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
                      color: isSelected
                          ? theme.accent
                          : theme.textSecondary.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              TextSpan(
                text: verse.text,
                style: GoogleFonts.lora(
                  color: theme.textPrimary,
                  fontSize: fontSize,
                  height: 1.8,
                  backgroundColor: highlightBg,
                ),
              ),
              if (hasNote)
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(Icons.circle,
                        color: theme.accent, size: 5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BOTTOM CHAPTER NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBottomNav(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentChapter > 1)
            GestureDetector(
              onTap: () => _goToChapter(_currentChapter - 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left,
                      color: t.textSecondary.withOpacity(0.4), size: 18),
                  Text(
                    'Cap. ${_currentChapter - 1}',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox.shrink(),
          Text(
            '${widget.bookName} $_currentChapter',
            style: GoogleFonts.manrope(
              color: t.textSecondary.withOpacity(0.25),
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          if (_currentChapter < _totalChapters)
            GestureDetector(
              onTap: () => _goToChapter(_currentChapter + 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cap. ${_currentChapter + 1}',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: t.textSecondary.withOpacity(0.4), size: 18),
                ],
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FLOATING TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildToolbarOverlay(BibleReaderThemeData t) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: VerseActionsToolbar(
        verse: _verses[_selectedVerseIndex!],
        theme: t,
        onDismiss: () => setState(() => _selectedVerseIndex = null),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY PANEL
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTypographyPanel(BibleReaderThemeData t) {
    return Positioned(
      top: 44,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        color: t.surface.withOpacity(0.98),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: BibleUserDataService.I.fontSizeNotifier,
              builder: (context, size, _) {
                return Row(
                  children: [
                    Text('A',
                        style: GoogleFonts.lora(
                            color: t.textSecondary, fontSize: 14)),
                    Expanded(
                      child: Slider(
                        value: size,
                        min: 14,
                        max: 28,
                        divisions: 7,
                        activeColor: t.accent,
                        inactiveColor: t.textSecondary.withOpacity(0.2),
                        onChanged: (v) =>
                            BibleUserDataService.I.setFontSize(v),
                      ),
                    ),
                    Text('A',
                        style: GoogleFonts.lora(
                            color: t.textSecondary, fontSize: 26)),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: BibleUserDataService.I.readerThemeNotifier,
              builder: (context, currentId, _) {
                final migrated =
                    BibleReaderThemeData.migrateId(currentId);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children:
                      BibleReaderThemeData.all.map((theme) {
                    final isActive = theme.id == migrated;
                    return GestureDetector(
                      onTap: () => BibleUserDataService.I
                          .setReaderTheme(theme.id),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.swatchColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? t.accent
                                : t.textSecondary.withOpacity(0.2),
                            width: isActive ? 2.5 : 1,
                          ),
                        ),
                        child: isActive
                            ? Icon(Icons.check,
                                color: theme.isDark
                                    ? Colors.white70
                                    : Colors.black54,
                                size: 14)
                            : null,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BOOK / CHAPTER SELECTOR
  // ═══════════════════════════════════════════════════════════════════════

  void _showBookChapterSelector() {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );
    int? selectedBookNumber;
    String selectedBookName = '';
    int selectedBookChapters = 0;
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchCtrl.text.toLowerCase();
            final filteredBooks = query.isEmpty
                ? _allBooks
                : _allBooks
                    .where(
                        (b) => b.name.toLowerCase().contains(query))
                    .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.92,
              minChildSize: 0.3,
              builder: (context, scrollCtrl) {
                return Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 12, bottom: 8),
                        child: Container(
                          width: 36,
                          height: 2,
                          decoration: BoxDecoration(
                            color: t.textSecondary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                      if (selectedBookNumber == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          child: TextField(
                            controller: searchCtrl,
                            style: GoogleFonts.manrope(
                              color: t.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Buscar libro...',
                              hintStyle: GoogleFonts.manrope(
                                color:
                                    t.textSecondary.withOpacity(0.5),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 12),
                            ),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20),
                        color: t.textSecondary.withOpacity(0.1),
                      ),
                      Expanded(
                        child: selectedBookNumber != null
                            ? _buildChapterGrid(
                                t,
                                selectedBookNumber!,
                                selectedBookName,
                                selectedBookChapters,
                                setSheetState,
                                () {
                                  setSheetState(() {
                                    selectedBookNumber = null;
                                  });
                                },
                              )
                            : ListView.builder(
                                controller: scrollCtrl,
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 8),
                                itemCount: filteredBooks.length,
                                itemBuilder: (_, index) {
                                  final book = filteredBooks[index];
                                  final isCurrent =
                                      book.number ==
                                          widget.bookNumber;
                                  return GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        selectedBookNumber =
                                            book.number;
                                        selectedBookName =
                                            book.name;
                                        selectedBookChapters =
                                            book.totalChapters;
                                      });
                                    },
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              book.name,
                                              style:
                                                  GoogleFonts.manrope(
                                                color: isCurrent
                                                    ? t.accent
                                                    : t.textPrimary,
                                                fontSize: 15,
                                                fontWeight: isCurrent
                                                    ? FontWeight.w600
                                                    : FontWeight
                                                        .w400,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${book.totalChapters}',
                                            style:
                                                GoogleFonts.manrope(
                                              color: t.textSecondary
                                                  .withOpacity(0.5),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChapterGrid(
    BibleReaderThemeData t,
    int bookNum,
    String bookName,
    int totalChaps,
    StateSetter setSheetState,
    VoidCallback onBack,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Icon(Icons.arrow_back_ios,
                    color: t.textSecondary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                bookName,
                style: GoogleFonts.manrope(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: totalChaps,
            itemBuilder: (_, index) {
              final chapter = index + 1;
              final isCurrent = bookNum == widget.bookNumber &&
                  chapter == _currentChapter;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  if (bookNum == widget.bookNumber) {
                    _goToChapter(chapter);
                  } else {
                    _goToBook(bookNum, bookName, chapter);
                  }
                },
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    '$chapter',
                    style: GoogleFonts.manrope(
                      color: isCurrent
                          ? t.accent
                          : t.textSecondary,
                      fontSize: 13,
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

}
