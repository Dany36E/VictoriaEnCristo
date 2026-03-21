import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/dictionary_entry.dart';
import '../../services/bible/bible_dictionary_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../services/bible/bible_user_data_service.dart';
import 'bible_dictionary_detail_screen.dart';

/// Pantalla de búsqueda en el diccionario bíblico.
class BibleDictionaryScreen extends StatefulWidget {
  const BibleDictionaryScreen({super.key});

  @override
  State<BibleDictionaryScreen> createState() => _BibleDictionaryScreenState();
}

class _BibleDictionaryScreenState extends State<BibleDictionaryScreen> {
  final _searchController = TextEditingController();
  final _dict = BibleDictionaryService.instance;
  List<DictionaryEntry> _results = [];
  String _filter = 'all'; // 'all', 'easton', 'hitchcock'

  @override
  void initState() {
    super.initState();
    _results = _dict.allEntries;
  }

  void _onSearch(String query) {
    setState(() {
      final all = _dict.search(query);
      _results = _applyFilter(all);
    });
  }

  List<DictionaryEntry> _applyFilter(List<DictionaryEntry> entries) {
    if (_filter == 'easton') {
      return entries.where((e) => e.source == 'Easton').toList();
    }
    if (_filter == 'hitchcock') {
      return entries.where((e) => e.source == 'Hitchcock').toList();
    }
    return entries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(t),
            _buildSearchBar(t),
            _buildFilterChips(t),
            Expanded(child: _buildResults(t)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BibleReaderThemeData t) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios_new,
                  color: t.textPrimary.withValues(alpha: 0.7),
                  size: 20),
            ),
            const SizedBox(width: 4),
            Icon(Icons.menu_book_outlined,
                color: t.accent, size: 22),
            const SizedBox(width: 10),
            Text(
              'DICCIONARIO BÍBLICO',
              style: GoogleFonts.cinzel(
                color: t.accent,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              '${_dict.totalCount} entradas',
              style: GoogleFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );

  Widget _buildSearchBar(BibleReaderThemeData t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearch,
          style: GoogleFonts.manrope(
            color: t.textPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Buscar término o definición...',
            hintStyle: GoogleFonts.manrope(
              color: t.textPrimary.withValues(alpha: 0.3),
              fontSize: 15,
            ),
            prefixIcon: Icon(Icons.search,
                color: t.accent.withValues(alpha: 0.5)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        color:
                            t.textPrimary.withValues(alpha: 0.4),
                        size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _onSearch('');
                    },
                  )
                : null,
            filled: true,
            fillColor: t.surface.withValues(alpha: 0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: t.accent.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: t.accent.withValues(alpha: 0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: t.accent),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );

  Widget _buildFilterChips(BibleReaderThemeData t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildChip('Todos', 'all', t),
            const SizedBox(width: 8),
            _buildChip('Easton', 'easton', t),
            const SizedBox(width: 8),
            _buildChip('Hitchcock', 'hitchcock', t),
          ],
        ),
      );

  Widget _buildChip(String label, String value, BibleReaderThemeData t) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = value;
          _results = _applyFilter(_dict.search(_searchController.text));
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.2)
              : t.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? t.accent
                : t.accent.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: selected
                ? t.accent
                : t.textPrimary.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BibleReaderThemeData t) {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 48,
                color: t.accent.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No se encontraron resultados',
              style: GoogleFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildEntryTile(_results[index], t),
    );
  }

  Widget _buildEntryTile(DictionaryEntry entry, BibleReaderThemeData t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BibleDictionaryDetailScreen(entry: entry),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: t.accent.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                entry.term,
                                style: GoogleFonts.manrope(
                                  color: t.accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    t.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.source,
                                style: GoogleFonts.manrope(
                                  color: t.accent
                                      .withValues(alpha: 0.6),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.shortDefinition,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            color: t.textPrimary
                                .withValues(alpha: 0.6),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: t.textPrimary.withValues(alpha: 0.2),
                      size: 20),
                ],
              ),
            ),
          ),
        ),
      );
}
