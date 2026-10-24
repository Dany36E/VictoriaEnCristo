import 'package:app_quitar/services/bible/reading_history_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReadingHistoryEntry _e(int book, int chapter, {int verse = 1, int min = 0}) =>
    ReadingHistoryEntry(
      bookNumber: book,
      bookName: 'Libro $book',
      chapter: chapter,
      verse: verse,
      versionId: 'RVR1960',
      at: DateTime(2024, 5, 1).add(Duration(minutes: min)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pushEntry', () {
    test('lo más reciente queda primero', () {
      var h = <ReadingHistoryEntry>[];
      h = ReadingHistoryService.pushEntry(h, _e(43, 3));
      h = ReadingHistoryService.pushEntry(h, _e(19, 23));
      expect(h.map((e) => e.label), ['Libro 19 23', 'Libro 43 3']);
    });

    test('visitas consecutivas al mismo capítulo no se repiten', () {
      var h = <ReadingHistoryEntry>[];
      h = ReadingHistoryService.pushEntry(h, _e(43, 3));
      h = ReadingHistoryService.pushEntry(h, _e(43, 3, verse: 16, min: 5));
      expect(h.length, 1);
      expect(h.first.verse, 16);
    });

    test('volver a un capítulo no consecutivo sí crea otra entrada', () {
      var h = <ReadingHistoryEntry>[];
      h = ReadingHistoryService.pushEntry(h, _e(43, 3));
      h = ReadingHistoryService.pushEntry(h, _e(43, 4));
      h = ReadingHistoryService.pushEntry(h, _e(43, 3));
      expect(h.length, 3);
    });

    test('se recorta al máximo', () {
      var h = <ReadingHistoryEntry>[];
      for (var i = 1; i <= 10; i++) {
        h = ReadingHistoryService.pushEntry(h, _e(1, i), max: 4);
      }
      expect(h.length, 4);
      expect(h.first.chapter, 10);
    });
  });

  test('codificar y decodificar historial y posiciones', () {
    final h = [_e(43, 3, verse: 16), _e(19, 23)];
    final back = ReadingHistoryService.decodeHistory(
      ReadingHistoryService.encodeHistory(h),
    );
    expect(back.length, 2);
    expect(back.first.label, 'Libro 43 3:16');
    expect(back.first.at, h.first.at);
    expect(ReadingHistoryService.decodeHistory('no es json'), isEmpty);
    expect(ReadingHistoryService.decodePositions('{"RVR1960:43:3":16}'), {
      'RVR1960:43:3': 16,
    });
    expect(ReadingHistoryService.decodePositions(null), isEmpty);
  });

  group('servicio', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        // Formato antiguo: solo libro y capítulo.
        'lastReadBookNumber': 45,
        'lastReadBookName': 'Romanos',
        'lastReadChapter': 8,
      });
      ReadingHistoryService.I.resetForTest();
    });

    test('lee la última lectura del formato antiguo', () async {
      await ReadingHistoryService.I.ensureLoaded();
      final last = ReadingHistoryService.I.lastReadNotifier.value!;
      expect(last.bookName, 'Romanos');
      expect(last.chapter, 8);
      expect(last.verse, 1);
    });

    test('recuerda el versículo por versión/libro/capítulo', () async {
      final s = ReadingHistoryService.I;
      await s.recordVisit(
        bookNumber: 43,
        bookName: 'Juan',
        chapter: 3,
        versionId: 'NVI',
      );
      s.updatePosition(
        bookNumber: 43,
        bookName: 'Juan',
        chapter: 3,
        versionId: 'NVI',
        verse: 16,
      );
      await s.flush();
      expect(s.positionFor('NVI', 43, 3), 16);
      expect(s.positionFor('RVR1960', 43, 3), isNull);
      expect(s.lastReadNotifier.value!.label, 'Juan 3:16');
      expect(s.historyNotifier.value.first.verse, 16);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('lastReadBookNumber'), 43);
      expect(prefs.getInt('lastReadVerse'), 16);
      expect(prefs.getString('lastReadVersion'), 'NVI');

      // Recargar desde disco conserva todo.
      s.resetForTest();
      await s.ensureLoaded();
      expect(s.positionFor('NVI', 43, 3), 16);
      expect(s.lastReadNotifier.value!.verse, 16);

      s.clearPosition('NVI', 43, 3);
      expect(s.positionFor('NVI', 43, 3), isNull);
      await s.flush();
    });

    test('borrar historial', () async {
      final s = ReadingHistoryService.I;
      await s.recordVisit(
        bookNumber: 1,
        bookName: 'Génesis',
        chapter: 1,
        versionId: 'RVR1960',
      );
      expect(s.historyNotifier.value, isNotEmpty);
      await s.clearHistory();
      expect(s.historyNotifier.value, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bible_reading_history_v1'), isNull);
    });
  });
}
