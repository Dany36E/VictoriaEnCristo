import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_concordance_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../screens/bible/bible_reader_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// CONCORDANCE SHEET — Buscar una palabra en toda la Biblia.
/// DraggableScrollableSheet con campo de búsqueda y resultados agrupados.
/// Mejorado con: estadísticas AT/NT, filtros de testamento, agrupación.
/// ═══════════════════════════════════════════════════════════════════════════
class ConcordanceSheet extends StatefulWidget {
  final String initialWord;
  final BibleVersion version;
  final BibleReaderThemeData theme;

  const ConcordanceSheet({
    super.key,
    this.initialWord = '',
    required this.version,
    required this.theme,
  });

  @override
  State<ConcordanceSheet> createState() => _ConcordanceSheetState();
}

class _ConcordanceSheetState extends State<ConcordanceSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<ConcordanceResult> _results = [];
  bool _loading = false;
  Timer? _debounce;

  // Enhanced: filters & grouping
  // 0 = all, 1 = AT only, 2 = NT only
  int _testamentFilter = 0;
  // 0 = by book, 1 = by frequency
  int _groupMode = 0;
  // Exact word match
  bool _exactMatch = false;
  // Book filter (null = all books)
  String? _bookFilter;
  // Limit display
  static const int _displayLimit = 200;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialWord.isNotEmpty) {
      _controller.text = widget.initialWord;
      _search(widget.initialWord);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialWord.isEmpty) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(val);
    });
  }

  Future<void> _search(String word) async {
    if (word.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _showAll = false;
    });
    final results = await BibleConcordanceService.I.searchWord(
      word,
      widget.version,
      exactMatch: _exactMatch,
    );
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  List<ConcordanceResult> get _filteredResults {
    var out = _results;
    if (_testamentFilter == 1) {
      out = out.where((r) => r.bookNumber < 40).toList();
    } else if (_testamentFilter == 2) {
      out = out.where((r) => r.bookNumber >= 40).toList();
    }
    if (_bookFilter != null) {
      out = out.where((r) => r.bookName == _bookFilter).toList();
    }
    return out;
  }

  int get _atCount => _results.where((r) => r.bookNumber < 40).length;
  int get _ntCount => _results.where((r) => r.bookNumber >= 40).length;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final filtered = _filteredResults;

    // Group results
    final grouped = <String, List<ConcordanceResult>>{};
    for (final r in filtered) {
      grouped.putIfAbsent(r.bookName, () => []).add(r);
    }

    // If frequency mode, sort by count descending
    List<MapEntry<String, List<ConcordanceResult>>> groupEntries;
    if (_groupMode == 1) {
      groupEntries = grouped.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
    } else {
      groupEntries = grouped.entries.toList();
    }

    // Apply display limit
    final limitedEntries = _showAll ? groupEntries : groupEntries;
    final totalDisplayed = filtered.length;
    final shouldLimit = !_showAll && totalDisplayed > _displayLimit;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 2,
                  decoration: BoxDecoration(
                    color: t.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // Title + search
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.account_tree_outlined,
                        color: t.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Concordancia',
                      style: GoogleFonts.manrope(
                        color: t.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_results.isNotEmpty)
                      Text(
                        '${filtered.length} resultados',
                        style: GoogleFonts.manrope(
                          color: t.textSecondary.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              // Search field
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: t.isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    style: GoogleFonts.manrope(
                        color: t.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar palabra en toda la Biblia...',
                      hintStyle: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.4),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: _onChanged,
                  ),
                ),
              ),

              // Stats + Filter bar (only when results exist)
              if (_results.isNotEmpty) ...[
                _buildStatsBar(t),
                _buildFilterBar(t),
              ],

              Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: t.textSecondary.withOpacity(0.1),
              ),
              // Results
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: t.accent, strokeWidth: 1.5))
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              _controller.text.length >= 2
                                  ? 'Sin resultados'
                                  : 'Escribe una palabra para buscar',
                              style: GoogleFonts.manrope(
                                color: t.textSecondary.withOpacity(0.4),
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            itemCount: limitedEntries.length +
                                (shouldLimit ? 1 : 0),
                            itemBuilder: (ctx, groupIdx) {
                              if (shouldLimit &&
                                  groupIdx == limitedEntries.length) {
                                return _buildShowAllButton(t);
                              }
                              final entry = limitedEntries[groupIdx];
                              return _buildBookGroup(
                                  t, entry.key, entry.value);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Statistics bar: AT count | NT count | total books
  Widget _buildStatsBar(BibleReaderThemeData t) {
    final bookCount = <String>{};
    for (final r in _results) {
      bookCount.add(r.bookName);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          _buildStatChip(t, 'AT', _atCount, const Color(0xFF8B6914)),
          const SizedBox(width: 8),
          _buildStatChip(t, 'NT', _ntCount, const Color(0xFF1E90FF)),
          const SizedBox(width: 8),
          _buildStatChip(t, 'Libros', bookCount.length, t.accent),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      BibleReaderThemeData t, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $count',
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Filter bar: testament chips + exact match + book filter + grouping toggle
  Widget _buildFilterBar(BibleReaderThemeData t) {
    // Collect unique book names
    final books = <String>{};
    for (final r in _results) {
      books.add(r.bookName);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          // Testament filters
          _buildFilterChip(t, 'Todos', _testamentFilter == 0,
              () => setState(() { _testamentFilter = 0; _bookFilter = null; })),
          const SizedBox(width: 6),
          _buildFilterChip(t, 'AT', _testamentFilter == 1,
              () => setState(() { _testamentFilter = 1; _bookFilter = null; })),
          const SizedBox(width: 6),
          _buildFilterChip(t, 'NT', _testamentFilter == 2,
              () => setState(() { _testamentFilter = 2; _bookFilter = null; })),
          const SizedBox(width: 6),
          // Exact match
          _buildFilterChip(
            t,
            'Exacta',
            _exactMatch,
            () {
              setState(() => _exactMatch = !_exactMatch);
              if (_controller.text.trim().length >= 2) {
                _search(_controller.text);
              }
            },
          ),
          const SizedBox(width: 6),
          // Book filter
          if (books.length > 1)
            GestureDetector(
              onTap: () => _showBookFilter(t, books.toList()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _bookFilter != null
                      ? t.accent.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _bookFilter != null
                        ? t.accent.withOpacity(0.4)
                        : t.textSecondary.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book, size: 11,
                        color: _bookFilter != null
                            ? t.accent
                            : t.textSecondary.withOpacity(0.5)),
                    const SizedBox(width: 3),
                    Text(
                      _bookFilter ?? 'Libro',
                      style: GoogleFonts.manrope(
                        color: _bookFilter != null
                            ? t.accent
                            : t.textSecondary.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          // Group mode toggle
          GestureDetector(
            onTap: () => setState(() => _groupMode = _groupMode == 0 ? 1 : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _groupMode == 0
                      ? Icons.sort_by_alpha
                      : Icons.bar_chart,
                  size: 14,
                  color: t.accent.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  _groupMode == 0 ? 'Libro' : 'Frecuencia',
                  style: GoogleFonts.manrope(
                    color: t.accent.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookFilter(BibleReaderThemeData t, List<String> books) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('FILTRAR POR LIBRO',
                style: GoogleFonts.cinzel(
                    color: t.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 12),
            // "All" option
            ListTile(
              dense: true,
              title: Text('Todos los libros',
                  style: GoogleFonts.manrope(
                      color: _bookFilter == null
                          ? t.accent
                          : t.textPrimary,
                      fontSize: 13,
                      fontWeight: _bookFilter == null
                          ? FontWeight.w700
                          : FontWeight.w400)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _bookFilter = null);
              },
            ),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: books.length,
                itemBuilder: (ctx, i) {
                  final book = books[i];
                  final count =
                      _results.where((r) => r.bookName == book).length;
                  final isCurrent = _bookFilter == book;
                  return ListTile(
                    dense: true,
                    title: Text(book,
                        style: GoogleFonts.manrope(
                            color: isCurrent ? t.accent : t.textPrimary,
                            fontSize: 13,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w400)),
                    trailing: Text('$count',
                        style: GoogleFonts.manrope(
                            color: t.textSecondary.withOpacity(0.5),
                            fontSize: 11)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _bookFilter = book);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      BibleReaderThemeData t, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? t.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? t.accent.withOpacity(0.4)
                : t.textSecondary.withOpacity(0.15),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: selected ? t.accent : t.textSecondary.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildShowAllButton(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() => _showAll = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: t.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.accent.withOpacity(0.3)),
            ),
            child: Text(
              'Ver todos los resultados (${_filteredResults.length})',
              style: GoogleFonts.manrope(
                color: t.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookGroup(BibleReaderThemeData t, String bookName,
      List<ConcordanceResult> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            children: [
              Text(
                bookName,
                style: GoogleFonts.manrope(
                  color: t.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${items.length}',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        ...items.map((r) => _buildResultItem(t, r)),
      ],
    );
  }

  Widget _buildResultItem(BibleReaderThemeData t, ConcordanceResult r) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a1, a2) => BibleReaderScreen(
              bookNumber: r.bookNumber,
              bookName: r.bookName,
              chapter: r.chapter,
              version: widget.version,
            ),
            transitionDuration: const Duration(milliseconds: 150),
            transitionsBuilder: (ctx, a, sa, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.chapter}:${r.verse}',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            _buildHighlightedSnippet(t, r.snippet),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedSnippet(BibleReaderThemeData t, String text) {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.lora(
            color: t.textPrimary, fontSize: 13, height: 1.5),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final idx = lowerText.indexOf(lowerQuery);
    if (idx < 0) {
      return Text(
        text,
        style: GoogleFonts.lora(
            color: t.textPrimary, fontSize: 13, height: 1.5),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final baseStyle = GoogleFonts.lora(
        color: t.textPrimary, fontSize: 13, height: 1.5);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text.substring(0, idx), style: baseStyle),
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: baseStyle.copyWith(
            color: t.background,
            backgroundColor: const Color(0xFFD4AF37),
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
            text: text.substring(idx + query.length), style: baseStyle),
      ]),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
