import 'dart:math';

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

/// Rango bíblico adicional dentro de un estudio. Permite que un mismo set de
/// respuestas cubra más de un pasaje, incluso en libros/capítulos distintos.
class StudyPassage {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int startVerse;
  final int endVerse;

  const StudyPassage({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
  });

  String get chapterKey => '$bookNumber:$chapter';

  String get reference {
    final name = bookName.trim().isEmpty ? 'Libro $bookNumber' : bookName;
    if (startVerse == endVerse) return '$name $chapter:$startVerse';
    return '$name $chapter:$startVerse-$endVerse';
  }

  List<int> versesInRange() {
    final lo = startVerse < endVerse ? startVerse : endVerse;
    final hi = startVerse < endVerse ? endVerse : startVerse;
    return [for (var v = lo; v <= hi; v++) v];
  }

  bool coversVerse(int bookNumber, int chapter, int verse) {
    if (this.bookNumber != bookNumber || this.chapter != chapter) return false;
    final lo = startVerse < endVerse ? startVerse : endVerse;
    final hi = startVerse < endVerse ? endVerse : startVerse;
    return verse >= lo && verse <= hi;
  }

  Map<String, dynamic> toMap() => {
    'bookNumber': bookNumber,
    'bookName': bookName,
    'chapter': chapter,
    'startVerse': startVerse,
    'endVerse': endVerse,
  };

  factory StudyPassage.fromMap(Map<String, dynamic> map) => StudyPassage(
    bookNumber: _asInt(map['bookNumber']),
    bookName: map['bookName'] as String? ?? '',
    chapter: _asInt(map['chapter']),
    startVerse: _asInt(map['startVerse']),
    endVerse: _asInt(map['endVerse']),
  );
}

class StudyVerseRef {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int verse;

  const StudyVerseRef({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.verse,
  });

  String get key => '$bookNumber:$chapter:$verse';
  String get chapterKey => '$bookNumber:$chapter';
}

/// Respuestas del usuario a las 6 preguntas para un capítulo concreto.
///
/// Documento Firestore en
/// `users/{uid}/studyAnswers/{bookNumber}_{chapter}`.
class StudyChapterAnswers {
  /// Identificador único del estudio. Permite múltiples estudios independientes
  /// del mismo capítulo (cada uno con sus propias notas y rango).
  /// Para documentos legacy (creados antes de esta migración) será null y se
  /// usará un identificador derivado de libro/capítulo para retro-compatibilidad.
  final String? studyId;
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
  final List<StudyPassage> additionalPassages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyChapterAnswers({
    this.studyId,
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
    this.additionalPassages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Genera un studyId único para nuevos estudios.
  static String generateStudyId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(0xFFFFFFFF).toRadixString(36);
    return 'st_${ms.toRadixString(36)}_$rand';
  }

  /// Clave estable para el documento Firestore y la cache local. Para estudios
  /// con studyId la clave es el propio id; para documentos legacy mantenemos
  /// el esquema antiguo `${bookNumber}_${chapter}`.
  String get docId => studyId ?? '${bookNumber}_$chapter';
  String get chapterKey => studyId ?? '$bookNumber:$chapter';
  String get reference {
    final refs = <String>[];
    if (studyStartVerse != null && studyEndVerse != null) {
      if (studyStartVerse == studyEndVerse) {
        refs.add('$bookName $chapter:$studyStartVerse');
      } else {
        refs.add('$bookName $chapter:$studyStartVerse-$studyEndVerse');
      }
    } else {
      refs.add('$bookName $chapter');
    }
    refs.addAll(additionalPassages.map((p) => p.reference));
    return refs.join(' + ');
  }

  StudyPassage? get primaryPassage {
    final s = studyStartVerse;
    final e = studyEndVerse;
    if (s == null || e == null) return null;
    return StudyPassage(
      bookNumber: bookNumber,
      bookName: bookName,
      chapter: chapter,
      startVerse: s,
      endVerse: e,
    );
  }

  List<StudyPassage> get rangedPassages {
    final primary = primaryPassage;
    return List.unmodifiable([?primary, ...additionalPassages]);
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

  List<StudyVerseRef> verseRefsInStudy() {
    final refs = <StudyVerseRef>[];
    for (final passage in rangedPassages) {
      for (final verse in passage.versesInRange()) {
        refs.add(
          StudyVerseRef(
            bookNumber: passage.bookNumber,
            bookName: passage.bookName,
            chapter: passage.chapter,
            verse: verse,
          ),
        );
      }
    }
    return List.unmodifiable(refs);
  }

  bool coversVerse(int bookNumber, int chapter, int verse) {
    return rangedPassages.any((passage) => passage.coversVerse(bookNumber, chapter, verse));
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
    String? studyId,
    String? versionId,
    Map<String, String>? answers,
    String? generalNotes,
    String? hopeMessage,
    List<int>? mainVerses,
    int? studyStartVerse,
    int? studyEndVerse,
    List<StudyPassage>? additionalPassages,
    bool clearRange = false,
    bool clearAdditionalPassages = false,
    DateTime? updatedAt,
  }) => StudyChapterAnswers(
    studyId: studyId ?? this.studyId,
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
    additionalPassages: clearAdditionalPassages
        ? const []
        : (additionalPassages ?? this.additionalPassages),
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
    if (studyId != null) 'studyId': studyId,
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
    if (additionalPassages.isNotEmpty)
      'additionalPassages': additionalPassages.map((p) => p.toMap()).toList(),
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
      studyId: map['studyId'] as String?,
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
      additionalPassages: _parsePassages(map['additionalPassages']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory StudyChapterAnswers.empty({
    required int bookNumber,
    required String bookName,
    required int chapter,
    required String versionId,
    String? studyId,
  }) {
    final now = DateTime.now();
    return StudyChapterAnswers(
      studyId: studyId ?? generateStudyId(),
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

List<StudyPassage> _parsePassages(Object? raw) {
  if (raw is! Iterable) return const [];
  final passages = <StudyPassage>[];
  for (final item in raw) {
    if (item is Map) {
      try {
        passages.add(StudyPassage.fromMap(Map<String, dynamic>.from(item)));
      } catch (_) {}
    }
  }
  return List.unmodifiable(passages);
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
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
