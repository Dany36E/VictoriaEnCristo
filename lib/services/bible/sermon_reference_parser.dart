import '../../models/bible/bible_book.dart';

class DetectedSermonReference {
  final int start;
  final int end;
  final String rawText;
  final BibleBook book;
  final int chapter;
  final int startVerse;
  final int endVerse;

  const DetectedSermonReference({
    required this.start,
    required this.end,
    required this.rawText,
    required this.book,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
  });

  String get label => '${book.name} $chapter:$verseLabel';
  String get verseLabel =>
      startVerse == endVerse ? '$startVerse' : '$startVerse-$endVerse';
}

List<DetectedSermonReference> detectSermonReferences(
  String source,
  List<BibleBook> books,
) {
  if (source.trim().isEmpty || books.isEmpty) return const [];
  final aliases = _bookAliases(books);
  final aliasPattern = aliases.keys.map(RegExp.escape).join('|');
  final pattern = RegExp(
    r'(?<![\p{L}\d])(' +
        aliasPattern +
        r')\.?\s*(\d{1,3})\s*[:\.,]\s*(\d{1,3})(?:\s*[-–]\s*(\d{1,3}))?(?![\d])',
    caseSensitive: false,
    unicode: true,
  );
  final out = <DetectedSermonReference>[];
  final seen = <String>{};
  for (final match in pattern.allMatches(source)) {
    final alias = _normalize(match.group(1) ?? '');
    final book = aliases[alias];
    if (book == null) continue;
    final chapter = int.tryParse(match.group(2) ?? '');
    final verse = int.tryParse(match.group(3) ?? '');
    final endVerseRaw = int.tryParse(match.group(4) ?? '');
    if (chapter == null || verse == null) continue;
    final maxVerse = book.versesPerChapter[chapter];
    if (maxVerse == null || verse < 1 || verse > maxVerse) continue;
    final endVerse = endVerseRaw == null
        ? verse
        : (endVerseRaw < verse ? verse : endVerseRaw);
    if (endVerse > maxVerse) continue;
    final key = '${book.number}:$chapter:$verse:$endVerse';
    if (!seen.add(key)) continue;
    out.add(
      DetectedSermonReference(
        start: match.start,
        end: match.end,
        rawText: source.substring(match.start, match.end),
        book: book,
        chapter: chapter,
        startVerse: verse,
        endVerse: endVerse,
      ),
    );
  }
  return List.unmodifiable(out);
}

Map<String, BibleBook> _bookAliases(List<BibleBook> books) {
  final aliases = <String, BibleBook>{};
  for (final book in books) {
    void add(String value) {
      final key = _normalize(value);
      if (key.isNotEmpty) aliases[key] = book;
    }

    add(book.name);
    add(book.abbreviation);
    for (final alias in _extraAliases[book.number] ?? const <String>[]) {
      add(alias);
    }
  }
  final ordered = aliases.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  return Map.fromEntries(ordered);
}

String _normalize(String value) {
  var out = value.trim().toLowerCase();
  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  replacements.forEach((from, to) => out = out.replaceAll(from, to));
  out = out.replaceAll(RegExp(r'\s+'), ' ');
  out = out.replaceAll(RegExp(r'\.$'), '');
  return out;
}

const Map<int, List<String>> _extraAliases = {
  1: ['gen', 'gn', 'ge'],
  2: ['exo', 'ex'],
  3: ['lev', 'lv'],
  4: ['num', 'nm'],
  5: ['deut', 'dt'],
  6: ['jos'],
  7: ['jue'],
  8: ['rut', 'rt'],
  9: ['1 sam', '1sam', '1 s', '1sa'],
  10: ['2 sam', '2sam', '2 s', '2sa'],
  11: ['1 rey', '1 reyes', '1re', '1 r'],
  12: ['2 rey', '2 reyes', '2re', '2 r'],
  13: ['1 cron', '1cron', '1 cr', '1cro'],
  14: ['2 cron', '2cron', '2 cr', '2cro'],
  15: ['esd'],
  16: ['neh'],
  17: ['est'],
  18: ['job'],
  19: ['sal', 'salmo', 'salmos', 'sl', 'slm'],
  20: ['prov', 'pr', 'pro'],
  21: ['ec', 'ecl', 'ecles'],
  22: ['cnt', 'cant', 'cantares'],
  23: ['isa', 'is'],
  24: ['jer', 'jr'],
  25: ['lam'],
  26: ['ez', 'eze'],
  27: ['dan', 'dn'],
  28: ['os'],
  29: ['jl'],
  30: ['amos', 'am'],
  31: ['abd'],
  32: ['jon'],
  33: ['miq', 'mi'],
  34: ['nah'],
  35: ['hab'],
  36: ['sof'],
  37: ['hag'],
  38: ['zac'],
  39: ['mal'],
  40: ['mat', 'mt'],
  41: ['mar', 'mr', 'mc'],
  42: ['luc', 'lc'],
  43: ['juan', 'jn', 'jua'],
  44: ['hech', 'hch', 'hechos'],
  45: ['rom', 'ro'],
  46: ['1 cor', '1cor', '1 co'],
  47: ['2 cor', '2cor', '2 co'],
  48: ['gal', 'ga'],
  49: ['efe', 'ef'],
  50: ['fil', 'flp'],
  51: ['col'],
  52: ['1 tes', '1tes', '1 ts'],
  53: ['2 tes', '2tes', '2 ts'],
  54: ['1 tim', '1tim', '1 ti'],
  55: ['2 tim', '2tim', '2 ti'],
  56: ['tit'],
  57: ['flm', 'filem'],
  58: ['heb', 'he'],
  59: ['sant', 'stg', 'sgo'],
  60: ['1 ped', '1ped', '1 pe'],
  61: ['2 ped', '2ped', '2 pe'],
  62: ['1 juan', '1juan', '1 jn', '1jn', 'i juan', 'i jn'],
  63: ['2 juan', '2juan', '2 jn', '2jn', 'ii juan', 'ii jn'],
  64: ['3 juan', '3juan', '3 jn', '3jn', 'iii juan', 'iii jn'],
  65: ['jud'],
  66: ['apoc', 'ap', 'apo'],
};
