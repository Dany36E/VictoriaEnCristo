import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/highlight.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_search_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../widgets/bible/full_color_picker_sheet.dart';
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

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<int> _selectedVerseNumbers = {};

  // In-reader search state
  bool _showSearch = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<int> _searchMatchIndices = []; // verse indices that match
  int _currentMatchIndex = -1;

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

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedVerseNumbers.clear();
    });
  }

  Future<void> _loadChapter() async {
    setState(() {
      _loading = true;
      _selectedVerseIndex = null;
      _isSelectionMode = false;
      _selectedVerseNumbers.clear();
      _searchMatchIndices = [];
      _currentMatchIndex = -1;
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
      // Re-run search if active
      if (_showSearch && _searchQuery.length >= 2) {
        _runInReaderSearch(_searchQuery);
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
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _runInReaderSearch(String query) {
    setState(() {
      _searchQuery = query;
      _searchMatchIndices = [];
      _currentMatchIndex = -1;
    });
    if (query.trim().length < 2) return;

    final normalizedQuery = BibleSearchService.normalize(query);
    final matches = <int>[];
    for (int i = 0; i < _verses.length; i++) {
      if (BibleSearchService.normalize(_verses[i].text)
          .contains(normalizedQuery)) {
        matches.add(i);
      }
    }
    setState(() {
      _searchMatchIndices = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    });
    if (matches.isNotEmpty) _scrollToMatch(0);
  }

  void _scrollToMatch(int matchIdx) {
    if (matchIdx < 0 || matchIdx >= _searchMatchIndices.length) return;
    setState(() => _currentMatchIndex = matchIdx);
    // Estimate scroll to verse index
    final verseIdx = _searchMatchIndices[matchIdx];
    final fontSize = BibleUserDataService.I.fontSizeNotifier.value;
    final estimatedOffset = 56.0 + 92.0 + (verseIdx * fontSize * 2.2);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        estimatedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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

                  if (_showSearch) _buildSearchOverlay(t),

                  if ((_selectedVerseIndex != null || _isSelectionMode) && !_loading)
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
            icon: Icon(Icons.search,
                color: t.textSecondary.withOpacity(0.6), size: 18),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (_showSearch) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocusNode.requestFocus();
                });
              }
            },
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
                            final isMultiSelected = _isSelectionMode &&
                                _selectedVerseNumbers.contains(verse.verse);

                            return _buildVerseParagraph(
                              verse: verse,
                              index: index,
                              highlight: highlight,
                              hasNote: hasNote,
                              isSelected: isSelected,
                              isMultiSelected: isMultiSelected,
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
    required bool isMultiSelected,
    required double fontSize,
    required BibleReaderThemeData theme,
  }) {
    final highlightBg =
        highlight != null ? theme.highlightOverlay(highlight.color) : null;
    final showSelected = isSelected || isMultiSelected;

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedVerseNumbers.contains(verse.verse)) {
              _selectedVerseNumbers.remove(verse.verse);
              if (_selectedVerseNumbers.isEmpty) _isSelectionMode = false;
            } else {
              _selectedVerseNumbers.add(verse.verse);
            }
          });
        } else {
          setState(() {
            _selectedVerseIndex =
                _selectedVerseIndex == index ? null : index;
          });
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          HapticFeedback.mediumImpact();
          setState(() {
            _isSelectionMode = true;
            _selectedVerseNumbers.add(verse.verse);
            _selectedVerseIndex = null;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: showSelected
            ? BoxDecoration(
                color: isMultiSelected
                    ? theme.accent.withOpacity(0.12)
                    : theme.selectionBg)
            : null,
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
                isSearchMatch: _searchQuery.length >= 2 &&
                    _searchMatchIndices.contains(
                        _verses.indexOf(verse)),
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

  List<InlineSpan> _buildVerseTextSpans(
    String text, {
    required double fontSize,
    required BibleReaderThemeData theme,
    required Color? highlightBg,
    required bool isSearchMatch,
  }) {
    final baseStyle = GoogleFonts.lora(
      color: theme.textPrimary,
      fontSize: fontSize,
      height: 1.8,
      backgroundColor: highlightBg,
    );

    if (!isSearchMatch || _searchQuery.length < 2) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final normalizedText = BibleSearchService.normalize(text);
    final normalizedQuery = BibleSearchService.normalize(_searchQuery);
    final idx = normalizedText.indexOf(normalizedQuery);
    if (idx < 0) return [TextSpan(text: text, style: baseStyle)];

    final end = idx + _searchQuery.length;
    final spans = <InlineSpan>[];
    if (idx > 0) spans.add(TextSpan(text: text.substring(0, idx), style: baseStyle));
    spans.add(TextSpan(
      text: text.substring(idx, end.clamp(0, text.length)),
      style: baseStyle.copyWith(
        color: theme.background,
        backgroundColor: const Color(0xFFD4AF37),
        fontWeight: FontWeight.w600,
      ),
    ));
    if (end < text.length) {
      spans.add(TextSpan(text: text.substring(end), style: baseStyle));
    }
    return spans;
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

  // Multi-select color picker state
  bool _multiSelectShowColors = false;

  Widget _buildToolbarOverlay(BibleReaderThemeData t) {
    if (_isSelectionMode) {
      return Positioned(
        bottom: 16,
        left: 0,
        right: 0,
        child: _buildMultiSelectToolbar(t),
      );
    }
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

  Widget _buildMultiSelectToolbar(BibleReaderThemeData t) {
    final iconColor = t.isDark ? Colors.white70 : const Color(0xFF1A1A1A);
    final count = _selectedVerseNumbers.length;

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: t.toolbarBg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _multiSelectShowColors
          ? _buildMultiSelectColorPicker(t)
          : Row(
              children: [
                // Exit selection mode
                GestureDetector(
                  onTap: _exitSelectionMode,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Icon(Icons.close, color: iconColor, size: 20),
                  ),
                ),
                Text(
                  '$count',
                  style: GoogleFonts.manrope(
                    color: t.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Highlight all
                GestureDetector(
                  onTap: () =>
                      setState(() => _multiSelectShowColors = true),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: Icon(Icons.format_paint,
                        color: iconColor, size: 20),
                  ),
                ),
                // Save all
                GestureDetector(
                  onTap: _saveAllSelected,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: Icon(Icons.bookmark_outline,
                        color: iconColor, size: 20),
                  ),
                ),
                // Copy all
                GestureDetector(
                  onTap: _copyAllSelected,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: Icon(Icons.content_copy,
                        color: iconColor, size: 20),
                  ),
                ),
                // Share all
                GestureDetector(
                  onTap: _shareAllSelected,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: Icon(Icons.share,
                        color: iconColor, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
    );
  }

  Widget _buildMultiSelectColorPicker(BibleReaderThemeData t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: () => setState(() => _multiSelectShowColors = false),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Icon(Icons.arrow_back_ios_new,
                color: t.isDark ? Colors.white54 : Colors.black38, size: 16),
          ),
        ),
        ...HighlightColors.defaults.map((color) {
          return GestureDetector(
            onTap: () {
              _applyColorToSelected(HighlightColors.toHex(color));
            },
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
        // Custom color
        GestureDetector(
          onTap: () async {
            final color = await showModalBottomSheet<Color>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => FullColorPickerSheet(theme: t),
            );
            if (color != null) {
              _applyColorToSelected(HighlightColors.toHex(color));
            }
          },
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _applyColorToSelected(String hex) {
    final data = BibleUserDataService.I;
    for (final verseNum in _selectedVerseNumbers) {
      data.addHighlight(
        bookNumber: widget.bookNumber,
        chapter: _currentChapter,
        verse: verseNum,
        colorHex: hex,
      );
    }
    _multiSelectShowColors = false;
    _exitSelectionMode();
  }

  String _buildSelectedVersesText() {
    final sorted = _selectedVerseNumbers.toList()..sort();
    final buf = StringBuffer();
    for (final num in sorted) {
      final v = _verses.firstWhere((v) => v.verse == num);
      buf.write('$num ${v.text} ');
    }
    final first = sorted.first;
    final last = sorted.last;
    final ref = first == last
        ? '${widget.bookName} $_currentChapter:$first'
        : '${widget.bookName} $_currentChapter:$first-$last';
    buf.write('\n— $ref (${_currentVersion.shortName})');
    return buf.toString().trim();
  }

  void _saveAllSelected() {
    final data = BibleUserDataService.I;
    for (final verseNum in _selectedVerseNumbers) {
      final verse = _verses.firstWhere((v) => v.verse == verseNum);
      if (!data.isVerseSaved(verse.bookNumber, verse.chapter, verse.verse)) {
        data.toggleSavedVerse(
          bookNumber: verse.bookNumber,
          chapter: verse.chapter,
          verse: verse.verse,
          bookName: verse.bookName,
          text: verse.text,
          version: verse.version,
        );
      }
    }
    _exitSelectionMode();
  }

  void _copyAllSelected() {
    Clipboard.setData(ClipboardData(text: _buildSelectedVersesText()));
    HapticFeedback.lightImpact();
    _exitSelectionMode();
  }

  void _shareAllSelected() {
    Share.share(_buildSelectedVersesText());
    _exitSelectionMode();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // IN-READER SEARCH OVERLAY
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSearchOverlay(BibleReaderThemeData t) {
    final hasMatches = _searchMatchIndices.isNotEmpty;
    final matchText = hasMatches
        ? '${_currentMatchIndex + 1} de ${_searchMatchIndices.length}'
        : _searchQuery.length >= 2
            ? '0 resultados'
            : '';

    return Positioned(
      top: 44,
      left: 0,
      right: 0,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: t.surface.withOpacity(0.98),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: GoogleFonts.manrope(
                    color: t.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar en capítulo...',
                  hintStyle: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.4),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                textInputAction: TextInputAction.search,
                onChanged: _runInReaderSearch,
              ),
            ),
            if (matchText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  matchText,
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ),
            if (hasMatches) ...[
              GestureDetector(
                onTap: () {
                  if (_currentMatchIndex > 0) {
                    _scrollToMatch(_currentMatchIndex - 1);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.keyboard_arrow_up,
                      color: _currentMatchIndex > 0
                          ? t.textSecondary
                          : t.textSecondary.withOpacity(0.2),
                      size: 20),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (_currentMatchIndex < _searchMatchIndices.length - 1) {
                    _scrollToMatch(_currentMatchIndex + 1);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.keyboard_arrow_down,
                      color: _currentMatchIndex <
                              _searchMatchIndices.length - 1
                          ? t.textSecondary
                          : t.textSecondary.withOpacity(0.2),
                      size: 20),
                ),
              ),
            ],
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _showSearch = false;
                  _searchQuery = '';
                  _searchMatchIndices = [];
                  _currentMatchIndex = -1;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close,
                    color: t.textSecondary.withOpacity(0.5), size: 18),
              ),
            ),
          ],
        ),
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
