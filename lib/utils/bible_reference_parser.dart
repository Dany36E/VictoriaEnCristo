/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE REFERENCE PARSER — Referencias bíblicas en español, tolerantes.
///
/// Entiende lo que la gente escribe y lo que traen los contenidos de la app:
///   - Nombres completos con o sin acentos: «Génesis 1:1», «Genesis 1:1».
///   - Singular/plural y variantes: «Salmo 103:12», «Cantar de los Cantares 2».
///   - Abreviaturas comunes: «Sal 23», «Gn 1:1», «1 Co 13:4», «Jn 3:16»,
///     «Flp 4:13», «Ap. 21:4», «1ra Juan 4:8», «Primera de Pedro 5:7».
///   - Códigos OSIS/USFM: «JHN.3.16», «PSA 23», «1CO 13:4».
///   - Rangos: «1 Tesalonicenses 5:16-18», separadores «:», «.» o «,».
///   - Libros de un solo capítulo: «Judas 24» → Judas 1:24.
///
/// Es Dart puro (sin Flutter) para poder probarlo en unit tests.
/// ═══════════════════════════════════════════════════════════════════════════
library;

/// Referencia ya resuelta a número de libro (1-66).
class BibleReference {
  final int bookNumber;

  /// Nombre canónico en español con acentos («Salmos», «1 Corintios»).
  final String bookName;
  final int chapter;
  final int? verse;
  final int? endVerse;

  const BibleReference({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    this.verse,
    this.endVerse,
  });

  /// «Juan 3:16», «Salmos 23», «1 Tesalonicenses 5:16-18».
  String get label {
    if (verse == null) return '$bookName $chapter';
    final fin = endVerse != null && endVerse! > verse! ? '-$endVerse' : '';
    return '$bookName $chapter:$verse$fin';
  }

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      other is BibleReference &&
      other.bookNumber == bookNumber &&
      other.chapter == chapter &&
      other.verse == verse &&
      other.endVerse == endVerse;

  @override
  int get hashCode => Object.hash(bookNumber, chapter, verse, endVerse);
}

class BibleReferenceParser {
  BibleReferenceParser._();

  /// Nombres canónicos (índice = número de libro - 1). Coinciden con los de
  /// BibleParserService para que las etiquetas sean las mismas en toda la app.
  static const List<String> bookNames = [
    'Génesis', 'Éxodo', 'Levítico', 'Números', 'Deuteronomio', 'Josué', //
    'Jueces', 'Rut', '1 Samuel', '2 Samuel', '1 Reyes', '2 Reyes',
    '1 Crónicas', '2 Crónicas', 'Esdras', 'Nehemías', 'Ester', 'Job',
    'Salmos', 'Proverbios', 'Eclesiastés', 'Cantares', 'Isaías', 'Jeremías',
    'Lamentaciones', 'Ezequiel', 'Daniel', 'Oseas', 'Joel', 'Amós', 'Abdías',
    'Jonás', 'Miqueas', 'Nahúm', 'Habacuc', 'Sofonías', 'Hageo', 'Zacarías',
    'Malaquías', 'Mateo', 'Marcos', 'Lucas', 'Juan', 'Hechos', 'Romanos',
    '1 Corintios', '2 Corintios', 'Gálatas', 'Efesios', 'Filipenses',
    'Colosenses', '1 Tesalonicenses', '2 Tesalonicenses', '1 Timoteo',
    '2 Timoteo', 'Tito', 'Filemón', 'Hebreos', 'Santiago', '1 Pedro',
    '2 Pedro', '1 Juan', '2 Juan', '3 Juan', 'Judas', 'Apocalipsis',
  ];

