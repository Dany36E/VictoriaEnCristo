import 'dart:io';

import 'package:app_quitar/models/bible/bible_book.dart';
import 'package:app_quitar/models/bible/bible_verse.dart';
import 'package:app_quitar/models/bible/rich_note_document.dart';
import 'package:app_quitar/models/bible/sermon_note.dart';
import 'package:app_quitar/services/bible/sermon_note_export_service.dart';
import 'package:app_quitar/services/bible/sermon_reference_parser.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sermon_export_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('exporta PDF de predicacion con notas y reflexion largas', () async {
    final longBody = List.filled(
      130,
      'Cristo sostiene, corrige y nos vuelve a centrar en su palabra.',
    ).join(' ');
    var richNotes = RichNoteDocument(
      text: 'Idea central: gracia $longBody',
      spans: const [],
    );
    richNotes = richNotes.applyFormat(0, 13, RichNoteFormat.bold);
    richNotes = richNotes.applyFormat(14, 20, RichNoteFormat.underline);
    richNotes = richNotes.applyFormat(
      21,
      richNotes.text.length,
      RichNoteFormat.size,
      fontSize: 22,
    );
    final note = SermonNote(
      id: 'sermon-test',
      title: 'Fe que persevera',
      sermonDate: DateTime(2026, 6, 6),
      speaker: 'Pastor Daniel',
      primaryVersionId: 'RVR1960',
      secondaryVersionId: 'NVI',
      centralPassage: const SermonCentralPassage(
        bookNumber: 45,
        bookName: 'Romanos',
        chapter: 8,
        startVerse: 1,
        endVerse: 3,
      ),
      notes: richNotes.toStorage(),
      takeaway: List.filled(
        95,
        'Me quedo con obedecer pronto y creerle a Dios por encima del temor.',
      ).join(' '),
      verses: const [
        SermonVerseReference(
          bookNumber: 45,
          bookName: 'Romanos',
          chapter: 8,
          verse: 1,
          versionId: 'RVR1960',
          text:
              'Ahora, pues, ninguna condenacion hay para los que estan en Cristo Jesus.',
        ),
      ],
      createdAt: DateTime(2026, 6, 6),
      updatedAt: DateTime(2026, 6, 6),
    );

    final file = await SermonNoteExportService.I.exportSermonNoteToPdf(
      note: note,
      chapterVerses: const [
        BibleVerse(
          bookNumber: 45,
          bookName: 'Romanos',
          chapter: 8,
          verse: 1,
          text:
              'Ahora, pues, ninguna condenacion hay para los que estan en Cristo Jesus.',
          version: 'RVR1960',
        ),
        BibleVerse(
          bookNumber: 45,
          bookName: 'Romanos',
          chapter: 8,
          verse: 2,
          text:
              'Porque la ley del Espiritu de vida en Cristo Jesus me ha librado de la ley del pecado y de la muerte.',
          version: 'RVR1960',
        ),
        BibleVerse(
          bookNumber: 45,
          bookName: 'Romanos',
          chapter: 8,
          verse: 3,
          text:
              'Porque lo que era imposible para la ley, por cuanto era debil por la carne, Dios, enviando a su Hijo.',
          version: 'RVR1960',
        ),
      ],
      secondaryChapterVerses: const [
        BibleVerse(
          bookNumber: 45,
          bookName: 'Romanos',
          chapter: 8,
          verse: 1,
          text:
              'Por lo tanto, ya no hay ninguna condenacion para los que estan unidos a Cristo Jesus.',
          version: 'NVI',
        ),
        BibleVerse(
          bookNumber: 45,
          bookName: 'Romanos',
          chapter: 8,
          verse: 2,
          text:
              'Pues por medio de el, la ley del Espiritu de vida me ha liberado de la ley del pecado y de la muerte.',
          version: 'NVI',
        ),
        BibleVerse(
          bookNumber: 45,
          bookName: 'Romanos',
          chapter: 8,
          verse: 3,
          text:
              'En efecto, la ley no pudo liberarnos porque la naturaleza pecaminosa anulo su poder.',
          version: 'NVI',
        ),
      ],
      cleanCover: true,
    );

    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
  });

  test('detecta rangos y separadores alternos al tomar apuntes', () {
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
    ];

    final refs = detectSermonReferences('Sal 23,1-2 y 2 Tim 1.7', books);

    expect(refs.map((r) => r.label), ['Salmos 23:1-2', '2 Timoteo 1:7']);
  });
}

class _FakePathProvider extends PathProviderPlatform {
  final String path;

  _FakePathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getDownloadsPath() async => path;
}
