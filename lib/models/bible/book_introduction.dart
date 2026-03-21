/// Modelo para introducciones de libros bíblicos.
library;

class BookIntroduction {
  final int bookNumber;
  final String name;
  final String author;
  final String authorDetails;
  final String writtenDate;
  final String period;
  final String audience;
  final String purpose;
  final List<String> keyThemes;
  final List<String> keyVerses;
  final String historicalContext;
  final List<BookSection> structure;
  final Map<int, String> chapterIntros; // chapter -> intro text
  final List<String> maps; // map IDs

  const BookIntroduction({
    required this.bookNumber,
    required this.name,
    required this.author,
    this.authorDetails = '',
    this.writtenDate = '',
    this.period = '',
    this.audience = '',
    this.purpose = '',
    this.keyThemes = const [],
    this.keyVerses = const [],
    this.historicalContext = '',
    this.structure = const [],
    this.chapterIntros = const {},
    this.maps = const [],
  });

  factory BookIntroduction.fromJson(Map<String, dynamic> json) {
    return BookIntroduction(
      bookNumber: json['bookNumber'] as int,
      name: json['name'] as String,
      author: json['author'] as String? ?? '',
      authorDetails: json['authorDetails'] as String? ?? '',
      writtenDate: json['writtenDate'] as String? ?? '',
      period: json['period'] as String? ?? '',
      audience: json['audience'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      keyThemes: (json['keyThemes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      keyVerses: (json['keyVerses'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      historicalContext: json['historicalContext'] as String? ?? '',
      structure: (json['structure'] as List?)
              ?.map((e) => BookSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      chapterIntros: _parseChapterIntros(json['chapterIntros']),
      maps:
          (json['maps'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  static Map<int, String> _parseChapterIntros(dynamic data) {
    if (data == null || data is! Map) return {};
    final result = <int, String>{};
    for (final entry in data.entries) {
      result[int.parse(entry.key.toString())] = entry.value.toString();
    }
    return result;
  }
}

class BookSection {
  final String chapters;
  final String title;

  const BookSection({required this.chapters, required this.title});

  factory BookSection.fromJson(Map<String, dynamic> json) {
    return BookSection(
      chapters: json['chapters'] as String,
      title: json['title'] as String,
    );
  }
}