  /// Códigos USFM/OSIS (índice = número de libro - 1).
  static const List<String> usfmCodes = [
    'GEN', 'EXO', 'LEV', 'NUM', 'DEU', 'JOS', 'JDG', 'RUT', '1SA', '2SA', //
    '1KI', '2KI', '1CH', '2CH', 'EZR', 'NEH', 'EST', 'JOB', 'PSA', 'PRO',
    'ECC', 'SNG', 'ISA', 'JER', 'LAM', 'EZK', 'DAN', 'HOS', 'JOL', 'AMO',
    'OBA', 'JON', 'MIC', 'NAM', 'HAB', 'ZEP', 'HAG', 'ZEC', 'MAL', 'MAT',
    'MRK', 'LUK', 'JHN', 'ACT', 'ROM', '1CO', '2CO', 'GAL', 'EPH', 'PHP',
    'COL', '1TH', '2TH', '1TI', '2TI', 'TIT', 'PHM', 'HEB', 'JAS', '1PE',
    '2PE', '1JN', '2JN', '3JN', 'JUD', 'REV',
  ];

  /// Libros de un solo capítulo: «Judas 24» significa Judas 1:24.
  static const Set<int> singleChapterBooks = {31, 57, 63, 64, 65};

  /// Abreviaturas y variantes por libro (se normalizan al construir el
  /// índice: minúsculas, sin acentos ni espacios ni puntos).
  static const Map<int, List<String>> _aliases = {
    1: ['gn', 'gen', 'ge', 'genesis'],
    2: ['ex', 'exo', 'exod', 'exodo', 'exodus'],
    3: ['lv', 'lev', 'le', 'levitico', 'leviticus'],
    4: ['nm', 'num', 'nu', 'numeros', 'numbers'],
    5: ['dt', 'deut', 'deu', 'dto', 'deuteronomio', 'deuteronomy'],
    6: ['jos', 'js', 'josue', 'joshua'],
    7: ['jue', 'jc', 'jueces', 'judges', 'jdg'],
    8: ['rt', 'rut', 'ruth'],
    9: ['1s', '1sa', '1sam', '1sm', '1samuel'],
    10: ['2s', '2sa', '2sam', '2sm', '2samuel'],
    11: ['1r', '1re', '1rey', '1ry', '1reyes', '1kings', '1ki'],
    12: ['2r', '2re', '2rey', '2ry', '2reyes', '2kings', '2ki'],
    13: ['1cr', '1cro', '1cron', '1cronicas', '1chronicles', '1ch'],
    14: ['2cr', '2cro', '2cron', '2cronicas', '2chronicles', '2ch'],
    15: ['esd', 'esdras', 'ezra', 'ezr'],
    16: ['neh', 'ne', 'nehemias', 'nehemiah'],
    17: ['est', 'et', 'ester', 'esther'],
    18: ['jb', 'job'],
    19: ['sal', 'sl', 'salmo', 'salmos', 'ps', 'psa', 'psalm', 'psalms'],
    20: ['pr', 'pro', 'prov', 'prv', 'proverbios', 'proverbs'],
    21: ['ec', 'ecl', 'ecc', 'ecles', 'eclesiastes', 'qohelet'],
    22: [
      'cnt',
      'cant',
      'ct',
      'cantar',
      'cantares',
      'cantardeloscantares',
      'cantardecantares',
      'sng',
      'songofsongs',
      'songofsolomon',
    ],
    23: ['is', 'isa', 'isaias', 'isaiah'],
    24: ['jr', 'jer', 'jeremias', 'jeremiah'],
    25: ['lm', 'lam', 'lamentaciones', 'lamentations'],
    26: ['ez', 'eze', 'ezeq', 'ezequiel', 'ezekiel', 'ezk'],
    27: ['dn', 'dan', 'daniel'],
    28: ['os', 'oseas', 'hosea', 'hos'],
    29: ['jl', 'joel', 'jol'],
    30: ['am', 'amos', 'amo'],
    31: ['abd', 'ab', 'abdias', 'obadiah', 'oba'],
    32: ['jon', 'jonas', 'jonah'],
    33: ['mi', 'miq', 'miqueas', 'micah', 'mic'],
    34: ['nah', 'na', 'nahum', 'nam'],
    35: ['hab', 'ha', 'habacuc', 'habakkuk'],
    36: ['sof', 'so', 'sofonias', 'zephaniah', 'zep'],
    37: ['hag', 'ag', 'hageo', 'haggai'],
    38: ['zac', 'za', 'zacarias', 'zechariah', 'zec'],
    39: ['mal', 'ml', 'malaquias', 'malachi'],
    40: ['mt', 'mat', 'mateo', 'sanmateo', 'matthew'],
    41: ['mr', 'mc', 'mar', 'mrc', 'marcos', 'sanmarcos', 'mark', 'mrk'],
    42: ['lc', 'luc', 'lu', 'lucas', 'sanlucas', 'luke', 'luk'],
    43: ['jn', 'jua', 'juan', 'sanjuan', 'john', 'jhn'],
    44: ['hch', 'hec', 'hech', 'hechos', 'hechosdelosapostoles', 'acts', 'act'],
    45: ['ro', 'rom', 'rm', 'romanos', 'romans'],
    46: ['1co', '1cor', '1corintios', '1corinthians'],
    47: ['2co', '2cor', '2corintios', '2corinthians'],
    48: ['ga', 'gal', 'galatas', 'galatians'],
    49: ['ef', 'efe', 'efes', 'efesios', 'ephesians', 'eph'],
    50: ['fil', 'flp', 'filip', 'filipenses', 'philippians', 'php'],
    51: ['col', 'colosenses', 'colossians'],
    52: ['1ts', '1tes', '1tesalonicenses', '1thessalonians', '1th'],
    53: ['2ts', '2tes', '2tesalonicenses', '2thessalonians', '2th'],
    54: ['1ti', '1tim', '1tm', '1timoteo', '1timothy'],
    55: ['2ti', '2tim', '2tm', '2timoteo', '2timothy'],
    56: ['tit', 'tt', 'tito', 'titus'],
    57: ['flm', 'film', 'filem', 'filemon', 'philemon', 'phm'],
    58: ['he', 'heb', 'hb', 'hebreos', 'hebrews'],
    59: ['stg', 'sant', 'st', 'stgo', 'santiago', 'james', 'jas'],
    60: ['1p', '1pe', '1ped', '1pedro', '1peter'],
    61: ['2p', '2pe', '2ped', '2pedro', '2peter'],
    62: ['1jn', '1jua', '1juan', '1john'],
    63: ['2jn', '2jua', '2juan', '2john'],
    64: ['3jn', '3jua', '3juan', '3john'],
    65: ['jud', 'jds', 'judas', 'jude'],
    66: ['ap', 'apo', 'apoc', 'apocalipsis', 'rev', 'revelacion', 'revelation'],
  };

