// Modelos para la integración con Blue Letter Bible API.

/// Estado de una respuesta BLB.
enum BLBResultStatus { success, noApiKey, rateLimited, networkError, parseError, noData }

/// Wrapper genérico para respuestas BLB.
class BLBResult<T> {
  final BLBResultStatus status;
  final T? data;
  final String? message;
  final bool fromCache;

  const BLBResult({
    required this.status,
    this.data,
    this.message,
    this.fromCache = false,
  });

  bool get isSuccess => status == BLBResultStatus.success;
}

/// Una palabra individual del texto KJV con posible número Strong.
class BLBWord {
  final String text;
  final String? strongNumber; // e.g. 'H430', 'G2316'
  final String? originalWord; // palabra original (griego/hebreo)
  final String? transliteration;
  final String? partOfSpeech;
  final String? shortDefinition;

  const BLBWord({
    required this.text,
    this.strongNumber,
    this.originalWord,
    this.transliteration,
    this.partOfSpeech,
    this.shortDefinition,
  });

  bool get hasStrong => strongNumber != null && strongNumber!.isNotEmpty;

  /// Idioma basado en el prefijo del número Strong.
  String get language {
    if (strongNumber == null) return '';
    return strongNumber!.startsWith('H') ? 'hebreo' : 'griego';
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'strongNumber': strongNumber,
    'originalWord': originalWord,
    'transliteration': transliteration,
    'partOfSpeech': partOfSpeech,
    'shortDefinition': shortDefinition,
  };

  factory BLBWord.fromJson(Map<String, dynamic> json) => BLBWord(
    text: json['text'] as String? ?? '',
    strongNumber: json['strongNumber'] as String?,
    originalWord: json['originalWord'] as String?,
    transliteration: json['transliteration'] as String?,
    partOfSpeech: json['partOfSpeech'] as String?,
    shortDefinition: json['shortDefinition'] as String?,
  );
}

/// Entrada completa del lexicón para un número Strong.
class BLBLexiconEntry {
  final String strongNumber;
  final String originalWord;
  final String transliteration;
  final String pronunciation;
  final String partOfSpeech;
  final String language; // 'hebrew' o 'greek'
  final String shortDefinition;
  final String fullDefinition;
  final int occurrences;
  final List<String> kjvTranslations;

  const BLBLexiconEntry({
    required this.strongNumber,
    required this.originalWord,
    required this.transliteration,
    this.pronunciation = '',
    required this.partOfSpeech,
    required this.language,
    required this.shortDefinition,
    this.fullDefinition = '',
    this.occurrences = 0,
    this.kjvTranslations = const [],
  });

  Map<String, dynamic> toJson() => {
    'strongNumber': strongNumber,
    'originalWord': originalWord,
    'transliteration': transliteration,
    'pronunciation': pronunciation,
    'partOfSpeech': partOfSpeech,
    'language': language,
    'shortDefinition': shortDefinition,
    'fullDefinition': fullDefinition,
    'occurrences': occurrences,
    'kjvTranslations': kjvTranslations,
  };

  factory BLBLexiconEntry.fromJson(Map<String, dynamic> json) =>
      BLBLexiconEntry(
        strongNumber: json['strongNumber'] as String? ?? '',
        originalWord: json['originalWord'] as String? ?? '',
        transliteration: json['transliteration'] as String? ?? '',
        pronunciation: json['pronunciation'] as String? ?? '',
        partOfSpeech: json['partOfSpeech'] as String? ?? '',
        language: json['language'] as String? ?? '',
        shortDefinition: json['shortDefinition'] as String? ?? '',
        fullDefinition: json['fullDefinition'] as String? ?? '',
        occurrences: json['occurrences'] as int? ?? 0,
        kjvTranslations:
            (json['kjvTranslations'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
      );
}

/// Una referencia cruzada para un versículo.
class BLBCrossReference {
  final String reference; // e.g. 'John 3:16'
  final int bookNumber;
  final int chapter;
  final int verse;
  final String? text; // texto del versículo (KJV o español si disponible)
  final bool isSpanishText; // true si el texto es de RVR1960/NVI

  const BLBCrossReference({
    required this.reference,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    this.text,
    this.isSpanishText = false,
  });

  Map<String, dynamic> toJson() => {
    'reference': reference,
    'bookNumber': bookNumber,
    'chapter': chapter,
    'verse': verse,
    'text': text,
    'isSpanishText': isSpanishText,
  };

  factory BLBCrossReference.fromJson(Map<String, dynamic> json) =>
      BLBCrossReference(
        reference: json['reference'] as String? ?? '',
        bookNumber: json['bookNumber'] as int? ?? 0,
        chapter: json['chapter'] as int? ?? 0,
        verse: json['verse'] as int? ?? 0,
        text: json['text'] as String?,
        isSpanishText: json['isSpanishText'] as bool? ?? false,
      );
}
