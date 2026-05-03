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
  StudyQuestion(
    'place',
    '¿Dónde suceden los hechos?',
    'Ciudad, región, geografía relevante.',
  ),
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

  /// ¿Hay al menos una respuesta no vacía?
  bool get hasContent => answers.values.any((v) => v.trim().isNotEmpty);

  StudyChapterAnswers copyWith({
    Map<String, String>? answers,
    int? studyStartVerse,
    int? studyEndVerse,
    bool clearRange = false,
    DateTime? updatedAt,
  }) =>
      StudyChapterAnswers(
        bookNumber: bookNumber,
        bookName: bookName,
        chapter: chapter,
        versionId: versionId,
        answers: answers ?? this.answers,
        studyStartVerse:
            clearRange ? null : (studyStartVerse ?? this.studyStartVerse),
        studyEndVerse:
            clearRange ? null : (studyEndVerse ?? this.studyEndVerse),
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
    return buf.toString().trimRight();
  }

  Map<String, dynamic> toMap() => {
        'bookNumber': bookNumber,
        'bookName': bookName,
        'chapter': chapter,
        'versionId': versionId,
        'answers': answers,
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
      studyStartVerse: (map['studyStartVerse'] as num?)?.toInt(),
      studyEndVerse: (map['studyEndVerse'] as num?)?.toInt(),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      createdAt: now,
      updatedAt: now,
    );
  }
}
