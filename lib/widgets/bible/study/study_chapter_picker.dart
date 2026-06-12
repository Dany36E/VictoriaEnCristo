import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_book.dart';
import '../../../models/bible/bible_version.dart';
import '../../../models/bible/bible_verse.dart';
import '../../../screens/bible/study_mode_screen.dart' show StudyPickerResult;
import '../../../services/bible/bible_parser_service.dart';
import '../../../theme/bible_reader_theme.dart';
import '../../../services/bible/bible_user_data_service.dart';

/// Bottom sheet para elegir libro + capítulo en Modo Estudio.
class StudyChapterPicker extends StatefulWidget {
  final List<BibleBook> books;
  final BibleVersion version;
  final int currentBookNumber;
  final int currentChapter;

  const StudyChapterPicker({
    super.key,
    required this.books,
    required this.version,
    required this.currentBookNumber,
    required this.currentChapter,
  });

  @override
  State<StudyChapterPicker> createState() => _StudyChapterPickerState();
}

class _StudyChapterPickerState extends State<StudyChapterPicker> {
  final TextEditingController _searchController = TextEditingController();
  late int _selectedBookNumber;
  late String _selectedBookName;
  late int _selectedChapter;
  List<_StudySearchHit> _searchHits = const [];
  bool _searching = false;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _selectedBookNumber = widget.currentBookNumber;
    _selectedChapter = widget.currentChapter;
    _selectedBookName = widget.books
        .firstWhere(
          (b) => b.number == widget.currentBookNumber,
          orElse: () => widget.books.isNotEmpty
              ? widget.books.first
              : const BibleBook(
                  number: 1,
                  name: 'Génesis',
                  testament: 'AT',
                  totalChapters: 50,
                  versesPerChapter: {},
                ),
        )
        .name;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    final token = ++_searchToken;
    if (query.isEmpty) {
      setState(() {
        _searchHits = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final hits = <_StudySearchHit>[];
    hits.addAll(_referenceHits(query));
    if (hits.isNotEmpty) {
      setState(() {
        _searchHits = _uniqueHits(hits);
        _searching = false;
      });
      return;
    }
    if (query.length >= 3) {
      final verses = await BibleParserService.I.search(
        version: widget.version,
        query: query,
        maxResults: 24,
      );
      for (final verse in verses) {
        hits.add(_StudySearchHit.fromVerse(verse));
      }
    }
    if (!mounted || token != _searchToken) return;
    setState(() {
      _searchHits = _uniqueHits(hits);
      _searching = false;
    });
  }

  List<_StudySearchHit> _referenceHits(String query) {
    final normalized = _normalize(query).replaceAll(RegExp(r'\s+'), ' ');
    final match = RegExp(r'^(.+?)\s+(\d{1,3})$').firstMatch(normalized);
    if (match == null) return _bookHits(normalized);
    final bookPart = match.group(1)!.trim();
    final chapter = int.tryParse(match.group(2)!);
    if (chapter == null) return const [];
    final hits = <_StudySearchHit>[];
    for (final book in widget.books) {
      if (chapter < 1 || chapter > book.totalChapters) continue;
      if (_matchesBook(book, bookPart)) {
        hits.add(
          _StudySearchHit(
            bookNumber: book.number,
            bookName: book.name,
            chapter: chapter,
            verse: null,
            preview: 'Abrir ${book.name} $chapter',
            source: 'Referencia',
          ),
        );
      }
    }
    return hits;
  }

  List<_StudySearchHit> _bookHits(String query) {
    if (query.length < 2) return const [];
    final hits = <_StudySearchHit>[];
    for (final book in widget.books) {
      if (_matchesBook(book, query)) {
        hits.add(
          _StudySearchHit(
            bookNumber: book.number,
            bookName: book.name,
            chapter: 1,
            verse: null,
            preview: 'Elegir libro (${book.totalChapters} capitulos)',
            source: 'Libro',
          ),
        );
      }
    }
    return hits;
  }

  List<_StudySearchHit> _uniqueHits(List<_StudySearchHit> hits) {
    final seen = <String>{};
    return hits.where((hit) => seen.add(hit.key)).toList();
  }

  bool _matchesBook(BibleBook book, String query) {
    final name = _normalize(book.name);
    final abbreviation = _normalize(book.abbreviation);
    final compact = name.replaceAll(' ', '');
    final q = query.replaceAll(' ', '');
    if (name.startsWith(query) ||
        compact.startsWith(q) ||
        abbreviation.startsWith(q)) {
      return true;
    }
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .join();
    return initials.startsWith(q);
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  void _selectHit(_StudySearchHit hit) {
    setState(() {
      _selectedBookNumber = hit.bookNumber;
      _selectedBookName = hit.bookName;
      _selectedChapter = hit.chapter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
        BibleUserDataService.I.readerThemeNotifier.value,
      ),
    );
    final book = widget.books.firstWhere(
      (b) => b.number == _selectedBookNumber,
      orElse: () => widget.books.first,
    );
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: t.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Elegir capítulo',
                    style: GoogleFonts.cinzel(
                      color: t.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      StudyPickerResult(
                        _selectedBookNumber,
                        _selectedBookName,
                        _selectedChapter,
                      ),
                    ),
                    child: Text(
                      'Abrir',
                      style: GoogleFonts.manrope(
                        color: t.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: _searchController,
                cursorColor: t.accent,
                style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar palabra o referencia (armadura, Ef 6)',
                  hintStyle: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.45),
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: t.textSecondary,
                    size: 18,
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(
                            Icons.close,
                            color: t.textSecondary,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _runSearch('');
                          },
                        ),
                  filled: true,
                  fillColor: t.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: t.textSecondary.withOpacity(0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: t.textSecondary.withOpacity(0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.accent.withOpacity(0.75)),
                  ),
                ),
                onChanged: _runSearch,
              ),
            ),
            if (_searching || _searchHits.isNotEmpty)
              SizedBox(
                height: 160,
                child: _searching
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: t.accent,
                            strokeWidth: 1.7,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        itemCount: _searchHits.length,
                        itemBuilder: (_, index) {
                          final hit = _searchHits[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              hit.verse == null
                                  ? Icons.menu_book_outlined
                                  : Icons.notes_outlined,
                              color: t.accent,
                              size: 18,
                            ),
                            title: Text(
                              hit.reference,
                              style: GoogleFonts.manrope(
                                color: t.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              hit.preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                color: t.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            trailing: Text(
                              hit.source,
                              style: GoogleFonts.manrope(
                                color: t.textSecondary.withOpacity(0.6),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () => _selectHit(hit),
                          );
                        },
                      ),
              ),
            Expanded(
              child: Row(
                children: [
                  // Lista de libros
                  Expanded(
                    flex: 5,
                    child: ListView.builder(
                      controller: scroll,
                      itemCount: widget.books.length,
                      itemBuilder: (_, i) {
                        final b = widget.books[i];
                        final selected = b.number == _selectedBookNumber;
                        return ListTile(
                          dense: true,
                          title: Text(
                            b.name,
                            style: GoogleFonts.lora(
                              color: selected ? t.accent : t.textPrimary,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () => setState(() {
                            _selectedBookNumber = b.number;
                            _selectedBookName = b.name;
                            _selectedChapter = 1;
                          }),
                        );
                      },
                    ),
                  ),
                  Container(width: 1, color: t.textSecondary.withOpacity(0.12)),
                  // Grilla de capítulos
                  Expanded(
                    flex: 4,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 1,
                          ),
                      itemCount: book.totalChapters,
                      itemBuilder: (_, i) {
                        final n = i + 1;
                        final selected = n == _selectedChapter;
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() => _selectedChapter = n),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? t.accent
                                  : t.textSecondary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$n',
                              style: GoogleFonts.manrope(
                                color: selected ? t.background : t.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudySearchHit {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int? verse;
  final String preview;
  final String source;

  const _StudySearchHit({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.preview,
    required this.source,
  });

  factory _StudySearchHit.fromVerse(BibleVerse verse) => _StudySearchHit(
    bookNumber: verse.bookNumber,
    bookName: verse.bookName,
    chapter: verse.chapter,
    verse: verse.verse,
    preview: verse.text,
    source: 'Texto',
  );

  String get key => '$bookNumber:$chapter:${verse ?? 0}:$source';

  String get reference {
    if (verse == null) return '$bookName $chapter';
    return '$bookName $chapter:$verse';
  }
}
