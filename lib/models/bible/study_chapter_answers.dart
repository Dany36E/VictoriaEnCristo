import 'package:cloud_firestore/cloud_firestore.dart';

/// IDs estables de las 6 preguntas del método inductivo del Modo Estudio.
/// Mantén este orden — la UI depende de él.
class StudyQuestion {
  final String id;
  final String prompt;
  final String hint;
  const StudyQuestion(this.id, this.prompt, this.hint);
}

const List<StudyQuestion> kStudyQuestions = [
  StudyQuestion(
    'about_god',
    '¿Qué dice el texto sobre Dios / Jesús?',
    'Atributos, acciones, promesas, voluntad revelada.',
  ),
  StudyQuestion(
    'about_people',
    '¿Qué dice el texto de los personajes?',
    'Reacciones, virtudes, errores, transformación.',
  ),
  StudyQuestion(
    'application',
    '¿Cómo puedo aplicarlo a mi vida?',
    'Una acción concreta para esta semana.',
  ),
  StudyQuestion(
    'author_speaker',
    '¿Quién lo escribió? ¿Quién está hablando?',
    'Autor humano, audiencia original, voz que habla.',
  ),
  StudyQuestion('place', '¿Dónde suceden los hechos?', 'Ciudad, región, geografía relevante.'),
  StudyQuestion(
    'context',
    '¿Qué estaba sucediendo? ¿Por qué?',
    'Contexto histórico, cultural y literario.',
  ),
];

/// Respuestas del usuario a las 6 preguntas para un capítulo concreto.
///
/// Documento Firestore en
/// `users/{uid}/studyAnswers/{bookNumber}_{chapter}`.
class StudyChapterAnswers {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final String versionId;
  final Map<String, String> answers; // questionId -> texto
  final String generalNotes;
  final String hopeMessage;
  final List<int> mainVerses;

  /// Versículo inicial del rango estudiado (1-based, inclusive). Null = capítulo completo.
  final int? studyStartVerse;

  /// Versículo final del rango estudiado (1-based, inclusive). Null = capítulo completo.
  final int? studyEndVerse;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyChapterAnswers({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.versionId,
    required this.answers,
    this.generalNotes = '',
    this.hopeMessage = '',
    this.mainVerses = const [],
    this.studyStartVerse,
    this.studyEndVerse,
    required this.createdAt,
    required this.updatedAt,
  });

  String get docId => '${bookNumber}_$chapter';
  String get chapterKey => '$bookNumber:$chapter';
  String get reference {
    if (studyStartVerse != null && studyEndVerse != null) {
      if (studyStartVerse == studyEndVerse) {
        return '$bookName $chapter:$studyStartVerse';
      }
      return '$bookName $chapter:$studyStartVerse-$studyEndVerse';
    }
    return '$bookName $chapter';
  }

  /// Lista de versículos cubiertos por el rango (vacío si no hay rango).
  List<int> versesInRange() {
    final s = studyStartVerse;
    final e = studyEndVerse;
    if (s == null || e == null) return const [];
    final lo = s < e ? s : e;
    final hi = s < e ? e : s;
    return [for (var v = lo; v <= hi; v++) v];
  }

  List<int> get sortedMainVerses => _normalizedVerseNumbers(mainVerses);

  String get mainVerseReference {
    final ranges = verseRangesLabel(mainVerses);
    if (ranges.isEmpty) return '';
    return '$bookName $chapter:$ranges';
  }

  static String verseRangesLabel(Iterable<int> verses) => _formatVerseRanges(verses);

  /// ¿Hay al menos una respuesta o nota no vacía?
  bool get hasContent =>
      answers.values.any((v) => v.trim().isNotEmpty) ||
      generalNotes.trim().isNotEmpty ||
      hopeMessage.trim().isNotEmpty ||
      sortedMainVerses.isNotEmpty;

