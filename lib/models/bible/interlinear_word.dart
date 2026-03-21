/// Modelo para datos interlineales (griego/hebreo).
library;

class InterlinearWord {
  final int position;
  final String originalWord;    // "Οὕτως" o "בְּרֵאשִׁית"
  final String? lemma;          // forma del diccionario
  final String? strongNumber;   // "G3779" o "H7225"
  final String morphCode;       // código de morfología
  final String gloss;           // significado breve en inglés
  final MorphAnalysis? morphAnalysis;

  const InterlinearWord({
    required this.position,
    required this.originalWord,
    this.lemma,
    this.strongNumber,
    required this.morphCode,
    this.gloss = '',
    this.morphAnalysis,
  });

  bool get hasStrong => strongNumber != null && strongNumber!.isNotEmpty;
}

class InterlinearVerse {
  final String bookCode;
  final int chapter;
  final int verse;
  final List<InterlinearWord> words;

  const InterlinearVerse({
    required this.bookCode,
    required this.chapter,
    required this.verse,
    required this.words,
  });
}

/// Análisis morfológico decodificado.
class MorphAnalysis {
  final String partOfSpeech;        // "Verbo"
  final String? tense;              // "Aoristo"
  final String? voice;              // "Activa"
  final String? mood;               // "Indicativo"
  final String? person;             // "3ra persona"
  final String? grammaticalNumber;  // "Singular"
  final String? gender;             // "Masculino"
  final String? grammaticalCase;    // "Nominativo"

  const MorphAnalysis({
    required this.partOfSpeech,
    this.tense,
    this.voice,
    this.mood,
    this.person,
    this.grammaticalNumber,
    this.gender,
    this.grammaticalCase,
  });

  /// Resumen como string legible.
  String get summary {
    final parts = <String>[partOfSpeech];
    if (tense != null) parts.add(tense!);
    if (voice != null) parts.add(voice!);
    if (mood != null) parts.add(mood!);
    if (person != null) parts.add(person!);
    if (grammaticalNumber != null) parts.add(grammaticalNumber!);
    if (gender != null) parts.add(gender!);
    if (grammaticalCase != null) parts.add(grammaticalCase!);
    return parts.join(' · ');
  }
}