  static final Map<String, int> _aliasIndex = _buildAliasIndex();

  static Map<String, int> _buildAliasIndex() {
    final index = <String, int>{};
    for (var i = 0; i < bookNames.length; i++) {
      index[_compact(bookNames[i])] = i + 1;
      index[_compact(usfmCodes[i])] = i + 1;
    }
    _aliases.forEach((book, list) {
      for (final a in list) {
        index[_compact(a)] = book;
      }
    });
    return index;
  }

  /// Minúsculas y sin acentos (conserva espacios y signos).
  static String stripAccents(String input) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñç';
    const to = 'aaaaeeeeiiiioooouuuunc';
    final sb = StringBuffer();
    for (final ch in input.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      sb.write(i >= 0 ? to[i] : ch);
    }
    return sb.toString();
  }

  static String _compact(String input) =>
      stripAccents(input).replaceAll(RegExp(r'[\s\.]+'), '');

  static final RegExp _ordinal = RegExp(
    r'^(primera|primer|primero|1ra|1era|1ro|1a|1o|1º|1ª|i|'
    r'segunda|segundo|2da|2do|2a|2o|2º|2ª|ii|'
    r'tercera|tercer|tercero|3ra|3era|3ro|3a|3o|3º|3ª|iii)\s+(de\s+)?',
  );

  static String _ordinalDigit(String token) {
    if (token.startsWith('prim') || token.startsWith('1') || token == 'i') {
      return '1';
    }
    if (token.startsWith('seg') || token.startsWith('2') || token == 'ii') {
      return '2';
    }
    return '3';
  }

  /// Normaliza solo la parte del libro: «1ra. de Juan» → «1juan».
  static String _normalizeBookPart(String raw) {
    var s = stripAccents(raw).replaceAll('.', ' ').trim();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    final m = _ordinal.firstMatch(s);
    if (m != null) {
      s = '${_ordinalDigit(m.group(1)!)} ${s.substring(m.end)}';
    }
    // «San Juan», «S. Mateo» → Juan / Mateo (no afecta a «Santiago»).
    s = s.replaceFirst(
      RegExp(r'^(san|s)\s+(?=(juan|mateo|marcos|lucas)\b)'),
      '',
    );
    return s.replaceAll(' ', '');
  }

  /// Número de libro (1-66) para un nombre, abreviatura o código; null si no
  /// se reconoce o es ambiguo.
  static int? resolveBook(String raw) {
    final key = _normalizeBookPart(raw);
    if (key.isEmpty) return null;
    final exact = _aliasIndex[key];
    if (exact != null) return exact;
    // Prefijo único de un nombre canónico («filip», «ecle», «1tesa»).
    final letters = key.replaceAll(RegExp(r'^\d'), '');
    if (letters.length < 3) return null;
    int? found;
    for (var i = 0; i < bookNames.length; i++) {
      if (_compact(bookNames[i]).startsWith(key)) {
        if (found != null) return null; // ambiguo
        found = i + 1;
      }
    }
    return found;
  }

  /// Nombre canónico en español del libro [bookNumber] (1-66).
  static String bookName(int bookNumber) =>
      bookNumber >= 1 && bookNumber <= bookNames.length
      ? bookNames[bookNumber - 1]
      : 'Libro $bookNumber';

  static final RegExp _refPattern = RegExp(
    // libro (puede empezar con dígito/ordinal) + capítulo [+ versículo [+ fin]]
    r'^\s*((?:[123]\s*)?[^\d:]*?[a-zA-ZÀ-ÿ][^\d:]*?)\s*'
    r'(\d{1,3})'
    r'(?:\s*[:\.,]\s*(\d{1,3})|\s+(\d{1,3}))?'
    r'(?:\s*[-–—]\s*(\d{1,3}))?'
    r'(?!\d)',
  );

  /// Parsea «Juan 3:16», «Sal 23», «1 Co 13:4-7», «JHN.3.16», etc.
  /// Devuelve null si no hay libro reconocible y al menos un capítulo.
  static BibleReference? parse(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;
    final m = _refPattern.firstMatch(input);
    if (m == null) return null;
    final bookPart = m.group(1)!;
    final book = resolveBook(bookPart);
    if (book == null) return null;

    final first = int.tryParse(m.group(2)!);
    if (first == null || first < 1) return null;
    final second = int.tryParse(m.group(3) ?? m.group(4) ?? '');
    final end = int.tryParse(m.group(5) ?? '');

    int chapter = first;
    int? verse = second;
    if (second == null && singleChapterBooks.contains(book) && first > 1) {
      // «Judas 24» = capítulo 1, versículo 24.
      chapter = 1;
      verse = first;
    }
    if (verse != null && verse < 1) verse = null;
    final endVerse = (verse != null && end != null && end > verse) ? end : null;

    return BibleReference(
      bookNumber: book,
      bookName: bookName(book),
      chapter: chapter,
      verse: verse,
      endVerse: endVerse,
    );
  }

  /// Parsea una referencia OSIS con puntos: «ROM.5.8», «Ps.23», «1Cor.13.4».
  static BibleReference? parseOsis(String osis) {
    final parts = osis.trim().split('.');
    if (parts.length < 2) return null;
    final book = resolveBook(parts[0]);
    final chapter = int.tryParse(parts[1]);
    if (book == null || chapter == null) return null;
    final verse = parts.length > 2 ? int.tryParse(parts[2]) : null;
    return BibleReference(
      bookNumber: book,
      bookName: bookName(book),
      chapter: chapter,
      verse: verse,
    );
  }
}