  StudyChapterAnswers copyWith({
    String? versionId,
    Map<String, String>? answers,
    String? generalNotes,
    String? hopeMessage,
    List<int>? mainVerses,
    int? studyStartVerse,
    int? studyEndVerse,
    bool clearRange = false,
    DateTime? updatedAt,
  }) => StudyChapterAnswers(
    bookNumber: bookNumber,
    bookName: bookName,
    chapter: chapter,
    versionId: versionId ?? this.versionId,
    answers: answers ?? this.answers,
    generalNotes: generalNotes ?? this.generalNotes,
    hopeMessage: hopeMessage ?? this.hopeMessage,
    mainVerses: mainVerses ?? this.mainVerses,
    studyStartVerse: clearRange ? null : (studyStartVerse ?? this.studyStartVerse),
    studyEndVerse: clearRange ? null : (studyEndVerse ?? this.studyEndVerse),
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  /// Markdown consolidado para sincronizar a la sección "Notas".
  String toMarkdown() {
    final buf = StringBuffer();
    for (final q in kStudyQuestions) {
      final a = answers[q.id]?.trim() ?? '';
      if (a.isEmpty) continue;
      buf.writeln('**${q.prompt}**');
      buf.writeln(a);
      buf.writeln();
    }
    final hope = hopeMessage.trim();
    if (hope.isNotEmpty) {
      buf.writeln('**Mensaje de esperanza**');
      buf.writeln(hope);
      buf.writeln();
    }
    final mainReference = mainVerseReference;
    if (mainReference.isNotEmpty) {
      buf.writeln('**Verso Principal**');
      buf.writeln(mainReference);
      buf.writeln();
    }
    final notes = generalNotes.trim();
    if (notes.isNotEmpty) {
      buf.writeln('**Notas generales**');
      buf.writeln(notes);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  Map<String, dynamic> toMap() => {
    'bookNumber': bookNumber,
    'bookName': bookName,
    'chapter': chapter,
    'versionId': versionId,
    'answers': answers,
    'generalNotes': generalNotes,
    'hopeMessage': hopeMessage,
    'mainVerses': sortedMainVerses,
    if (studyStartVerse != null) 'studyStartVerse': studyStartVerse,
    if (studyEndVerse != null) 'studyEndVerse': studyEndVerse,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory StudyChapterAnswers.fromMap(Map<String, dynamic> map) {
    final raw = map['answers'];
    final parsed = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is String) parsed[k.toString()] = v;
      });
    }
    return StudyChapterAnswers(
      bookNumber: map['bookNumber'] as int,
      bookName: map['bookName'] as String? ?? '',
      chapter: map['chapter'] as int,
      versionId: map['versionId'] as String? ?? 'RVR1960',
      answers: parsed,
      generalNotes: map['generalNotes'] as String? ?? '',
      hopeMessage: map['hopeMessage'] as String? ?? '',
      mainVerses: _parseVerseNumbers(map['mainVerses']),
      studyStartVerse: (map['studyStartVerse'] as num?)?.toInt(),
      studyEndVerse: (map['studyEndVerse'] as num?)?.toInt(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory StudyChapterAnswers.empty({
    required int bookNumber,
    required String bookName,
    required int chapter,
    required String versionId,
  }) {
    final now = DateTime.now();
    return StudyChapterAnswers(
      bookNumber: bookNumber,
      bookName: bookName,
      chapter: chapter,
      versionId: versionId,
      answers: const {},
      generalNotes: '',
      hopeMessage: '',
      mainVerses: const [],
      createdAt: now,
      updatedAt: now,
    );
  }
}

List<int> _parseVerseNumbers(Object? raw) {
  if (raw is! Iterable) return const [];
  final numbers = <int>[];
  for (final value in raw) {
    if (value is num) {
      numbers.add(value.toInt());
    }
  }
  return _normalizedVerseNumbers(numbers);
}

List<int> _normalizedVerseNumbers(Iterable<int> verses) {
  final out = verses.where((v) => v > 0).toSet().toList()..sort();
  return List.unmodifiable(out);
}

String _formatVerseRanges(Iterable<int> verses) {
  final sorted = _normalizedVerseNumbers(verses);
  if (sorted.isEmpty) return '';
  final ranges = <String>[];
  var start = sorted.first;
  var previous = start;

  void closeRange() {
    ranges.add(start == previous ? '$start' : '$start-$previous');
  }

  for (final verse in sorted.skip(1)) {
    if (verse == previous + 1) {
      previous = verse;
      continue;
    }
    closeRange();
    start = verse;
    previous = verse;
  }
  closeRange();
  return ranges.join(', ');
}
