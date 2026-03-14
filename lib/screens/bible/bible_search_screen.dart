import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_search_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE SEARCH SCREEN
/// Buscador general con normalización de acentos,
/// historial reciente, filtros y resaltado dorado.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleSearchScreen extends StatefulWidget {
  const BibleSearchScreen({super.key});

  @override
  State<BibleSearchScreen> createState() => _BibleSearchScreenState();
}

class _BibleSearchScreenState extends State<BibleSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<BibleVerse> _results = [];
  List<String> _recentSearches = [];
  bool _searching = false;
  String _query = '';
  String? _testamentFilter; // null, 'old', 'new'

  @override
  void initState() {
    super.initState();
    _loadRecent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
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
        _results = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch());
  }

  Future<void> _doSearch() async {
    if (_query.trim().length < 2) return;

    final version = BibleUserDataService.I.preferredVersionNotifier.value;
    final results = await BibleSearchService.I.search(
      version: version,
      query: _query,
      testamentFilter: _testamentFilter,
    );

    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  void _submitSearch(String query) {
    if (query.trim().length < 2) return;
    BibleSearchService.I.addRecentSearch(query);
    _loadRecent();
  }

  void _selectRecent(String query) {
    _controller.text = query;
    _controller.selection =
        TextSelection.collapsed(offset: query.length);
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
                      ? _buildRecentList(t)
                      : _buildResultsList(t),
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
                hintText: 'Buscar en la Biblia...',
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
          const Spacer(),
          ValueListenableBuilder<BibleVersion>(
            valueListenable:
                BibleUserDataService.I.preferredVersionNotifier,
            builder: (_, version, __) {
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
              'Busca palabras, frases o temas',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.4),
                fontSize: 14,
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

    if (_results.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _results.length + 1, // +1 for count header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${_results.length} resultado${_results.length == 1 ? '' : 's'}',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.5),
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          );
        }

        final verse = _results[index - 1];
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

    // Use original text positions (same indices since normalization is char-by-char)
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
