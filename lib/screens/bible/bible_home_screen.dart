import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../widgets/bible/version_selector_sheet.dart';
import 'bible_reader_screen.dart';
import 'bible_search_screen.dart';
import 'bible_settings_screen.dart';
import 'chapter_selector_screen.dart';
import 'saved_verses_screen.dart';
import 'all_notes_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE HOME SCREEN — Edición editorial premium
///
/// Primera pantalla del módulo. Define toda la experiencia:
///   - Header minimalista (no AppBar)
///   - Lista unificada AT + NT (sin tabs)
///   - Búsqueda inline con highlight dorado
///   - Accesos secundarios a guardados y notas
/// ═══════════════════════════════════════════════════════════════════════════
class BibleHomeScreen extends StatefulWidget {
  const BibleHomeScreen({super.key});

  @override
  State<BibleHomeScreen> createState() => _BibleHomeScreenState();
}

class _BibleHomeScreenState extends State<BibleHomeScreen> {
  List<BibleBook> _allBooks = [];
  bool _loading = true;
  bool _searchMode = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<BibleVerse> _searchResults = [];
  bool _searching = false;

  BibleVersion get _version =>
      BibleUserDataService.I.preferredVersionNotifier.value;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await BibleParserService.I.getBooks(_version);
    if (mounted) {
      setState(() {
        _allBooks = books;
        _loading = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await BibleParserService.I.search(
      version: _version,
      query: query,
      maxResults: 40,
    );
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
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
          body: SafeArea(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        color: t.accent, strokeWidth: 1.5))
                : Column(
                    children: [
                      _buildHeader(t),
                      Expanded(
                        child: _searchMode
                            ? _buildSearchContent(t)
                            : _buildMainContent(t),
                      ),
                    ],
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
    if (_searchMode) return _buildSearchHeader(t);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.arrow_back_ios,
                  color: t.textSecondary, size: 18),
            ),
          ),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La Biblia',
                  style: GoogleFonts.cinzel(
                    color: t.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                ValueListenableBuilder<BibleVersion>(
                  valueListenable:
                      BibleUserDataService.I.preferredVersionNotifier,
                  builder: (context, version, _) {
                    return GestureDetector(
                      onTap: () => showVersionSelectorSheet(
                        context,
                        onChanged: () {
                          setState(() => _loading = true);
                          _loadBooks();
                        },
                      ),
                      child: Text(
                        version.displayName,
                        style: GoogleFonts.manrope(
                          color: t.textSecondary.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Search
          IconButton(
            icon: Icon(Icons.search,
                color: t.textSecondary.withOpacity(0.6), size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BibleSearchScreen(),
                ),
              );
            },
          ),
          // Settings
          IconButton(
            icon: Icon(Icons.tune,
                color: t.textSecondary.withOpacity(0.6), size: 20),
            onPressed: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (c, a1, a2) => const BibleSettingsScreen(),
                transitionDuration: const Duration(milliseconds: 150),
                transitionsBuilder: (ctx, a, sa, child) =>
                    FadeTransition(opacity: a, child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
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
                controller: _searchController,
                focusNode: _searchFocus,
                style: GoogleFonts.manrope(
                    color: t.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar en la Biblia...',
                  hintStyle: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.4),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) {
                  setState(() => _searchQuery = v);
                  _performSearch(v);
                },
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                color: t.textSecondary, size: 20),
            onPressed: () {
              setState(() {
                _searchMode = false;
                _searchQuery = '';
                _searchResults = [];
              });
              _searchController.clear();
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MAIN CONTENT (book list)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildMainContent(BibleReaderThemeData t) {
    return CustomScrollView(
      slivers: [
        // Secondary links + spacing
        SliverToBoxAdapter(
          child: _buildSecondaryLinks(t),
        ),

        // Unified book list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              // Calculate including section headers
              final items = _buildBookListItems();
              if (index >= items.length) return null;
              return items[index];
            },
            childCount: _buildBookListItems().length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildSecondaryLinks(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
      child: Row(
        children: [
          ValueListenableBuilder(
            valueListenable: BibleUserDataService.I.savedVersesNotifier,
            builder: (context, saved, _) {
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (c, a1, a2) =>
                        const SavedVersesScreen(),
                    transitionDuration:
                        const Duration(milliseconds: 150),
                    transitionsBuilder: (ctx, a, sa, child) =>
                        FadeTransition(opacity: a, child: child),
                  ),
                ),
                child: Text.rich(
                  TextSpan(
                    text: 'Versículos guardados',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.6),
                      fontSize: 13,
                    ),
                    children: [
                      if (saved.isNotEmpty)
                        TextSpan(
                          text: '  (${saved.length})',
                          style: TextStyle(color: t.accent),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '·',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.3),
                fontSize: 13,
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: BibleUserDataService.I.notesNotifier,
            builder: (context, notes, _) {
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (c, a1, a2) =>
                        const AllNotesScreen(),
                    transitionDuration:
                        const Duration(milliseconds: 150),
                    transitionsBuilder: (ctx, a, sa, child) =>
                        FadeTransition(opacity: a, child: child),
                  ),
                ),
                child: Text.rich(
                  TextSpan(
                    text: 'Notas',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.6),
                      fontSize: 13,
                    ),
                    children: [
                      if (notes.isNotEmpty)
                        TextSpan(
                          text: '  (${notes.length})',
                          style: TextStyle(color: t.accent),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBookListItems() {
    final items = <Widget>[];
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );

    for (int i = 0; i < _allBooks.length; i++) {
      final book = _allBooks[i];

      // Section header: AT before book 1, NT before book 40
      if (book.number == 1) {
        items.add(_buildSectionLabel('ANTIGUO TESTAMENTO', t));
      } else if (book.number == 40) {
        items.add(const SizedBox(height: 16));
        items.add(_buildSectionLabel('NUEVO TESTAMENTO', t));
      }

      items.add(_buildBookItem(book, t));
    }

    return items;
  }

  Widget _buildSectionLabel(String label, BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: t.textSecondary.withOpacity(0.4),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  Widget _buildBookItem(BibleBook book, BibleReaderThemeData t) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a1, a2) => ChapterSelectorScreen(
            book: book,
            version: _version,
          ),
          transitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (ctx, a, sa, child) {
            final slide = Tween(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut));
            return SlideTransition(position: slide, child: child);
          },
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  book.name,
                  style: GoogleFonts.lora(
                    color: t.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${book.totalChapters}',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SEARCH CONTENT
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSearchContent(BibleReaderThemeData t) {
    if (_searchQuery.trim().length < 3) {
      return Center(
        child: Text(
          'Escribe al menos 3 caracteres',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.4),
            fontSize: 13,
          ),
        ),
      );
    }

    if (_searching) {
      return Center(
        child: CircularProgressIndicator(
            color: t.accent, strokeWidth: 1.5),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.4),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final verse = _searchResults[index];
        return GestureDetector(
          onTap: () {
            setState(() {
              _searchMode = false;
              _searchQuery = '';
              _searchResults = [];
            });
            _searchController.clear();
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (c, a1, a2) => BibleReaderScreen(
                  bookNumber: verse.bookNumber,
                  bookName: verse.bookName,
                  chapter: verse.chapter,
                  version: _version,
                ),
                transitionDuration:
                    const Duration(milliseconds: 150),
                transitionsBuilder: (ctx, a, sa, child) =>
                    FadeTransition(opacity: a, child: child),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${verse.reference} — ${verse.version}',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                _buildHighlightedText(
                    verse.text, _searchQuery, t),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightedText(
      String text, String query, BibleReaderThemeData t) {
    if (query.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.lora(
            color: t.textPrimary, fontSize: 15, height: 1.5),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex < 0) {
      return Text(
        text,
        style: GoogleFonts.lora(
            color: t.textPrimary, fontSize: 15, height: 1.5),
        maxLines: 2,
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
          TextSpan(
              text: text.substring(matchIndex + query.length)),
        ],
        style: GoogleFonts.lora(
            color: t.textPrimary, fontSize: 15, height: 1.5),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
