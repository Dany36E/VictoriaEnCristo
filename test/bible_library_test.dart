import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/screens/bible/chapter_selector_screen.dart';
import 'package:app_quitar/services/bible/bible_library.dart';
import 'package:app_quitar/services/bible/reading_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryItem _item(
  int book,
  int chapter,
  int verse, {
  LibraryKind kind = LibraryKind.highlight,
  int day = 1,
  String? color,
  String? text,
  String? note,
  String? version = 'RVR1960',
}) => LibraryItem(
  kind: kind,
  bookNumber: book,
  bookName: 'Libro$book',
  chapter: chapter,
  verse: verse,
  versionId: version,
  date: DateTime(2024, 1, day),
  colorHex: color,
  verseText: text,
  noteText: note,
);

void main() {
  group('BibleLibrary.query', () {
    final items = [
      _item(43, 3, 16, day: 1, color: '#FFF176', text: 'Porque de tal manera'),
      _item(1, 1, 1, day: 3, color: '#A5D6A7', text: 'En el principio'),
      _item(19, 23, 1, day: 2, color: '#FFF176', text: 'Jehová es mi pastor'),
    ];

    test('por fecha: lo más reciente primero', () {
      final r = BibleLibrary.query(items);
      expect(r.map((i) => i.bookNumber), [1, 19, 43]);
    });

    test('orden bíblico', () {
      final r = BibleLibrary.query(items, sort: LibrarySort.bibleOrder);
      expect(r.map((i) => i.bookNumber), [1, 19, 43]);
      final r2 = BibleLibrary.query([
        _item(43, 3, 16),
        _item(43, 1, 1),
        _item(43, 3, 2),
      ], sort: LibrarySort.bibleOrder);
      expect(r2.map((i) => '${i.chapter}:${i.verse}'), ['1:1', '3:2', '3:16']);
    });

    test('filtro por color (sin importar mayúsculas)', () {
      final r = BibleLibrary.query(items, colorHex: '#fff176');
      expect(r.map((i) => i.bookNumber), unorderedEquals([43, 19]));
    });

    test('búsqueda por texto sin acentos', () {
      final r = BibleLibrary.query(items, search: 'jehova');
      expect(r.single.bookNumber, 19);
    });

    test('búsqueda por referencia', () {
      final r = BibleLibrary.query(items, search: 'Jn 3:16');
      expect(r.single.bookNumber, 43);
      final r2 = BibleLibrary.query(items, search: 'Salmos');
      expect(r2.single.bookNumber, 19);
    });

    test('búsqueda dentro de notas', () {
      final notas = [
        _item(45, 8, 28, kind: LibraryKind.note, note: 'Todo obra para bien'),
        _item(45, 8, 1, kind: LibraryKind.note, note: 'Sin condenación'),
      ];
      final r = BibleLibrary.query(notas, search: 'condenacion');
      expect(r.single.verse, 1);
    });
  });

  test('exportar a texto y Markdown incluye referencia y versión', () {
    final items = [
      _item(43, 3, 16, kind: LibraryKind.saved, text: 'Porque de tal manera'),
      _item(45, 8, 28, kind: LibraryKind.note, note: 'Promesa', version: null),
    ];
    final txt = BibleLibrary.exportText(items, LibraryKind.saved);
    expect(txt, contains('Libro43 3:16 (RVR1960)'));
    expect(txt, contains('«Porque de tal manera»'));
    expect(txt, contains('Nota: Promesa'));
    final md = BibleLibrary.exportMarkdown(items, LibraryKind.saved);
    expect(md, startsWith('# Versículos guardados'));
    expect(md, contains('## Libro43 3:16 (RVR1960)'));
    expect(md, contains('> Porque de tal manera'));
  });

  test('copyright: cada versión en español tiene su aviso', () {
    expect(
      BibleVersion.rvr1960.copyright,
      'Reina-Valera 1960 © Sociedades Bíblicas en América Latina, 1960. '
      'Renovado © Sociedades Bíblicas Unidas, 1988.',
    );
    expect(
      BibleVersion.nvi.copyright,
      'Nueva Versión Internacional® © 1999, 2015 por Biblica, Inc.®',
    );
    expect(
      BibleVersion.ntv.copyright,
      'Nueva Traducción Viviente © Tyndale House Foundation, 2010.',
    );
    expect(
      BibleVersion.lbla.copyright,
      'La Biblia de las Américas © 1986, 1995, 1997 The Lockman Foundation.',
    );
    expect(
      BibleVersion.tla.copyright,
      'Traducción en lenguaje actual © Sociedades Bíblicas Unidas, 2000.',
    );
    for (final v in BibleVersion.values) {
      expect(v.copyright, contains('©'), reason: v.id);
    }
    expect(BibleVersion.rvr1960.shareAbbreviation, 'RVR1960');
    expect(BibleVersion.nivEnglish.shareAbbreviation, 'NIV');
  });

  test('RECIENTES del selector: capítulos de verdad recientes', () {
    ReadingHistoryEntry e(int book, int ch, int min) => ReadingHistoryEntry(
      bookNumber: book,
      bookName: 'L',
      chapter: ch,
      verse: 1,
      versionId: 'RVR1960',
      at: DateTime(2024).add(Duration(minutes: min)),
    );
    // Historial: más reciente primero.
    final history = [e(43, 2, 9), e(1, 50, 8), e(43, 21, 7), e(43, 2, 6)];
    expect(ChapterSelectorScreen.recentChaptersFor(43, history), [2, 21]);
    expect(ChapterSelectorScreen.recentChaptersFor(19, history), isEmpty);
  });
}
