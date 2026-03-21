// Mapas de traducción EN → ES para datos de Blue Letter Bible.

class BlbTranslator {
  BlbTranslator._();

  /// Part of Speech: inglés → español.
  static const Map<String, String> partOfSpeech = {
    'noun': 'sustantivo',
    'verb': 'verbo',
    'adjective': 'adjetivo',
    'adverb': 'adverbio',
    'pronoun': 'pronombre',
    'preposition': 'preposición',
    'conjunction': 'conjunción',
    'interjection': 'interjección',
    'particle': 'partícula',
    'article': 'artículo',
    'proper noun': 'nombre propio',
    'noun masculine': 'sustantivo masculino',
    'noun feminine': 'sustantivo femenino',
    'noun common': 'sustantivo común',
    'verb transitive': 'verbo transitivo',
    'verb intransitive': 'verbo intransitivo',
    'numeral': 'numeral',
    'suffix': 'sufijo',
    'prefix': 'prefijo',
  };

  /// Idioma del original.
  static const Map<String, String> language = {
    'hebrew': 'hebreo',
    'greek': 'griego',
    'aramaic': 'arameo',
    'chaldee': 'caldeo',
  };

  /// Testamento.
  static const Map<String, String> testament = {
    'Old Testament': 'Antiguo Testamento',
    'New Testament': 'Nuevo Testamento',
  };

  /// Traduce part of speech. Si no existe, devuelve el original.
  static String translatePOS(String pos) {
    final lower = pos.toLowerCase().trim();
    return partOfSpeech[lower] ?? pos;
  }

  /// Traduce idioma.
  static String translateLanguage(String lang) {
    final lower = lang.toLowerCase().trim();
    return language[lower] ?? lang;
  }

  /// Traduce testamento.
  static String translateTestament(String test) {
    return testament[test] ?? test;
  }

  /// Mapa de nombres de libro internos (español) → códigos BLB (inglés).
  /// BLB usa abreviaciones como "Gen", "Exo", "Lev", etc.
  static const Map<String, String> bookToBLBCode = {
    'génesis': 'Gen',
    'genesis': 'Gen',
    'éxodo': 'Exo',
    'exodo': 'Exo',
    'levítico': 'Lev',
    'levitico': 'Lev',
    'números': 'Num',
    'numeros': 'Num',
    'deuteronomio': 'Deu',
    'josué': 'Jos',
    'josue': 'Jos',
    'jueces': 'Jdg',
    'rut': 'Rth',
    'ruth': 'Rth',
    '1 samuel': '1Sa',
    '2 samuel': '2Sa',
    '1 reyes': '1Ki',
    '2 reyes': '2Ki',
    '1 crónicas': '1Ch',
    '1 cronicas': '1Ch',
    '2 crónicas': '2Ch',
    '2 cronicas': '2Ch',
    'esdras': 'Ezr',
    'nehemías': 'Neh',
    'nehemias': 'Neh',
    'ester': 'Est',
    'job': 'Job',
    'salmos': 'Psa',
    'proverbios': 'Pro',
    'eclesiastés': 'Ecc',
    'eclesiastes': 'Ecc',
    'cantares': 'Sol',
    'cantar de los cantares': 'Sol',
    'isaías': 'Isa',
    'isaias': 'Isa',
    'jeremías': 'Jer',
    'jeremias': 'Jer',
    'lamentaciones': 'Lam',
    'ezequiel': 'Eze',
    'daniel': 'Dan',
    'oseas': 'Hos',
    'joel': 'Joe',
    'amós': 'Amo',
    'amos': 'Amo',
    'abdías': 'Oba',
    'abdias': 'Oba',
    'jonás': 'Jon',
    'jonas': 'Jon',
    'miqueas': 'Mic',
    'nahúm': 'Nah',
    'nahum': 'Nah',
    'habacuc': 'Hab',
    'sofonías': 'Zep',
    'sofonias': 'Zep',
    'hageo': 'Hag',
    'zacarías': 'Zec',
    'zacarias': 'Zec',
    'malaquías': 'Mal',
    'malaquias': 'Mal',
    // Nuevo Testamento
    'mateo': 'Mat',
    'marcos': 'Mar',
    'lucas': 'Luk',
    'juan': 'Jhn',
    'hechos': 'Act',
    'romanos': 'Rom',
    '1 corintios': '1Co',
    '2 corintios': '2Co',
    'gálatas': 'Gal',
    'galatas': 'Gal',
    'efesios': 'Eph',
    'filipenses': 'Phl',
    'colosenses': 'Col',
    '1 tesalonicenses': '1Th',
    '2 tesalonicenses': '2Th',
    '1 timoteo': '1Ti',
    '2 timoteo': '2Ti',
    'tito': 'Tit',
    'filemón': 'Phm',
    'filemon': 'Phm',
    'hebreos': 'Heb',
    'santiago': 'Jas',
    '1 pedro': '1Pe',
    '2 pedro': '2Pe',
    '1 juan': '1Jo',
    '2 juan': '2Jo',
    '3 juan': '3Jo',
    'judas': 'Jud',
    'apocalipsis': 'Rev',
  };

  /// Convierte nombre de libro en español a código BLB.
  /// Intenta normalización básica (minúsculas, sin acentos).
  static String? getBookCode(String bookName) {
    final lower = bookName.toLowerCase().trim();
    return bookToBLBCode[lower];
  }

  /// Mapa de bookNumber (1-66) a código BLB.
  static const Map<int, String> bookNumberToBLBCode = {
    1: 'Gen', 2: 'Exo', 3: 'Lev', 4: 'Num', 5: 'Deu',
    6: 'Jos', 7: 'Jdg', 8: 'Rth', 9: '1Sa', 10: '2Sa',
    11: '1Ki', 12: '2Ki', 13: '1Ch', 14: '2Ch', 15: 'Ezr',
    16: 'Neh', 17: 'Est', 18: 'Job', 19: 'Psa', 20: 'Pro',
    21: 'Ecc', 22: 'Sol', 23: 'Isa', 24: 'Jer', 25: 'Lam',
    26: 'Eze', 27: 'Dan', 28: 'Hos', 29: 'Joe', 30: 'Amo',
    31: 'Oba', 32: 'Jon', 33: 'Mic', 34: 'Nah', 35: 'Hab',
    36: 'Zep', 37: 'Hag', 38: 'Zec', 39: 'Mal',
    40: 'Mat', 41: 'Mar', 42: 'Luk', 43: 'Jhn', 44: 'Act',
    45: 'Rom', 46: '1Co', 47: '2Co', 48: 'Gal', 49: 'Eph',
    50: 'Phl', 51: 'Col', 52: '1Th', 53: '2Th', 54: '1Ti',
    55: '2Ti', 56: 'Tit', 57: 'Phm', 58: 'Heb', 59: 'Jas',
    60: '1Pe', 61: '2Pe', 62: '1Jo', 63: '2Jo', 64: '3Jo',
    65: 'Jud', 66: 'Rev',
  };

  /// Mapa inverso: código BLB → bookNumber.
  static final Map<String, int> blbCodeToBookNumber = {
    for (final e in bookNumberToBLBCode.entries) e.value: e.key,
  };
}
