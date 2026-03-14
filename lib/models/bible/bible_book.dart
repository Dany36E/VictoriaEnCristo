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

  @override
  String toString() => 'BibleBook($number: $name, $testament, $totalChapters caps)';
}
