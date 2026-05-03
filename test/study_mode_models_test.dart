import 'package:flutter_test/flutter_test.dart';
import 'package:app_quitar/models/bible/study_chapter_answers.dart';
import 'package:app_quitar/models/bible/study_word_highlight.dart';

void main() {
  group('StudyHighlightCode', () {
    test('roundtrip de claves conocidas', () {
      for (final code in StudyHighlightCode.values) {
        expect(StudyHighlightCode.fromKey(code.key), code);
      }
    });

    test('clave desconocida cae en yellow', () {
      expect(StudyHighlightCode.fromKey('purple'), StudyHighlightCode.yellow);
      expect(StudyHighlightCode.fromKey(null), StudyHighlightCode.yellow);
    });

    test('los 4 colores requeridos están presentes', () {
      final keys = StudyHighlightCode.values.map((c) => c.key).toSet();
      expect(keys, containsAll(<String>{'red', 'green', 'blue', 'yellow'}));
    });
  });

  group('StudyWordHighlight', () {
    final h = StudyWordHighlight(
      id: 'abc',
      bookNumber: 1,
      chapter: 1,
      verse: 1,
      startWord: 2,
      endWord: 5,
      code: 'red',
      createdAt: DateTime(2025, 1, 1),
    );

    test('overlapsWord respeta rango [start, end)', () {
      expect(h.overlapsWord(1), isFalse);
      expect(h.overlapsWord(2), isTrue);
      expect(h.overlapsWord(4), isTrue);
      expect(h.overlapsWord(5), isFalse);
    });

    test('verseKey y chapterKey', () {
      expect(h.verseKey, '1:1:1');
      expect(h.chapterKey, '1:1');
    });

    test('codeEnum mapea correctamente', () {
      expect(h.codeEnum, StudyHighlightCode.red);
    });
  });

  group('StudyChapterAnswers', () {
    test('hasContent es false para mapa vacío', () {
      final a = StudyChapterAnswers.empty(
        bookNumber: 1,
        bookName: 'Génesis',
        chapter: 1,
        versionId: 'RVR1960',
      );
      expect(a.hasContent, isFalse);
    });

    test('hasContent es true cuando hay al menos una respuesta', () {
      final a = StudyChapterAnswers.empty(
        bookNumber: 1,
        bookName: 'Génesis',
        chapter: 1,
        versionId: 'RVR1960',
      ).copyWith(answers: {'about_god': 'Dios crea con su palabra.'});
      expect(a.hasContent, isTrue);
    });

    test('toMarkdown omite respuestas vacías y respeta orden de preguntas', () {
      final a = StudyChapterAnswers.empty(
        bookNumber: 43,
        bookName: 'Juan',
        chapter: 1,
        versionId: 'RVR1960',
      ).copyWith(answers: {
        'application': 'Confiar en la Palabra hoy.',
        'about_god': 'El Verbo es Dios.',
        '': 'ignorar',
      });
      final md = a.toMarkdown();
      // about_god va primero según orden canónico
      expect(md.indexOf('El Verbo es Dios.'),
          lessThan(md.indexOf('Confiar en la Palabra hoy.')));
      expect(md.contains('ignorar'), isFalse);
    });

    test('docId y chapterKey', () {
      final a = StudyChapterAnswers.empty(
        bookNumber: 19,
        bookName: 'Salmos',
        chapter: 23,
        versionId: 'RVR1960',
      );
      expect(a.docId, '19_23');
      expect(a.chapterKey, '19:23');
    });

    test('las 6 preguntas canónicas existen y tienen ids únicos', () {
      expect(kStudyQuestions.length, 6);
      final ids = kStudyQuestions.map((q) => q.id).toSet();
      expect(ids.length, 6);
      expect(
        ids,
        containsAll(<String>{
          'about_god',
          'about_people',
          'application',
          'author_speaker',
          'place',
          'context',
        }),
      );
    });
  });

  group('StudyChapterAnswers - rango de versículos (Fase 2)', () {
    StudyChapterAnswers makeBase() => StudyChapterAnswers.empty(
          bookNumber: 43,
          bookName: 'Juan',
          chapter: 4,
          versionId: 'RVR1960',
        );

    test('versesInRange devuelve [] cuando no hay rango', () {
      expect(makeBase().versesInRange(), isEmpty);
    });

    test('versesInRange inclusivo y normaliza orden invertido', () {
      final a = makeBase().copyWith(studyStartVerse: 44, studyEndVerse: 51);
      expect(a.versesInRange(), [44, 45, 46, 47, 48, 49, 50, 51]);
      // Orden invertido se normaliza:
      final b = makeBase().copyWith(studyStartVerse: 51, studyEndVerse: 44);
      expect(b.versesInRange().first, 44);
      expect(b.versesInRange().last, 51);
    });

    test('versesInRange single verso cuando start == end', () {
      final a = makeBase().copyWith(studyStartVerse: 7, studyEndVerse: 7);
      expect(a.versesInRange(), [7]);
    });

    test('reference incluye rango cuando aplica', () {
      expect(makeBase().reference, 'Juan 4');
      expect(
          makeBase().copyWith(studyStartVerse: 7, studyEndVerse: 7).reference,
          'Juan 4:7');
      expect(
          makeBase().copyWith(studyStartVerse: 44, studyEndVerse: 51).reference,
          'Juan 4:44-51');
    });

    test('serialización roundtrip preserva el rango', () {
      final a = makeBase().copyWith(studyStartVerse: 44, studyEndVerse: 51);
      final map = a.toMap();
      expect(map['studyStartVerse'], 44);
      expect(map['studyEndVerse'], 51);
      final round = StudyChapterAnswers.fromMap(map);
      expect(round.studyStartVerse, 44);
      expect(round.studyEndVerse, 51);
      expect(round.reference, 'Juan 4:44-51');
    });

    test('serialización omite el rango cuando es null', () {
      final a = makeBase();
      final map = a.toMap();
      expect(map.containsKey('studyStartVerse'), isFalse);
      expect(map.containsKey('studyEndVerse'), isFalse);
    });

    test('copyWith(clearRange: true) elimina ambos extremos', () {
      final a = makeBase().copyWith(studyStartVerse: 44, studyEndVerse: 51);
      final cleared = a.copyWith(clearRange: true);
      expect(cleared.studyStartVerse, isNull);
      expect(cleared.studyEndVerse, isNull);
      expect(cleared.versesInRange(), isEmpty);
    });
  });
}
