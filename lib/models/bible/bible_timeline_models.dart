/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE TIMELINE MODELS
/// Períodos, eventos y personajes para la línea de tiempo bíblica.
/// ═══════════════════════════════════════════════════════════════════════════
library;

/// Período histórico bíblico
class TimelinePeriod {
  final String id;
  final String name;
  final String description;
  final int yearStart; // Negativo = AC
  final int yearEnd;
  final String colorHex;
  final List<String> keyBooks; // Números de libro

  const TimelinePeriod({
    required this.id,
    required this.name,
    required this.description,
    required this.yearStart,
    required this.yearEnd,
    required this.colorHex,
    this.keyBooks = const [],
  });

  int get durationYears => (yearEnd - yearStart).abs();
  String get yearRange => '${_formatYear(yearStart)} – ${_formatYear(yearEnd)}';

  static String _formatYear(int year) =>
      year < 0 ? '${year.abs()} a.C.' : '$year d.C.';

  factory TimelinePeriod.fromJson(Map<String, dynamic> j) => TimelinePeriod(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        yearStart: j['yearStart'] as int,
        yearEnd: j['yearEnd'] as int,
        colorHex: j['colorHex'] as String? ?? 'D4A853',
        keyBooks: (j['keyBooks'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

/// Evento bíblico puntual
class TimelineEvent {
  final String id;
  final String title;
  final String description;
  final int year;
  final String periodId;
  final String? iconName; // Material icon name
  final List<TimelineReference> references;
  final List<String> characterIds;

  const TimelineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.year,
    required this.periodId,
    this.iconName,
    this.references = const [],
    this.characterIds = const [],
  });

  String get yearFormatted =>
      year < 0 ? '${year.abs()} a.C.' : '$year d.C.';

  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String? ?? '',
        year: j['year'] as int,
        periodId: j['periodId'] as String,
        iconName: j['iconName'] as String?,
        references: (j['references'] as List<dynamic>?)
                ?.map((e) => TimelineReference.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        characterIds: (j['characterIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

/// Personaje bíblico
class TimelineCharacter {
  final String id;
  final String name;
  final String description;
  final int? birthYear;
  final int? deathYear;
  final String periodId;
  final List<TimelineReference> references;
  final List<String> roles; // patriarca, rey, profeta, apóstol, etc.

  const TimelineCharacter({
    required this.id,
    required this.name,
    required this.description,
    this.birthYear,
    this.deathYear,
    required this.periodId,
    this.references = const [],
    this.roles = const [],
  });

  String get lifespan {
    if (birthYear == null) return '';
    final b = TimelinePeriod._formatYear(birthYear!);
    if (deathYear == null) return b;
    return '$b – ${TimelinePeriod._formatYear(deathYear!)}';
  }

  factory TimelineCharacter.fromJson(Map<String, dynamic> j) =>
      TimelineCharacter(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        birthYear: j['birthYear'] as int?,
        deathYear: j['deathYear'] as int?,
        periodId: j['periodId'] as String,
        references: (j['references'] as List<dynamic>?)
                ?.map((e) => TimelineReference.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        roles: (j['roles'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

/// Referencia bíblica asociada a evento/personaje
class TimelineReference {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int? verse;

  const TimelineReference({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    this.verse,
  });

  String get display =>
      verse != null ? '$bookName $chapter:$verse' : '$bookName $chapter';

  factory TimelineReference.fromJson(Map<String, dynamic> j) =>
      TimelineReference(
        bookNumber: j['bookNumber'] as int,
        bookName: j['bookName'] as String,
        chapter: j['chapter'] as int,
        verse: j['verse'] as int?,
      );
}
