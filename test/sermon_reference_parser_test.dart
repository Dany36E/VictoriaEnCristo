import 'package:flutter_test/flutter_test.dart';
import 'package:app_quitar/models/bible/bible_book.dart';
import 'package:app_quitar/services/bible/sermon_reference_parser.dart';

void main() {
  test('detecta citas biblicas con nombres y abreviaturas comunes', () {
    const books = [
      BibleBook(
        number: 43,
        name: 'Juan',
        testament: 'NT',
        totalChapters: 21,
        versesPerChapter: {3: 36},
      ),
      BibleBook(
        number: 45,
        name: 'Romanos',
        testament: 'NT',
        totalChapters: 16,
        versesPerChapter: {3: 31, 8: 39},
      ),
    ];

    final refs = detectSermonReferences(
      'Anote Romanos 3:5, luego Rom. 8:1 y tambien Jn 3:16.',
      books,
    );

    expect(refs.map((r) => r.label), [
      'Romanos 3:5',
      'Romanos 8:1',
      'Juan 3:16',
    ]);
  });

  test('ignora citas fuera del rango real del libro', () {
    const books = [
      BibleBook(
        number: 45,
        name: 'Romanos',
        testament: 'NT',
        totalChapters: 16,
        versesPerChapter: {3: 31},
      ),
    ];

    final refs = detectSermonReferences('Rom. 3:99 y Rom. 3:5', books);

    expect(refs.single.label, 'Romanos 3:5');
  });

  test('detecta separadores alternos, rangos y libros numerados', () {
    const books = [
      BibleBook(
        number: 19,
        name: 'Salmos',
        testament: 'AT',
        totalChapters: 150,
        versesPerChapter: {23: 6},
      ),
      BibleBook(
        number: 55,
        name: '2 Timoteo',
        testament: 'NT',
        totalChapters: 4,
        versesPerChapter: {1: 18},
      ),
      BibleBook(
        number: 62,
        name: '1 Juan',
        testament: 'NT',
        totalChapters: 5,
        versesPerChapter: {4: 21},
      ),
    ];

    final refs = detectSermonReferences(
      'Sal 23,1-2, 2 Tim 1.7 y 1Jn 4:8',
      books,
    );

    expect(refs.map((r) => r.label), [
      'Salmos 23:1-2',
      '2 Timoteo 1:7',
      '1 Juan 4:8',
    ]);
    expect(refs.first.startVerse, 1);
    expect(refs.first.endVerse, 2);
  });

  test('detecta completo el rango de Apocalipsis sin texto extra', () {
    const books = [
      BibleBook(
        number: 66,
        name: 'Apocalipsis',
        testament: 'NT',
        totalChapters: 22,
        versesPerChapter: {22: 21},
      ),
    ];

    const text = 'Agregar (Apocalipsis 22:18-19) a mis notas';
    final refs = detectSermonReferences(text, books);

    expect(refs, hasLength(1));
    expect(refs.single.label, 'Apocalipsis 22:18-19');
    expect(refs.single.rawText, 'Apocalipsis 22:18-19');
    expect(
      text.substring(refs.single.start, refs.single.end),
      refs.single.rawText,
    );
  });
}
