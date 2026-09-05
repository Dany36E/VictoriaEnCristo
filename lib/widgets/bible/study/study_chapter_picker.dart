import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_book.dart';
import '../../../models/bible/bible_version.dart';
import '../../../models/bible/bible_verse.dart';
import '../../../screens/bible/study_mode_screen.dart' show StudyPickerResult;
import '../../../services/bible/bible_parser_service.dart';
import '../../../services/bible/passage_history_service.dart';
import '../../../theme/bible_reader_theme.dart';
import '../../../services/bible/bible_user_data_service.dart';

/// Bottom sheet para elegir libro + capítulo (y opcionalmente versículo) en
/// Modo Estudio y en Apuntes.
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
  final ScrollController _booksScroll = ScrollController();
  late int _selectedBookNumber;
  late String _selectedBookName;
  late int _selectedChapter;
  String _query = '';
  List<_StudySearchHit> _searchHits = const [];
  bool _searching = false;
  int _searchToken = 0;
  bool _didAutoScroll = false;

  /// Referencia detectada en el portapapeles (pegado inteligente).
  _ClipboardRef? _clipboardRef;

  // Alturas fijas para poder calcular el auto-scroll con precisión.
  static const double _kHeaderH = 30;
  static const double _kBookH = 44;

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
    PassageHistoryService.I.ensureLoaded();
    _detectClipboardReference();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _booksScroll.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BÚSQUEDA
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    final token = ++_searchToken;
    _query = query;
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

  // ══════════════════════════════════════════════════════════════════════════
  // PEGADO INTELIGENTE (portapapeles)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _detectClipboardReference() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty || text.length > 40) return;
      final ref = _parseReference(text);
      if (ref != null && mounted) {
        setState(() => _clipboardRef = ref);
      }
    } catch (_) {
      // Silencioso: el pegado es una comodidad opcional.
    }
  }

  /// Reconoce "Juan 3:16", "Jn 3:16-18", "Salmos 23", etc.
  _ClipboardRef? _parseReference(String raw) {
    final normalized = _normalize(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = RegExp(
      r'^(.+?)\s+(\d{1,3})(?::(\d{1,3})(?:\s*-\s*(\d{1,3}))?)?$',
    ).firstMatch(normalized);
    if (match == null) return null;
    final bookPart = match.group(1)!.trim();
    final chapter = int.tryParse(match.group(2)!);
    if (chapter == null) return null;
    final vStart = match.group(3) == null
        ? null
        : int.tryParse(match.group(3)!);
    final vEnd = match.group(4) == null ? null : int.tryParse(match.group(4)!);
    for (final book in widget.books) {
      if (chapter < 1 || chapter > book.totalChapters) continue;
      if (_matchesBook(book, bookPart)) {
        return _ClipboardRef(
          bookNumber: book.number,
          bookName: book.name,
          chapter: chapter,
          verseStart: vStart,
          verseEnd: vEnd,
        );
      }
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SELECCIÓN / SALIDA
  // ══════════════════════════════════════════════════════════════════════════

  String _abbrFor(int number, String fallbackName) {
    for (final b in widget.books) {
      if (b.number == number) return b.abbreviation;
    }
    return fallbackName.length <= 3
        ? fallbackName
        : fallbackName.substring(0, 3);
  }

  PassageRef _refFor(int bookNumber, String bookName, int chapter, int? verse) {
    return PassageRef(
      bookNumber: bookNumber,
      bookName: bookName,
      abbreviation: _abbrFor(bookNumber, bookName),
      chapter: chapter,
      verse: verse,
    );
  }

  Future<void> _pop(StudyPickerResult result) async {
    HapticFeedback.selectionClick();
    await PassageHistoryService.I.recordRecent(
      _refFor(result.bookNumber, result.bookName, result.chapter, result.verse),
    );
    if (mounted) Navigator.pop(context, result);
  }

  void _selectHit(_StudySearchHit hit) {
    // Un resultado de tipo "Libro" tiene varios capítulos: no cerramos, sólo
    // lo seleccionamos y mostramos su grilla de capítulos para elegir.
    if (hit.source == 'Libro') {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedBookNumber = hit.bookNumber;
        _selectedBookName = hit.bookName;
        _selectedChapter = 1;
        _searchController.clear();
        _searchHits = const [];
        _searching = false;
        _query = '';
      });
      return;
    }
    // Texto (versículo concreto) → aplicar directo (autoApply). Referencia
    // (capítulo) → abrir capítulo completo.
    _pop(
      StudyPickerResult(
        hit.bookNumber,
        hit.bookName,
        hit.chapter,
        verse: hit.verse,
        autoApply: hit.verse != null,
      ),
    );
  }

  void _confirmChapter(int chapter) {
    _pop(StudyPickerResult(_selectedBookNumber, _selectedBookName, chapter));
  }

  void _selectPassageRef(PassageRef ref) {
    _pop(
      StudyPickerResult(
        ref.bookNumber,
        ref.bookName,
        ref.chapter,
        verse: ref.verse,
      ),
    );
  }

  void _openClipboardRef(_ClipboardRef ref) {
    _pop(
      StudyPickerResult(
        ref.bookNumber,
        ref.bookName,
        ref.chapter,
        verse: ref.verseStart,
        verseEnd: ref.verseEnd,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

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
    final showBrowse = !_searching && _searchHits.isEmpty;
    return DraggableScrollableSheet(
      initialChildSize: MediaQuery.textScalerOf(context).scale(16) > 20
          ? 0.95
          : 0.7,
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
                color: t.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Elegir capítulo',
                      style: GoogleFonts.cinzel(
                        color: t.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pop(
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
            _buildSearchField(t),
            if (_clipboardRef != null && showBrowse) _buildClipboardBanner(t),
            if (showBrowse) _buildChipsRow(t),
            if (_searching || _searchHits.isNotEmpty) _buildSearchResults(t),
            if (showBrowse)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildBookList(scroll, t)),
                    Container(
                      width: 1,
                      color: t.textSecondary.withValues(alpha: 0.12),
                    ),
                    Expanded(flex: 4, child: _buildChapterGrid(book, t)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: TextField(
        controller: _searchController,
        cursorColor: t.accent,
        style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar palabra o referencia (armadura, Ef 6)',
          hintStyle: GoogleFonts.manrope(
            color: t.textSecondary.withValues(alpha: 0.45),
            fontSize: 12,
          ),
          prefixIcon: Icon(Icons.search, color: t.textSecondary, size: 18),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: t.textSecondary, size: 18),
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
              color: t.textSecondary.withValues(alpha: 0.12),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: t.textSecondary.withValues(alpha: 0.12),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: t.accent.withValues(alpha: 0.75)),
          ),
        ),
        onChanged: _runSearch,
      ),
    );
  }

  Widget _buildClipboardBanner(BibleReaderThemeData t) {
    final ref = _clipboardRef!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: t.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openClipboardRef(ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.content_paste_go, color: t.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.manrope(
                        color: t.textSecondary,
                        fontSize: 12.5,
                      ),
                      children: [
                        const TextSpan(text: 'Pegar '),
                        TextSpan(
                          text: ref.label,
                          style: GoogleFonts.manrope(
                            color: t.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: t.accent, size: 18),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setState(() => _clipboardRef = null),
                  child: Icon(
                    Icons.close,
                    color: t.textSecondary.withValues(alpha: 0.6),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipsRow(BibleReaderThemeData t) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        PassageHistoryService.I.favoritesNotifier,
        PassageHistoryService.I.recentsNotifier,
      ]),
      builder: (_, _) {
        final favorites = PassageHistoryService.I.favoritesNotifier.value;
        final favKeys = favorites.map((p) => p.key).toSet();
        final recents = PassageHistoryService.I.recentsNotifier.value
            .where((p) => !favKeys.contains(p.key))
            .toList(growable: false);
        if (favorites.isEmpty && recents.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 24 + MediaQuery.textScalerOf(context).scale(12.5) * 1.5,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            children: [
              for (final ref in favorites) _chip(t, ref, favorite: true),
              for (final ref in recents) _chip(t, ref, favorite: false),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(
    BibleReaderThemeData t,
    PassageRef ref, {
    required bool favorite,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: favorite
            ? t.accent.withValues(alpha: 0.16)
            : t.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _selectPassageRef(ref),
          onLongPress: () async {
            HapticFeedback.mediumImpact();
            await PassageHistoryService.I.toggleFavorite(ref);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  favorite ? Icons.star_rounded : Icons.history,
                  size: 14,
                  color: favorite
                      ? t.accent
                      : t.textSecondary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  ref.label,
                  style: GoogleFonts.manrope(
                    color: favorite ? t.accent : t.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BibleReaderThemeData t) {
    return SizedBox(
      height: 200,
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
                final isBook = hit.source == 'Libro';
                final leadingIcon = hit.verse != null
                    ? Icons.format_quote_rounded
                    : isBook
                    ? Icons.auto_stories_outlined
                    : Icons.menu_book_outlined;
                return ListTile(
                  dense: true,
                  leading: Icon(leadingIcon, color: t.accent, size: 18),
                  title: Text(
                    isBook ? hit.bookName : hit.reference,
                    style: GoogleFonts.manrope(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: hit.verse != null
                      ? RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: GoogleFonts.manrope(
                              color: t.textSecondary,
                              fontSize: 11,
                            ),
                            children: _highlightSpans(hit.preview, _query, t),
                          ),
                        )
                      : Text(
                          hit.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            color: t.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                  trailing: Icon(
                    isBook
                        ? Icons.chevron_right
                        : hit.verse != null
                        ? Icons.add_circle_outline
                        : Icons.arrow_forward_rounded,
                    color: t.accent.withValues(alpha: 0.85),
                    size: 18,
                  ),
                  onTap: () => _selectHit(hit),
                );
              },
            ),
    );
  }

  /// Resalta cada palabra de la consulta dentro del texto del versículo.
  List<InlineSpan> _highlightSpans(
    String text,
    String query,
    BibleReaderThemeData t,
  ) {
    final base = TextSpan(text: text);
    if (query.trim().isEmpty) return [base];
    // `_normalize` preserva la longitud (1 char → 1 char), así que los índices
    // sobre el texto normalizado sirven para cortar el texto original.
    final nt = _normalize(text);
    final tokens = _normalize(
      query,
    ).split(RegExp(r'\s+')).where((tok) => tok.length >= 2).toList();
    if (tokens.isEmpty || nt.length != text.length) return [base];
    final ranges = <List<int>>[];
    for (final tok in tokens) {
      var i = 0;
      while (true) {
        final idx = nt.indexOf(tok, i);
        if (idx < 0) break;
        ranges.add([idx, idx + tok.length]);
        i = idx + tok.length;
      }
    }
    if (ranges.isEmpty) return [base];
    ranges.sort((a, b) => a[0].compareTo(b[0]));
    // Fusiona rangos solapados.
    final merged = <List<int>>[];
    for (final r in ranges) {
      if (merged.isNotEmpty && r[0] <= merged.last[1]) {
        if (r[1] > merged.last[1]) merged.last[1] = r[1];
      } else {
        merged.add([r[0], r[1]]);
      }
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final r in merged) {
      if (r[0] > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, r[0])));
      }
      spans.add(
        TextSpan(
          text: text.substring(r[0], r[1]),
          style: TextStyle(color: t.accent, fontWeight: FontWeight.w800),
        ),
      );
      cursor = r[1];
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  // ── Lista de libros con separadores AT / NT ────────────────────────────────

  Widget _buildBookList(ScrollController scroll, BibleReaderThemeData t) {
    // Construye una lista plana: encabezados de testamento + libros.
    final items = <_BookRow>[];
    String? lastTestament;
    for (final b in widget.books) {
      if (b.testament != lastTestament) {
        items.add(
          _BookRow.header(
            b.testament == 'AT' ? 'Antiguo Testamento' : 'Nuevo Testamento',
          ),
        );
        lastTestament = b.testament;
      }
      items.add(_BookRow.book(b));
    }

    _maybeAutoScroll(items, scroll);

    return ListView.builder(
      controller: scroll,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final row = items[i];
        if (row.isHeader) {
          return Container(
            height: _kHeaderH,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Text(
              row.header!,
              style: GoogleFonts.manrope(
                color: t.textSecondary.withValues(alpha: 0.65),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          );
        }
        final b = row.book!;
        final selected = b.number == _selectedBookNumber;
        return Material(
          color: selected
              ? t.accent.withValues(alpha: 0.10)
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedBookNumber = b.number;
                _selectedBookName = b.name;
                _selectedChapter = 1;
              });
            },
            child: SizedBox(
              height: _kBookH,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lora(
                          color: selected ? t.accent : t.textPrimary,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      b.abbreviation,
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withValues(alpha: 0.45),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: t.accent, size: 18),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _maybeAutoScroll(List<_BookRow> items, ScrollController scroll) {
    if (_didAutoScroll) return;
    _didAutoScroll = true;
    // Calcula el offset del libro actual y salta ahí tras el primer frame.
    double offset = 0;
    for (final row in items) {
      if (!row.isHeader && row.book!.number == widget.currentBookNumber) break;
      offset += row.isHeader ? _kHeaderH : _kBookH;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      final max = scroll.position.maxScrollExtent;
      scroll.jumpTo(offset.clamp(0, max));
    });
  }

  // ── Grilla de capítulos con contador de versículos ──────────────────────────

  Widget _buildChapterGrid(BibleBook book, BibleReaderThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
          child: Text(
            _selectedBookName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cinzel(
              color: t.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            'Toca un capítulo para elegir versículos',
            style: GoogleFonts.manrope(
              color: t.textSecondary.withValues(alpha: 0.7),
              fontSize: 10.5,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final columns = ((constraints.maxWidth - 24) / (48 * scale))
                  .floor()
                  .clamp(1, 4);
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  mainAxisExtent: 48 * scale,
                ),
                itemCount: book.totalChapters,
                itemBuilder: (_, i) {
                  final n = i + 1;
                  final isCurrent =
                      n == widget.currentChapter &&
                      _selectedBookNumber == widget.currentBookNumber;
                  final verseCount = book.versesPerChapter[n];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _confirmChapter(n),
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.textSecondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: isCurrent
                            ? Border.all(color: t.accent, width: 1.5)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$n',
                            style: GoogleFonts.manrope(
                              color: isCurrent ? t.accent : t.textPrimary,
                              fontWeight: isCurrent
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (verseCount != null)
                            Text(
                              '$verseCount v',
                              style: GoogleFonts.manrope(
                                color: t.textSecondary.withValues(alpha: 0.5),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Fila de la lista de libros: o encabezado de testamento, o un libro.
class _BookRow {
  final String? header;
  final BibleBook? book;
  const _BookRow.header(this.header) : book = null;
  const _BookRow.book(this.book) : header = null;
  bool get isHeader => header != null;
}

/// Referencia detectada en el portapapeles.
class _ClipboardRef {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int? verseStart;
  final int? verseEnd;
  const _ClipboardRef({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    this.verseStart,
    this.verseEnd,
  });

  String get label {
    if (verseStart == null) return '$bookName $chapter';
    if (verseEnd == null) return '$bookName $chapter:$verseStart';
    return '$bookName $chapter:$verseStart-$verseEnd';
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
