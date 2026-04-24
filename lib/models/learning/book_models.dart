/// Modelos para "Los 66 Libros" — biblioteca bíblica.
library;

class BibleBook {
  final String id;
  final int order; // 1..66
  final String name;
  final String testament; // 'AT' | 'NT'
  final String category; // Pentateuco, Históricos, Poéticos, etc.
  final int chapters;
  final String author;
  final String date; // época aproximada
  final String theme; // 1 frase
  final String keyVerse;
  final String keyVerseRef;
  final String summary; // 2-3 oraciones
  final int xpReward;

  BibleBook({
    required this.id,
    required this.order,
    required this.name,
    required this.testament,
    required this.category,
    required this.chapters,
    required this.author,
    required this.date,
    required this.theme,
    required this.keyVerse,
    required this.keyVerseRef,
    required this.summary,
    required this.xpReward,
  });

  factory BibleBook.fromJson(Map<String, dynamic> j) => BibleBook(
        id: j['id'] as String,
        order: j['order'] as int,
        name: j['name'] as String,
        testament: j['testament'] as String,
        category: j['category'] as String,
        chapters: j['chapters'] as int,
        author: j['author'] as String? ?? '—',
        date: j['date'] as String? ?? '—',
        theme: j['theme'] as String? ?? '',
        keyVerse: j['keyVerse'] as String? ?? '',
        keyVerseRef: j['keyVerseRef'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        xpReward: j['xpReward'] as int? ?? 15,
      );
}
