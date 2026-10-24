/// ═══════════════════════════════════════════════════════════════════════════
/// MI BIBLIOTECA — modelo unificado de resaltados, notas y guardados.
///
/// Lógica pura (filtro, búsqueda, orden y exportación) separada de la UI para
/// poder probarla sin Firebase. La pantalla está en
/// lib/screens/bible/bible_library_screen.dart.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import '../../models/bible/bible_note.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/highlight.dart';
import '../../models/bible/saved_verse.dart';
import '../../utils/bible_reference_parser.dart';
import 'bible_search_service.dart';

enum LibraryKind { saved, highlight, note }

enum LibrarySort { date, bibleOrder }

class LibraryItem {
  final LibraryKind kind;
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int verse;
  final int? endVerse;

  /// Versión del texto (null en notas: no dependen de la traducción).
  final String? versionId;
  final DateTime date;

  /// Texto bíblico (guardados; en resaltados se completa al cargarlo).
  final String? verseText;

  /// Texto de la nota personal (solo notas).
  final String? noteText;

  /// Color del resaltado (#RRGGBB, solo resaltados).
  final String? colorHex;

  const LibraryItem({
    required this.kind,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.verse,
    this.endVerse,
    this.versionId,
    required this.date,
    this.verseText,
    this.noteText,
    this.colorHex,
  });

  String get reference => endVerse != null && endVerse! > verse
      ? '$bookName $chapter:$verse-$endVerse'
      : '$bookName $chapter:$verse';

  /// Clave estable para cachés de texto: versión + versículo.
  String get textKey => '${versionId ?? ''}:$bookNumber:$chapter:$verse';

  LibraryItem withVerseText(String? text) => LibraryItem(
    kind: kind,
    bookNumber: bookNumber,
    bookName: bookName,
    chapter: chapter,
    verse: verse,
    endVerse: endVerse,
    versionId: versionId,
    date: date,
    verseText: text,
    noteText: noteText,
    colorHex: colorHex,
  );

  factory LibraryItem.fromSaved(SavedVerse s) => LibraryItem(
    kind: LibraryKind.saved,
    bookNumber: s.bookNumber,
    bookName: s.bookName.isNotEmpty
        ? s.bookName
        : BibleReferenceParser.bookName(s.bookNumber),
    chapter: s.chapter,
    verse: s.verse,
    endVerse: s.endVerse,
    versionId: s.version,
    date: s.savedAt,
    verseText: s.text,
  );

  factory LibraryItem.fromHighlight(Highlight h, {String? verseText}) =>
      LibraryItem(
        kind: LibraryKind.highlight,
        bookNumber: h.bookNumber,
        bookName: BibleReferenceParser.bookName(h.bookNumber),
        chapter: h.chapter,
        verse: h.verse,
        versionId: h.versionId,
        date: h.createdAt,
        verseText: verseText,
        colorHex: h.colorHex.toUpperCase(),
      );

  factory LibraryItem.fromNote(BibleNote n) => LibraryItem(
    kind: LibraryKind.note,
    bookNumber: n.bookNumber,
    bookName: n.bookName.isNotEmpty
        ? n.bookName
        : BibleReferenceParser.bookName(n.bookNumber),
    chapter: n.chapter,
    verse: n.verse,
    date: n.updatedAt,
    noteText: n.text,
  );
}

class BibleLibrary {
  BibleLibrary._();

  /// Filtra por búsqueda (referencia, texto bíblico o nota; sin acentos) y
  /// por color (resaltados), y ordena por fecha o por orden bíblico.
  static List<LibraryItem> query(
    Iterable<LibraryItem> items, {
    String search = '',
    String? colorHex,
    LibrarySort sort = LibrarySort.date,
  }) {
    final q = BibleSearchService.normalize(search.trim());
    final color = colorHex?.toUpperCase();
    final ref = q.isEmpty ? null : BibleReferenceParser.parse(search);
    final book = q.isEmpty ? null : BibleReferenceParser.resolveBook(search);

    bool matches(LibraryItem i) {
      if (color != null && i.colorHex != color) return false;
      if (q.isEmpty) return true;
      if (ref != null) {
        // «Juan 3» → todo Juan 3; «Juan 3:16» → ese versículo.
        return i.bookNumber == ref.bookNumber &&
            i.chapter == ref.chapter &&
            (ref.verse == null || i.verse == ref.verse);
      }
      if (book != null && i.bookNumber == book) return true;
      final hay = BibleSearchService.normalize(
        '${i.reference} ${i.verseText ?? ''} ${i.noteText ?? ''}',
      );
      return hay.contains(q);
    }

    final out = items.where(matches).toList();
    if (sort == LibrarySort.date) {
      out.sort((a, b) => b.date.compareTo(a.date));
    } else {
      out.sort((a, b) {
        final byBook = a.bookNumber.compareTo(b.bookNumber);
        if (byBook != 0) return byBook;
        final byChapter = a.chapter.compareTo(b.chapter);
        if (byChapter != 0) return byChapter;
        return a.verse.compareTo(b.verse);
      });
    }
    return out;
  }

  static String _kindTitle(LibraryKind k) => switch (k) {
    LibraryKind.saved => 'Versículos guardados',
    LibraryKind.highlight => 'Resaltados',
    LibraryKind.note => 'Notas',
  };

  static String _abbr(String? versionId) => versionId == null
      ? ''
      : ' (${BibleVersion.fromId(versionId).shareAbbreviation})';

  /// Exporta como texto plano (para compartir por mensaje).
  static String exportText(List<LibraryItem> items, LibraryKind kind) {
    final sb = StringBuffer('${_kindTitle(kind)} — Victoria en Cristo\n');
    for (final i in items) {
      sb.writeln();
      sb.writeln('${i.reference}${_abbr(i.versionId)}');
      if (i.verseText != null && i.verseText!.trim().isNotEmpty) {
        sb.writeln('«${i.verseText!.trim()}»');
      }
      if (i.noteText != null && i.noteText!.trim().isNotEmpty) {
        sb.writeln('Nota: ${i.noteText!.trim()}');
      }
    }
    return sb.toString().trimRight();
  }

  /// Exporta como Markdown (para notas o documentos).
  static String exportMarkdown(List<LibraryItem> items, LibraryKind kind) {
    final sb = StringBuffer('# ${_kindTitle(kind)}\n');
    for (final i in items) {
      sb.writeln();
      sb.writeln('## ${i.reference}${_abbr(i.versionId)}');
      if (i.verseText != null && i.verseText!.trim().isNotEmpty) {
        sb.writeln();
        sb.writeln('> ${i.verseText!.trim()}');
      }
      if (i.noteText != null && i.noteText!.trim().isNotEmpty) {
        sb.writeln();
        sb.writeln(i.noteText!.trim());
      }
    }
    return sb.toString().trimRight();
  }
}
