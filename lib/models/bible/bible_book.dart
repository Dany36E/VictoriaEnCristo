// ─────────────────────────────────────────────────────────────────────────────
// GÉNERO LITERARIO
// Clasificación hermenéutica de los libros bíblicos.
// El género determina cómo leer e interpretar el texto:
//   - Ley: mandamientos, estatutos (contexto: pacto mosaico)
//   - Historia: narrativa histórico-teológica
//   - Poesía: paralelismo hebreo, metáfora, emoción elevada
//   - Profecía: anuncio de juicio/salvación, contexto histórico crítico
//   - Evangelio: biografía teológica de Jesús
//   - Epístola: carta pastoral con aplicación doctrinal directa
//   - Apocalíptico: visión simbólica, no literal-directo
// ─────────────────────────────────────────────────────────────────────────────
enum BibleGenre {
  pentateuco,
  historico,
  poetico,
  profeta,
  evangelio,
  historia,  // Hechos
  epistola,
  apocaliptico,
}

extension BibleGenreInfo on BibleGenre {
  String get label {
    switch (this) {
      case BibleGenre.pentateuco:   return 'Ley';
      case BibleGenre.historico:    return 'Historia';
      case BibleGenre.poetico:      return 'Sabiduría';
      case BibleGenre.profeta:      return 'Profecía';
      case BibleGenre.evangelio:    return 'Evangelio';
      case BibleGenre.historia:     return 'Historia';
      case BibleGenre.epistola:     return 'Epístola';
      case BibleGenre.apocaliptico: return 'Profecía';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIONES CANÓNICAS
// Las 10 secciones clásicas del canon protestante español.
// ─────────────────────────────────────────────────────────────────────────────
class BibleCanonSection {
  final String name;
  final String description;
  final int firstBook;
  final int lastBook;
  final BibleGenre genre;

  const BibleCanonSection({
    required this.name,
    required this.description,
    required this.firstBook,
    required this.lastBook,
    required this.genre,
  });
}

const List<BibleCanonSection> bibleCanonSections = [
  BibleCanonSection(
    name: 'Pentateuco',
    description: 'Ley de Moisés · Génesis–Deuteronomio',
    firstBook: 1, lastBook: 5, genre: BibleGenre.pentateuco,
  ),
  BibleCanonSection(
    name: 'Libros Históricos',
    description: 'Historia del pueblo de Israel',
    firstBook: 6, lastBook: 17, genre: BibleGenre.historico,
  ),
  BibleCanonSection(
    name: 'Libros Poéticos',
    description: 'Poesía, sabiduría y adoración',
    firstBook: 18, lastBook: 22, genre: BibleGenre.poetico,
  ),
  BibleCanonSection(
    name: 'Profetas Mayores',
    description: 'Isaías, Jeremías, Ezequiel, Daniel',
    firstBook: 23, lastBook: 27, genre: BibleGenre.profeta,
  ),
  BibleCanonSection(
    name: 'Profetas Menores',
    description: 'Los doce profetas · Oseas–Malaquías',
    firstBook: 28, lastBook: 39, genre: BibleGenre.profeta,
  ),
  BibleCanonSection(
    name: 'Evangelios',
    description: 'La vida y obra de Jesucristo',
    firstBook: 40, lastBook: 43, genre: BibleGenre.evangelio,
  ),
  BibleCanonSection(
    name: 'Historia Apostólica',
    description: 'El libro de los Hechos',
    firstBook: 44, lastBook: 44, genre: BibleGenre.historia,
  ),
  BibleCanonSection(
    name: 'Cartas de Pablo',
    description: 'Romanos–Filemón',
    firstBook: 45, lastBook: 57, genre: BibleGenre.epistola,
  ),
  BibleCanonSection(
    name: 'Epístolas Generales',
    description: 'Hebreos–Judas',
    firstBook: 58, lastBook: 65, genre: BibleGenre.epistola,
  ),
  BibleCanonSection(
    name: 'Profecía Apocalíptica',
    description: 'El libro del Apocalipsis',
    firstBook: 66, lastBook: 66, genre: BibleGenre.apocaliptico,
  ),
];

/// Modelo de un libro bíblico con sus capítulos y versículos.
class BibleBook {
  final int number;
  final String name;
  final String testament; // 'AT' | 'NT'
  final int totalChapters;
  final Map<int, int> versesPerChapter; // {capítulo: totalVersículos}

  const BibleBook({
    required this.number,
    required this.name,
    required this.testament,
    required this.totalChapters,
    required this.versesPerChapter,
  });

  /// Abreviatura del libro (primeras 3 letras)
  String get abbreviation {
    if (name.length <= 3) return name;
    // Manejar libros con número (1 Juan, 2 Pedro, etc.)
    if (name.startsWith(RegExp(r'\d\s'))) {
      return '${name[0]}${name.substring(2, 2 + 2)}';
    }
    return name.substring(0, 3);
  }

  /// Sección canónica a la que pertenece este libro.
  BibleCanonSection get canonSection => bibleCanonSections
      .firstWhere((s) => number >= s.firstBook && number <= s.lastBook,
          orElse: () => bibleCanonSections.first);

  /// Género literario del libro (para hermenéutica).
  BibleGenre get genre => canonSection.genre;

  @override
  String toString() => 'BibleBook($number: $name, $testament, $totalChapters caps)';
}
