/// Versículo bíblico con referencia completa.
class BibleVerse {
  final String bookName;
  final int bookNumber;
  final int chapter;
  final int verse;
  final String text;
  final String version; // 'RVR1960', 'NVI', etc.

  const BibleVerse({
    required this.bookName,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.version,
  });

  /// Referencia legible: "Génesis 1:1"
  String get reference => '$bookName $chapter:$verse';

  /// Clave única para identificar este versículo (sin versión)
  String get uniqueKey => '$bookNumber:$chapter:$verse';

  /// Clave con versión incluida
  String get fullKey => '$version:$bookNumber:$chapter:$verse';

  @override
  String toString() => '$reference ($version)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleVerse &&
          bookNumber == other.bookNumber &&
          chapter == other.chapter &&
          verse == other.verse &&
          version == other.version;

  @override
  int get hashCode => Object.hash(bookNumber, chapter, verse, version);
}
