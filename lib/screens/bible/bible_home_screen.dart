import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bible_reading_stats_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../widgets/bible/collapsible_section.dart';
import '../../widgets/bible/concordance_sheet.dart';
import 'bible_reader_screen.dart';
import 'bible_search_screen.dart';
import 'bible_settings_screen.dart';
import 'bible_stats_screen.dart';
import 'chapter_selector_screen.dart';
import 'collections_screen.dart';
import 'saved_verses_screen.dart';
import 'all_chapter_notes_screen.dart';
import 'all_notes_screen.dart';
import 'bible_parallel_screen.dart';
import 'bible_timeline_screen.dart';
import 'bible_map_screen.dart';
import 'gospel_harmony_screen.dart';
import 'typology_screen.dart';
import 'ot_quotes_screen.dart';

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
  Timer? _searchDebounce;

  // Continue-reading state
  int? _lastBookNumber;
  String? _lastBookName;
  int? _lastChapter;

  BibleVersion get _version =>
      BibleUserDataService.I.preferredVersionNotifier.value;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _loadLastRead();
  }

  Future<void> _loadLastRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bn = prefs.getInt('lastReadBookNumber');
      final name = prefs.getString('lastReadBookName');
      final ch = prefs.getInt('lastReadChapter');
      if (bn != null && name != null && ch != null && mounted) {
        setState(() {
          _lastBookNumber = bn;
          _lastBookName = name;
          _lastChapter = ch;
        });
      }
    } catch (e) {
      debugPrint('[BibleHome] Error en SharedPreferences: $e');
    }
  }

  Future<void> _loadBooks() async {
    try {
      final books = await BibleParserService.I.getBooks(_version);
      if (mounted) {
        setState(() {
          _allBooks = books;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[BIBLE_HOME] Error loading books: $e');
      if (mounted) setState(() => _loading = false);
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
    _searchDebounce?.cancel();
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
  // HEADER — Minimalista: ← título  🔍 ⚙️
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader(BibleReaderThemeData t) {
    if (_searchMode) return _buildSearchHeader(t);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.arrow_back_ios,
                  color: t.textSecondary, size: 18),
            ),
          ),
          Expanded(
            child: Text(
              'La Biblia',
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.search,
                color: t.textSecondary.withOpacity(0.6), size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BibleSearchScreen(),
              ),
            ),
          ),
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
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                    if (mounted) _performSearch(v);
                  });
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
  // MAIN CONTENT — Continue reading + Book list + Tools (collapsed)
  // ═══════════════════════════════════════════════════════════════════════

  /// Construye la lista plana intercalada: [null=header, BibleBook, BibleBook…]
  /// null representa un BibleCanonSection (usamos el índice para obtenerlo).
  List<Object?> _buildGroupedItems() {
    if (_allBooks.isEmpty) return [];
    final items = <Object?>[];
    BibleCanonSection? lastSection;
    for (final book in _allBooks) {
      final section = book.canonSection;
      if (lastSection == null || section.name != lastSection.name) {
        items.add(null); // header marker
        lastSection = section;
      }
      items.add(book);
    }
    return items;
  }

  Widget _buildMainContent(BibleReaderThemeData t) {
    final groupedItems = _buildGroupedItems();
    // Build section lookup: position of each null → section
    final Map<int, BibleCanonSection> headerAtIndex = {};
    {
      int sectionIdx = 0;
      for (int i = 0; i < groupedItems.length; i++) {
        if (groupedItems[i] == null) {
          if (sectionIdx < bibleCanonSections.length) {
            // find canonical section for the next book in the list
            BibleBook? nextBook;
            for (int j = i + 1; j < groupedItems.length; j++) {
              if (groupedItems[j] is BibleBook) {
                nextBook = groupedItems[j] as BibleBook;
                break;
              }
            }
            if (nextBook != null) {
              headerAtIndex[i] = nextBook.canonSection;
            }
          }
          sectionIdx++;
        }
      }
    }

    return CustomScrollView(
      slivers: [
        // Continue reading card
        if (_lastBookNumber != null)
          SliverToBoxAdapter(child: _buildContinueReading(t)),

        // Reading stats row (subtle)
        SliverToBoxAdapter(child: _buildStatsRow(t)),

        // Quick study tools strip
        SliverToBoxAdapter(child: _buildQuickToolsStrip(t)),

        // Book list with canonical section headers
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == 0) return const SizedBox(height: 8);
              final itemIndex = index - 1;
              if (itemIndex >= groupedItems.length) return null;
              final item = groupedItems[itemIndex];
              if (item == null) {
                final section = headerAtIndex[itemIndex];
                return section != null
                    ? _buildSectionHeader(section, t) : null;
              }
              return _buildBookItem(item as BibleBook, t);
            },
            childCount: groupedItems.length + 1,
          ),
        ),

        // Study tools (expanded by default)
        SliverToBoxAdapter(child: _buildToolsSection(t)),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ─── Canonical Section Header ──────────────────────────────────────────

  Widget _buildSectionHeader(BibleCanonSection section, BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.name.toUpperCase(),
            style: GoogleFonts.manrope(
              color: t.accent.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            section.description,
            style: GoogleFonts.manrope(
              color: t.textSecondary.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Continue Reading Card ──────────────────────────────────────────

  Widget _buildContinueReading(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BibleReaderScreen(
                bookNumber: _lastBookNumber!,
                bookName: _lastBookName!,
                chapter: _lastChapter!,
                version: _version,
              ),
            ),
          ).then((_) => _loadLastRead())
           .catchError((e) { debugPrint('⚠️ [BibleHome] Nav error: $e'); });
        },
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: t.isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.accent.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded,
                  color: t.accent.withOpacity(0.8), size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continuar leyendo',
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_lastBookName $_lastChapter',
                      style: GoogleFonts.lora(
                        color: t.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: t.textSecondary.withOpacity(0.3), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Stats Row (subtle) ─────────────────────────────────────────────

  Widget _buildStatsRow(BibleReaderThemeData t) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: BibleReadingStatsService.I.statsNotifier,
      builder: (context, stats, _) {
        final streak = stats['streak'] as int? ?? 0;
        final pct = stats['percentRead'] as double? ?? 0.0;
        if (streak == 0 && pct == 0.0) return const SizedBox(height: 12);
        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 4),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BibleStatsScreen(),
              ),
            ),
            child: Row(
              children: [
                if (streak > 0) ...[
                  Icon(Icons.local_fire_department,
                      color: const Color(0xFFFF6B35), size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '$streak días',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFFFF6B35),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (pct > 0) ...[
                  SizedBox(
                    width: 50,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: t.textSecondary.withOpacity(0.08),
                        color: t.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Quick Study Tools Strip ────────────────────────────────────────

  Widget _buildQuickToolsStrip(BibleReaderThemeData t) {
    final quickTools = [
      _ToolItem(Icons.bookmark_outline, 'Guardados', () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a1, a2) => const SavedVersesScreen(),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (ctx, a, sa, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      )),
      _ToolItem(Icons.sticky_note_2_outlined, 'Notas', () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a1, a2) => const AllNotesScreen(),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (ctx, a, sa, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      )),
      _ToolItem(Icons.collections_bookmark_outlined, 'Colecciones', () =>
          Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a1, a2) => const CollectionsScreen(),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (ctx, a, sa, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      )),
      _ToolItem(Icons.timeline, 'Línea', () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BibleTimelineScreen()),
      )),
      _ToolItem(Icons.map_outlined, 'Mapas', () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BibleMapScreen()),
      )),
      _ToolItem(Icons.grid_view_rounded, 'Armonía', () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GospelHarmonyScreen()),
      )),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: quickTools.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final tool = quickTools[index];
            return GestureDetector(
              onTap: tool.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: t.isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: t.accent.withOpacity(0.12),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tool.icon, color: t.accent, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      tool.label,
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Tools Section ──────────────────────────────────────────────────

  Widget _buildToolsSection(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: CollapsibleSection(
        title: 'Herramientas de estudio',
        initiallyExpanded: true,
        persistKey: 'bibleHomeToolsExpanded',
        theme: t,
        child: _buildToolsGrid(t),
      ),
    );
  }

  Widget _buildToolsGrid(BibleReaderThemeData t) {
    final tools = [
      _ToolItem(Icons.manage_search, 'Búsqueda', () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BibleSearchScreen(
            version: _version,
            initialAdvanced: true,
          ),
        ),
      )),
      _ToolItem(Icons.bookmark_outline, 'Guardados', () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a1, a2) => const SavedVersesScreen(),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (ctx, a, sa, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      )),
      _ToolItem(Icons.sticky_note_2_outlined, 'Notas', () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a1, a2) => const AllNotesScreen(),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (ctx, a, sa, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      )),
      _ToolItem(Icons.collections_bookmark_outlined, 'Colecciones', () =>
          Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a1, a2) => const CollectionsScreen(),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (ctx, a, sa, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      )),
      _ToolItem(Icons.timeline, 'Línea de Tiempo', () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BibleTimelineScreen()),
      )),
      _ToolItem(Icons.map_outlined, 'Mapas Bíblicos', () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BibleMapScreen()),
      )),
      _ToolItem(Icons.account_tree_outlined, 'Concordancia', () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ConcordanceSheet(version: _version, theme: t),
        );
      }),
      _ToolItem(Icons.description_outlined, 'Estudio capítulos', () =>
          Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a1, a2) => const AllChapterNotesScreen(),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (ctx, a, sa, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      )),
      _ToolItem(Icons.view_column_outlined, 'Vista Paralela', () =>
          Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BibleParallelScreen(
            bookNumber: 1,
            bookName: 'Génesis',
            chapter: 1,
            primaryVersion: _version,
          ),
        ),
      )),
      _ToolItem(Icons.grid_view_rounded, 'Armonía', () =>
          Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GospelHarmonyScreen()),
      )),
      _ToolItem(Icons.compare_arrows, 'Tipologías', () =>
          Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TypologyScreen()),
      )),
      _ToolItem(Icons.format_quote, 'Citas AT→NT', () =>
          Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OTQuotesScreen()),
      )),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: const EdgeInsets.only(top: 12),
      children: tools.map((tool) {
        return GestureDetector(
          onTap: tool.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: t.isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool.icon, color: t.accent, size: 20),
                const SizedBox(height: 6),
                Text(
                  tool.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBookItem(BibleBook book, BibleReaderThemeData t) {
    return Semantics(
      label: '${book.name}, ${book.totalChapters} capítulos',
      button: true,
      child: GestureDetector(
      onTap: () {
        Navigator.push(
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
        );
      },
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
              // Genre label
              Text(
                book.genre.label,
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.32),
                  fontSize: 10,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 10),
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
      ),    ),    );
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

class _ToolItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolItem(this.icon, this.label, this.onTap);
}
