class StrongLexiconEntry {
  final String strongNumber;
  final String lemma;
  final String transliteration;
  final String pronunciation;
  final String derivation;
  final String definition;
  final String biblicalUsage;

  const StrongLexiconEntry({
    required this.strongNumber,
    required this.lemma,
    required this.transliteration,
    required this.pronunciation,
    required this.derivation,
    required this.definition,
    required this.biblicalUsage,
  });

  factory StrongLexiconEntry.fromCompactJson(
    String strongNumber,
    Map<String, dynamic> json,
  ) {
    return StrongLexiconEntry(
      strongNumber: strongNumber,
      lemma: json['w']?.toString() ?? '',
      transliteration: json['x']?.toString() ?? '',
      pronunciation: json['p']?.toString() ?? '',
      derivation: json['o']?.toString() ?? '',
      definition: json['d']?.toString() ?? '',
      biblicalUsage: json['u']?.toString() ?? '',
    );
  }
}

class OriginalWordReference {
  final int bookNumber;
  final int chapter;
  final int verse;

  const OriginalWordReference({
    required this.bookNumber,
    required this.chapter,
    required this.verse,
  });

  factory OriginalWordReference.fromPacked(int packed) {
    final book = packed ~/ 1000000;
    final remainder = packed % 1000000;
    return OriginalWordReference(
      bookNumber: book,
      chapter: remainder ~/ 1000,
      verse: remainder % 1000,
    );
  }
}

class OriginalWordSearchResult {
  final String query;
  final String displayWord;
  final String lemma;
  final List<String> strongNumbers;
  final List<StrongLexiconEntry> lexiconEntries;
  final List<OriginalWordReference> references;

  const OriginalWordSearchResult({
    required this.query,
    required this.displayWord,
    required this.lemma,
    required this.strongNumbers,
    required this.lexiconEntries,
    required this.references,
  });

  int get occurrenceCount => references.length;
  bool get hasData => references.isNotEmpty || lexiconEntries.isNotEmpty;
}
