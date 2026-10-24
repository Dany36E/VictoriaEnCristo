/// Modelo para entradas del diccionario bíblico.
library;

import '../../utils/bible_reference_parser.dart';

class DictionaryEntry {
  /// Identificador estable («e0054» en Easton, «h12» en Hitchcock).
  final String id;
  final String term;

  /// Término original en inglés (vacío si no aplica).
  final String termEn;

  /// Definición. En Easton puede llevar marcadores `[[GEN.2.7|Gn 2:7]]`
  /// (versículo) y `[[VER:e0054|ABRAHAM]]` (véase otra entrada).
  final String definition;
  final List<String> references; // ["GEN.2.7", "ROM.5.12-14", "JDG.8.33-9.6"]
  final List<String> see; // ids de entradas relacionadas
  final String source; // "Easton" | "Hitchcock"

  const DictionaryEntry({
    this.id = '',
    required this.term,
    this.termEn = '',
    required this.definition,
    this.references = const [],
    this.see = const [],
    required this.source,
  });

  static final RegExp markerPattern = RegExp(
    r'\[\[([^\[\]|]+)\|([^\[\]]*)\]\]',
  );

  /// Definición sin marcadores (texto plano).
  String get plainDefinition =>
      definition.replaceAllMapped(markerPattern, (m) => m.group(2)!);

  /// Primeras ~2 oraciones (texto plano).
  String get shortDefinition {
    final plain = plainDefinition.replaceAll(RegExp(r'\s+'), ' ').trim();
    final sentences = plain.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.length <= 2) return plain;
    return '${sentences.take(2).join(' ')}...';
  }
}

/// Referencia de Easton («GEN.2.7», «ROM.5.12-14», «GEN.2-3», «JDG.8.33-9.6»)
/// ya resuelta para mostrarla y abrir el lector.
class DictionaryRef {
  final String raw;
  final BibleReference start;

  /// Fin del rango cuando cruza capítulos («8:33–9:6» o «2–3»).
  final int? endChapter;
  final int? endVerse;

  const DictionaryRef._(this.raw, this.start, this.endChapter, this.endVerse);

  static final RegExp _pattern = RegExp(
    r'^([1-3]?[A-Z]{2,3})\.(\d+)(?:\.(\d+))?(?:-(\d+)(?:\.(\d+))?)?$',
  );

  /// Null si el código no es válido.
  static DictionaryRef? parse(String raw) {
    final m = _pattern.firstMatch(raw.trim());
    if (m == null) return null;
    final book = BibleReferenceParser.usfmCodes.indexOf(m.group(1)!) + 1;
    if (book == 0) return null;
    final chapter = int.parse(m.group(2)!);
    final verse = m.group(3) == null ? null : int.parse(m.group(3)!);
    final a = m.group(4) == null ? null : int.parse(m.group(4)!);
    final b = m.group(5) == null ? null : int.parse(m.group(5)!);
    int? endChapter;
    int? endVerse;
    if (a != null && b != null) {
      endChapter = a; // JDG.8.33-9.6
      endVerse = b;
    } else if (a != null && verse != null) {
      endVerse = a; // ROM.5.12-14
    } else if (a != null) {
      endChapter = a; // GEN.2-3
    }
    return DictionaryRef._(
      raw,
      BibleReference(
        bookNumber: book,
        bookName: BibleReferenceParser.bookName(book),
        chapter: chapter,
        verse: verse,
        endVerse: endChapter == null ? endVerse : null,
      ),
      endChapter,
      endVerse,
    );
  }

  /// «Génesis 2:7», «Romanos 5:12-14», «Génesis 2–3», «Jueces 8:33–9:6».
  String get label {
    if (endChapter == null) return start.label;
    final s = start;
    if (s.verse == null) return '${s.bookName} ${s.chapter}–$endChapter';
    final fin = endVerse == null ? '$endChapter' : '$endChapter:$endVerse';
    return '${s.bookName} ${s.chapter}:${s.verse}–$fin';
  }
}
