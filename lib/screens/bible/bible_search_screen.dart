import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_fonts.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_search_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/advanced_search_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../theme/contraste.dart';
import 'bible_reader_screen.dart';
import 'chapter_selector_screen.dart';
import '../../services/bible/bible_parser_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE SEARCH SCREEN
/// Buscador universal: libros, capítulos, versículos y texto libre.
/// Detecta intención del query automáticamente.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleSearchScreen extends StatefulWidget {
  final bool initialAdvanced;
  final BibleVersion? version;
  final String? initialQuery;

  const BibleSearchScreen({
    super.key,
    this.initialAdvanced = false,
    this.version,
    this.initialQuery,
  });

  @override
  State<BibleSearchScreen> createState() => _BibleSearchScreenState();
}

class _BibleSearchScreenState extends State<BibleSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  SearchResult? _searchResult;
  List<String> _recentSearches = [];
  bool _searching = false;
  String _query = '';
  String? _testamentFilter;
  bool _advancedMode = false;
  AdvancedSearchResult? _advancedResult;
  bool _advancedSearching = false;
  List<String> _advancedHistory = [];
  int? _startBook;
  int? _endBook;
  bool _groupByBook = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _loadAdvancedHistory();
    _advancedMode = widget.initialAdvanced;
    final initialQuery = widget.initialQuery?.trim() ?? '';
    if (initialQuery.isNotEmpty) {
      _controller.text = initialQuery;
      _controller.selection = TextSelection.collapsed(
        offset: initialQuery.length,
      );
      _query = initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _doAdvancedSearch(
          _advancedTypeFor(initialQuery),
          initialQuery,
          addToHistory: false,
        );
      });
    } else if (!widget.initialAdvanced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focus.requestFocus();
      });
    } else {
      _advancedMode = true;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final recent = await BibleSearchService.I.getRecentSearches();
    if (mounted) setState(() => _recentSearches = recent);
  }

  Future<void> _loadAdvancedHistory() async {
    final h = await AdvancedSearchService.I.getSearchHistory();
    if (mounted) setState(() => _advancedHistory = h);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _query = value;
    final minimumLength = _advancedMode ? 1 : 2;

    if (value.trim().length < minimumLength) {
      setState(() {
        _searchResult = null;
        _advancedResult = null;
        _searching = false;
        _advancedSearching = false;
      });
      return;
    }

    if (_advancedMode) {
      setState(() {
        _advancedSearching = true;
        _advancedResult = null;
      });
      _debounce = Timer(
        const Duration(milliseconds: 450),
        () => _doAdvancedSearch(
          _advancedTypeFor(value),
          value,
          addToHistory: false,
        ),
      );
    } else {
      setState(() => _searching = true);
      _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch());
    }
  }

  Future<void> _doSearch() async {
    if (_query.trim().length < 2) return;

    try {
      final version = BibleUserDataService.I.preferredVersionNotifier.value;
      final result = await BibleSearchService.I.detectAndSearch(
        version: version,
        query: _query,
        testamentFilter: _testamentFilter,
      );

      if (mounted) {
        // Si es verseReference, navegar directamente
        if (result.intent == SearchIntent.verseReference &&
            result.bookNumber != null &&
            result.chapter != null &&
            result.verse != null) {
          BibleSearchService.I.addRecentSearch(_query);
          final bookName =
              result.bookName ??
              await BibleParserService.I.getBookName(
                version,
                result.bookNumber!,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Abriendo $bookName ${result.chapter}:${result.verse}...',
                ),
                duration: const Duration(seconds: 1),
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BibleReaderScreen(
                  bookNumber: result.bookNumber!,
                  bookName: bookName,
                  chapter: result.chapter!,
                  version: version,
                ),
              ),
            );
          }
          return;
        }

        setState(() {
          _searchResult = result;
          _searching = false;
        });
      }
    } catch (e) {
      debugPrint('🔍 [SEARCH] Error searching: $e');
      if (mounted) setState(() => _searching = false);
    }
  }

  void _submitSearch(String query) {
    if (query.trim().length < (_advancedMode ? 1 : 2)) return;
    if (_advancedMode) {
      _doAdvancedSearch(_advancedTypeFor(query), query, addToHistory: true);
      return;
    }
    BibleSearchService.I.addRecentSearch(query);
    _loadRecent();
  }

  void _selectRecent(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _onQueryChanged(query);
    _submitSearch(query);
  }

  void _navigateToVerse(BibleVerse verse) {
    if (_query.trim().length >= 2) {
      BibleSearchService.I.addRecentSearch(_query);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          bookNumber: verse.bookNumber,
          bookName: verse.bookName,
          chapter: verse.chapter,
          version: BibleUserDataService.I.preferredVersionNotifier.value,
        ),
      ),
    );
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
          t.oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );

        return Scaffold(
          backgroundColor: t.pageBg,
          body: SafeArea(
            child: Column(
              children: [
                _buildSearchBar(t),
                _buildFilters(t),
                Expanded(
                  child: _query.trim().length < (_advancedMode ? 1 : 2)
                      ? (_advancedMode
                            ? _buildAdvancedPanel(t)
                            : _buildRecentList(t))
                      : (_advancedMode
                            ? _buildAdvancedResults(t)
                            : _buildResultsList(t)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(BibleReaderThemeData t) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: t.background,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: t.textSecondary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: t.oscuro
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: t.oscuro
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                cursorColor: t.textPrimary,
                style: AppFonts.manrope(color: t.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: _advancedMode
                      ? 'Palabra hebrea, griega o número Strong...'
                      : 'Buscar libros, capítulos o versículos...',
                  hintStyle: AppFonts.manrope(
                    color: t.textoAtenuado(
                      sobre: Color.alphaBlend(
                        t.oscuro
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        t.fondoVisible,
                      ),
                    ),
                    fontSize: 16,
                  ),
                  // Sin el relleno ni los bordes del tema de la app: el fondo
                  // y el borde son los de la cajita.
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: _submitSearch,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close,
                color: t.textSecondary.withValues(alpha: 0.5),
                size: 20,
              ),
              onPressed: () {
                _controller.clear();
                _onQueryChanged('');
                _focus.requestFocus();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilters(BibleReaderThemeData t) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          _FilterChip(
            label: 'Todo',
            isSelected: _testamentFilter == null,
            theme: t,
            onTap: () {
              setState(() => _testamentFilter = null);
              _rerunCurrentSearch();
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'AT',
            isSelected: _testamentFilter == 'old',
            theme: t,
            onTap: () {
              setState(() => _testamentFilter = 'old');
              _rerunCurrentSearch();
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'NT',
            isSelected: _testamentFilter == 'new',
            theme: t,
            onTap: () {
              setState(() => _testamentFilter = 'new');
              _rerunCurrentSearch();
            },
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              final advanced = !_advancedMode;
              setState(() {
                _advancedMode = advanced;
                _advancedResult = null;
                _searchResult = null;
              });
              if (_query.trim().isNotEmpty) {
                if (advanced) {
                  _doAdvancedSearch(
                    _advancedTypeFor(_query),
                    _query,
                    addToHistory: false,
                  );
                } else if (_query.trim().length >= 2) {
                  _doSearch();
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _advancedMode
                    ? t.accent.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _advancedMode
                      ? t.accent.withValues(alpha: 0.4)
                      : t.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                'Avanzado',
                style: AppFonts.manrope(
                  color: _advancedMode
                      ? legibleEnPastilla(t.accent, 0.15, t.fondoVisible)
                      : t.textoTenue(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          ValueListenableBuilder<BibleVersion>(
            valueListenable: BibleUserDataService.I.preferredVersionNotifier,
            builder: (_, version, _) {
              return Center(
                child: Text(
                  version.shortName,
                  style: AppFonts.manrope(
                    color: t.textoTenue(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentList(BibleReaderThemeData t) {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              color: t.textSecondary.withValues(alpha: 0.2),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Busca libros, capítulos o versículos',
              style: AppFonts.manrope(
                color: t.textoTenue(0.4),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ej: "Salmos 23", "Juan 3:16", "amor"',
              style: AppFonts.manrope(
                color: t.textoTenue(0.3),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                'Recientes',
                style: AppFonts.manrope(
                  color: t.textoTenue(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await BibleSearchService.I.clearRecentSearches();
                  _loadRecent();
                },
                child: Text(
                  'Borrar',
                  style: AppFonts.manrope(
                    color: t.accent.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._recentSearches.map((q) {
          return ListTile(
            dense: true,
            leading: Icon(
              Icons.history,
              color: t.textSecondary.withValues(alpha: 0.3),
              size: 18,
            ),
            title: Text(
              q,
              style: AppFonts.manrope(color: t.textPrimary, fontSize: 15),
            ),
            trailing: GestureDetector(
              onTap: () async {
                await BibleSearchService.I.removeRecentSearch(q);
                _loadRecent();
              },
              child: Icon(
                Icons.close,
                color: t.textSecondary.withValues(alpha: 0.3),
                size: 16,
              ),
            ),
            onTap: () => _selectRecent(q),
          );
        }),
      ],
    );
  }

  Widget _buildResultsList(BibleReaderThemeData t) {
    if (_searching) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
        ),
      );
    }

    final result = _searchResult;
    if (result == null) return const SizedBox.shrink();

    final hasReference =
        result.intent == SearchIntent.bookOnly ||
        result.intent == SearchIntent.bookAndChapter;
    final hasVerses = result.verses.isNotEmpty;

    if (!hasReference && !hasVerses) {
      return Center(
        child: Text(
          'Sin resultados',
          style: AppFonts.manrope(
            color: t.textoTenue(0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    // Build header items + verse items for efficient builder
    final headerItems = <Widget>[];
    if (hasReference) {
      headerItems.addAll([
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'REFERENCIA DIRECTA',
            style: AppFonts.manrope(
              color: t.textoTenue(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        _buildReferenceCard(result, t),
        const SizedBox(height: 20),
      ]);
    }
    if (hasVerses) {
      headerItems.addAll([
        Text(
          '${result.verses.length} versículo${result.verses.length == 1 ? '' : 's'}',
          style: AppFonts.manrope(
            color: t.textoTenue(0.5),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
      ]);
    }
    final totalItems =
        headerItems.length + (hasVerses ? result.verses.length : 0);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index < headerItems.length) return headerItems[index];
        final verseIndex = index - headerItems.length;
        final verse = result.verses[verseIndex];
        return GestureDetector(
          onTap: () => _navigateToVerse(verse),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verse.reference,
                  style: AppFonts.manrope(
                    color: t.textoTenue(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                _buildHighlightedText(verse.text, _query, t),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReferenceCard(SearchResult result, BibleReaderThemeData t) {
    final version = BibleUserDataService.I.preferredVersionNotifier.value;

    return GestureDetector(
      onTap: () async {
        BibleSearchService.I.addRecentSearch(_query);
        if (result.intent == SearchIntent.bookAndChapter &&
            result.bookNumber != null &&
            result.chapter != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BibleReaderScreen(
                bookNumber: result.bookNumber!,
                bookName: result.bookName ?? '',
                chapter: result.chapter!,
                version: version,
              ),
            ),
          );
        } else if (result.intent == SearchIntent.bookOnly &&
            result.bookNumber != null) {
          final books = await BibleParserService.I.getBooks(version);
          final book = books
              .where((b) => b.number == result.bookNumber)
              .firstOrNull;
          if (book != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ChapterSelectorScreen(book: book, version: version),
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.oscuro
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: t.accent, width: 2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.intent == SearchIntent.bookAndChapter
                        ? '${result.bookName}, capítulo ${result.chapter}'
                        : '${result.bookName} — ${result.totalChapters} capítulos',
                    style: AppFonts.lora(color: t.textPrimary, fontSize: 16),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.intent == SearchIntent.bookAndChapter
                      ? 'Ir al capítulo'
                      : 'Abrir libro',
                  style: AppFonts.manrope(
                    color: t.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, color: t.accent, size: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String text,
    String query,
    BibleReaderThemeData t,
  ) {
    if (query.isEmpty) {
      return Text(
        text,
        style: AppFonts.lora(
          color: t.textPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    final normalized = BibleSearchService.normalize(text);
    final normalizedQuery = BibleSearchService.normalize(query);
    final matchIndex = normalized.indexOf(normalizedQuery);

    if (matchIndex < 0) {
      return Text(
        text,
        style: AppFonts.lora(
          color: t.textPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, matchIndex)),
          TextSpan(
            text: text.substring(matchIndex, matchIndex + query.length),
            style: TextStyle(
              color: t.background,
              backgroundColor: t.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: text.substring(matchIndex + query.length)),
        ],
        style: AppFonts.lora(
          color: t.textPrimary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ADVANCED SEARCH
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAdvancedPanel(BibleReaderThemeData t) {
    final themes = AdvancedSearchService.I.availableThemes;
    final version = BibleUserDataService.I.preferredVersionNotifier.value;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // --- Search history ---
        if (_advancedHistory.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'HISTORIAL DE BÚSQUEDA',
                style: AppFonts.manrope(
                  color: t.textoTenue(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await AdvancedSearchService.I.clearHistory();
                  _loadAdvancedHistory();
                },
                child: Text(
                  'Borrar',
                  style: AppFonts.manrope(
                    color: t.accent.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _advancedHistory.take(10).map((h) {
              return GestureDetector(
                onTap: () {
                  _controller.text = h;
                  _controller.selection = TextSelection.collapsed(
                    offset: h.length,
                  );
                  _query = h;
                  _doAdvancedSearch(_advancedTypeFor(h), h);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: t.oscuro
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: t.textSecondary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        color: t.textSecondary.withValues(alpha: 0.4),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        h,
                        style: AppFonts.manrope(
                          color: t.textPrimary.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // --- Book range filter ---
        Text(
          'RANGO DE LIBROS',
          style: AppFonts.manrope(
            color: t.textoTenue(0.4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder(
          future: BibleParserService.I.getBooks(version),
          builder: (ctx, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final books = snap.data!;
            return Row(
              children: [
                Expanded(
                  child: _buildBookDropdown(t, books, _startBook, 'Desde...', (
                    v,
                  ) {
                    setState(() => _startBook = v);
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    color: t.textSecondary.withValues(alpha: 0.3),
                    size: 16,
                  ),
                ),
                Expanded(
                  child: _buildBookDropdown(t, books, _endBook, 'Hasta...', (
                    v,
                  ) {
                    setState(() => _endBook = v);
                  }),
                ),
                if (_startBook != null || _endBook != null)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: t.textSecondary.withValues(alpha: 0.5),
                      size: 16,
                    ),
                    onPressed: () => setState(() {
                      _startBook = null;
                      _endBook = null;
                    }),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // Theme search section
        Text(
          'BUSCAR POR TEMA',
          style: AppFonts.manrope(
            color: t.textoTenue(0.4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: themes.map((theme) {
            return GestureDetector(
              onTap: () => _doAdvancedSearch(AdvancedSearchType.theme, theme),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: t.oscuro
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  theme,
                  style: AppFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // Original-language word search
        Text(
          'PALABRA ORIGINAL',
          style: AppFonts.manrope(
            color: t.textoTenue(0.4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Copia una palabra hebrea o griega desde el Interlineal. La búsqueda reúne sus apariciones por forma escrita, lema y Strong cuando existe vínculo local.',
          style: AppFonts.manrope(
            color: t.textoTenue(0.55),
            fontSize: 12,
            height: 1.45,
          ),
        ),

        const SizedBox(height: 24),

        // Strong number search
        Text(
          'NÚMERO STRONG',
          style: AppFonts.manrope(
            color: t.textoTenue(0.4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'También puedes escribir un número completo (por ejemplo H430 o G2316). El léxico y el índice funcionan sin conexión.',
          style: AppFonts.manrope(
            color: t.textoTenue(0.4),
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildBookDropdown(
    BibleReaderThemeData t,
    List<dynamic> books,
    int? value,
    String hint,
    ValueChanged<int?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: t.oscuro
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: AppFonts.manrope(
              color: t.textoTenue(0.5),
              fontSize: 12,
            ),
          ),
          dropdownColor: t.surface,
          icon: Icon(
            Icons.expand_more,
            color: t.textSecondary.withValues(alpha: 0.4),
            size: 18,
          ),
          style: AppFonts.manrope(color: t.textPrimary, fontSize: 12),
          items: books
              .map(
                (b) => DropdownMenuItem<int>(
                  value: b.number,
                  child: Text(
                    b.name,
                    style: AppFonts.manrope(
                      color: t.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  AdvancedSearchType _advancedTypeFor(String query) {
    if (AdvancedSearchService.I.availableThemes.contains(query)) {
      return AdvancedSearchType.theme;
    }
    return RegExp(r'^\s*[gGhH]0*\d+[a-zA-Z]*\s*$').hasMatch(query)
        ? AdvancedSearchType.strong
        : AdvancedSearchType.originalWord;
  }

  void _rerunCurrentSearch() {
    if (_query.trim().length < (_advancedMode ? 1 : 2)) return;
    if (_advancedMode) {
      _doAdvancedSearch(_advancedTypeFor(_query), _query, addToHistory: false);
    } else {
      _doSearch();
    }
  }

  Future<void> _doAdvancedSearch(
    AdvancedSearchType type,
    String query, {
    bool addToHistory = true,
  }) async {
    setState(() => _advancedSearching = true);
    try {
      final version = BibleUserDataService.I.preferredVersionNotifier.value;
      if (addToHistory) {
        await AdvancedSearchService.I.addToHistory(query);
        _loadAdvancedHistory();
      }

      AdvancedSearchResult result;
      switch (type) {
        case AdvancedSearchType.strong:
          result = await AdvancedSearchService.I.searchByStrong(query, version);
          break;
        case AdvancedSearchType.originalWord:
          result = await AdvancedSearchService.I.searchByOriginalWord(
            query,
            version,
          );
          break;
        case AdvancedSearchType.character:
          result = await AdvancedSearchService.I.searchByCharacter(
            query,
            version,
          );
          break;
        case AdvancedSearchType.theme:
          result = await AdvancedSearchService.I.searchByTheme(
            query,
            version,
            startBook: _startBook,
            endBook: _endBook,
          );
          break;
      }

      if (mounted) {
        if (_query.trim() != query.trim()) return;
        setState(() {
          _advancedResult = result;
          _advancedSearching = false;
        });
      }
    } catch (e) {
      debugPrint('🔍 [SEARCH] Advanced search error: $e');
      if (mounted) setState(() => _advancedSearching = false);
    }
  }

  Widget _buildAdvancedResults(BibleReaderThemeData t) {
    if (_advancedSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: t.accent,
                strokeWidth: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Buscando...',
              style: AppFonts.manrope(
                color: t.textoTenue(0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final result = _advancedResult;
    if (result == null) return const SizedBox.shrink();

    final version = BibleUserDataService.I.preferredVersionNotifier.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _advancedResult = null),
                child: Icon(
                  Icons.arrow_back_ios,
                  color: t.textSecondary,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: AppFonts.manrope(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      result.subtitle,
                      style: AppFonts.manrope(
                        color: t.textoTenue(0.5),
                        fontSize: 12,
                      ),
                    ),
                    if (result.description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.description!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.manrope(
                          color: t.textoTenue(0.65),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _groupByBook = !_groupByBook),
                child: Icon(
                  _groupByBook ? Icons.view_list : Icons.list_alt,
                  color: t.textSecondary.withValues(alpha: 0.5),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        // Results
        Expanded(
          child: result.verses.isEmpty
              ? Center(
                  child: Text(
                    'Sin resultados',
                    style: AppFonts.manrope(
                      color: t.textoTenue(0.4),
                      fontSize: 14,
                    ),
                  ),
                )
              : _groupByBook
              ? _buildGroupedAdvancedResults(result, version, t)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: result.verses.length,
                  itemBuilder: (context, index) {
                    final v = result.verses[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BibleReaderScreen(
                            bookNumber: v.bookNumber,
                            bookName: v.bookName,
                            chapter: v.chapter,
                            version: version,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.reference,
                              style: AppFonts.manrope(
                                color: t.textoTenue(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (v.text.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _buildHighlightedText(
                                v.text,
                                v.highlight ?? '',
                                t,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroupedAdvancedResults(
    AdvancedSearchResult result,
    BibleVersion version,
    BibleReaderThemeData t,
  ) {
    // Group verses by book
    final groups = <String, List<AdvancedSearchVerse>>{};
    for (final v in result.verses) {
      groups.putIfAbsent(v.bookName, () => []).add(v);
    }

    final groupEntries = groups.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: groupEntries.length,
      itemBuilder: (context, index) {
        final entry = groupEntries[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book group header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: AppFonts.manrope(
                      color: t.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${entry.value.length})',
                    style: AppFonts.manrope(
                      color: t.textoTenue(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ...entry.value.map(
              (v) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BibleReaderScreen(
                      bookNumber: v.bookNumber,
                      bookName: v.bookName,
                      chapter: v.chapter,
                      version: version,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${v.chapter}:${v.verse}',
                        style: AppFonts.manrope(
                          color: t.textoTenue(0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (v.text.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _buildHighlightedText(v.text, v.highlight ?? '', t),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final BibleReaderThemeData theme;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.accent.withValues(alpha: 0.4)
                : theme.textSecondary.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: AppFonts.manrope(
            color: isSelected
                ? legibleEnPastilla(theme.accent, 0.15, theme.fondoVisible)
                : theme.textoTenue(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
