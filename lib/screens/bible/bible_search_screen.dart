import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_search_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/advanced_search_service.dart';
import '../../theme/bible_reader_theme.dart';
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

  const BibleSearchScreen({
    super.key,
    this.initialAdvanced = false,
    this.version,
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

  @override
  void initState() {
    super.initState();
    _loadRecent();
    if (widget.initialAdvanced) {
      _advancedMode = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focus.requestFocus();
      });
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

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _query = value;

    if (value.trim().length < 2) {
      setState(() {
        _searchResult = null;
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch());
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
        final bookName = result.bookName ??
            await BibleParserService.I.getBookName(version, result.bookNumber!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Abriendo $bookName ${result.chapter}:${result.verse}...'),
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
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _submitSearch(String query) {
    if (query.trim().length < 2) return;
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
          t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );

        return Scaffold(
          backgroundColor: t.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildSearchBar(t),
                _buildFilters(t),
                Expanded(
                  child: _query.trim().length < 2
                      ? (_advancedMode
                          ? _buildAdvancedPanel(t)
                          : _buildRecentList(t))
                      : (_advancedResult != null
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
            icon: Icon(Icons.arrow_back_ios,
                color: t.textSecondary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              style: GoogleFonts.manrope(
                color: t.textPrimary,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar libros, capítulos o versículos...',
                hintStyle: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.5),
                  fontSize: 16,
                ),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _submitSearch,
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close,
                  color: t.textSecondary.withOpacity(0.5), size: 20),
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
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FilterChip(
            label: 'Todo',
            isSelected: _testamentFilter == null,
            theme: t,
            onTap: () {
              setState(() => _testamentFilter = null);
              if (_query.trim().length >= 2) _doSearch();
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'AT',
            isSelected: _testamentFilter == 'old',
            theme: t,
            onTap: () {
              setState(() => _testamentFilter = 'old');
              if (_query.trim().length >= 2) _doSearch();
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'NT',
            isSelected: _testamentFilter == 'new',
            theme: t,
            onTap: () {
              setState(() => _testamentFilter = 'new');
              if (_query.trim().length >= 2) _doSearch();
            },
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() {
              _advancedMode = !_advancedMode;
              _advancedResult = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _advancedMode
                    ? t.accent.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _advancedMode
                      ? t.accent.withOpacity(0.4)
                      : t.textSecondary.withOpacity(0.15),
                ),
              ),
              child: Text(
                'Avanzado',
                style: GoogleFonts.manrope(
                  color: _advancedMode
                      ? t.accent
                      : t.textSecondary.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Spacer(),
          ValueListenableBuilder<BibleVersion>(
            valueListenable:
                BibleUserDataService.I.preferredVersionNotifier,
            builder: (_, version, _) {
              return Text(
                version.shortName,
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
            Icon(Icons.search,
                color: t.textSecondary.withOpacity(0.2), size: 48),
            const SizedBox(height: 12),
            Text(
              'Busca libros, capítulos o versículos',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ej: "Salmos 23", "Juan 3:16", "amor"',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.3),
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
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.5),
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
                  style: GoogleFonts.manrope(
                    color: t.accent.withOpacity(0.7),
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
            leading: Icon(Icons.history,
                color: t.textSecondary.withOpacity(0.3), size: 18),
            title: Text(
              q,
              style: GoogleFonts.manrope(
                color: t.textPrimary,
                fontSize: 15,
              ),
            ),
            trailing: GestureDetector(
              onTap: () async {
                await BibleSearchService.I.removeRecentSearch(q);
                _loadRecent();
              },
              child: Icon(Icons.close,
                  color: t.textSecondary.withOpacity(0.3), size: 16),
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
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: t.accent,
          ),
        ),
      );
    }

    final result = _searchResult;
    if (result == null) return const SizedBox.shrink();

    final hasReference = result.intent == SearchIntent.bookOnly ||
        result.intent == SearchIntent.bookAndChapter;
    final hasVerses = result.verses.isNotEmpty;

    if (!hasReference && !hasVerses) {
      return Center(
        child: Text(
          'Sin resultados',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Referencia directa card
        if (hasReference) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'REFERENCIA DIRECTA',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          _buildReferenceCard(result, t),
          const SizedBox(height: 20),
        ],
        // Versículos
        if (hasVerses) ...[
          Text(
            '${result.verses.length} versículo${result.verses.length == 1 ? '' : 's'}',
            style: GoogleFonts.manrope(
              color: t.textSecondary.withOpacity(0.5),
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...result.verses.map((verse) {
            return GestureDetector(
              onTap: () => _navigateToVerse(verse),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verse.reference,
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.5),
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
          }),
        ],
      ],
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
          final book = books.where((b) => b.number == result.bookNumber).firstOrNull;
          if (book != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChapterSelectorScreen(
                  book: book,
                  version: version,
                ),
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: t.accent, width: 2),
          ),
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
                    style: GoogleFonts.lora(
                      color: t.textPrimary,
                      fontSize: 16,
                    ),
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
                  style: GoogleFonts.manrope(
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
      String text, String query, BibleReaderThemeData t) {
    if (query.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.lora(
            color: t.textPrimary, fontSize: 15, height: 1.5),
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
        style: GoogleFonts.lora(
            color: t.textPrimary, fontSize: 15, height: 1.5),
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
              backgroundColor: const Color(0xFFD4AF37),
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: text.substring(matchIndex + query.length)),
        ],
        style: GoogleFonts.lora(
            color: t.textPrimary, fontSize: 15, height: 1.5),
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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Theme search section
        Text(
          'BUSCAR POR TEMA',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.4),
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
              onTap: () => _doAdvancedSearch(
                  AdvancedSearchType.theme, theme),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: t.isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  theme,
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // Strong number search
        Text(
          'NÚMERO STRONG',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Escribe un número Strong (ej: H430, G2316) en el buscador',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.4),
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 28),

        // Character search
        Text(
          'BUSCAR POR PERSONAJE',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Escribe el nombre de un personaje bíblico en el buscador',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Future<void> _doAdvancedSearch(
      AdvancedSearchType type, String query) async {
    setState(() => _advancedSearching = true);
    try {
      final version = BibleUserDataService.I.preferredVersionNotifier.value;

      AdvancedSearchResult result;
      switch (type) {
        case AdvancedSearchType.strong:
          result = await AdvancedSearchService.I
              .searchByStrong(query, version);
          break;
        case AdvancedSearchType.character:
          result = await AdvancedSearchService.I
              .searchByCharacter(query, version);
          break;
        case AdvancedSearchType.theme:
          result = await AdvancedSearchService.I
              .searchByTheme(query, version);
          break;
      }

      if (mounted) {
        setState(() {
          _advancedResult = result;
          _advancedSearching = false;
        });
      }
    } catch (_) {
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
                  color: t.accent, strokeWidth: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Buscando...',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.5),
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
                child: Icon(Icons.arrow_back_ios,
                    color: t.textSecondary, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: GoogleFonts.manrope(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      result.subtitle,
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                              style: GoogleFonts.manrope(
                                color: t.textSecondary.withOpacity(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (v.text.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _buildHighlightedText(
                                  v.text, v.highlight ?? '', t),
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
              ? theme.accent.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.accent.withOpacity(0.4)
                : theme.textSecondary.withOpacity(0.15),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: isSelected
                ? theme.accent
                : theme.textSecondary.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
