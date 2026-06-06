import 'dart:io';

import 'package:app_quitar/models/bible/bible_verse.dart';
import 'package:app_quitar/models/bible/rich_note_document.dart';
import 'package:app_quitar/models/bible/study_chapter_answers.dart';
import 'package:app_quitar/services/bible/study_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('study_export_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('exporta PDF con notas generales largas y formato parcial', () async {
    final longNote = List.filled(
      90,
      'Hay que demostrarle que lo amamos mas a Dios que a lo que nos ha dado.',
    ).join(' ');
    var formatted = RichNoteDocument(
      text: 'Confianza: obediencia $longNote',
      spans: const [],
    );
    formatted = formatted.applyFormat(0, 11, RichNoteFormat.bold);
    formatted = formatted.applyFormat(12, 22, RichNoteFormat.underline);
    formatted = formatted.applyFormat(
      23,
      formatted.text.length,
      RichNoteFormat.size,
      fontSize: 22,
    );
    final study = StudyChapterAnswers(
      studyId: 'study-test',
      bookNumber: 1,
      bookName: 'Genesis',
      chapter: 22,
      versionId: 'RVR1960',
      answers: {
        'application': List.filled(
          70,
          'Respuesta larga para probar saltos de pagina.',
        ).join(' '),
      },
      generalNotes: formatted.toStorage(),
      hopeMessage: List.filled(
        55,
        'Dios provee y sostiene la esperanza.',
      ).join(' '),
      createdAt: DateTime(2026, 6, 5),
      updatedAt: DateTime(2026, 6, 5),
    );

    final file = await StudyExportService.I.exportStudyToPdf(
      study: study,
      chapterVerses: [
        const BibleVerse(
          bookNumber: 1,
          bookName: 'Genesis',
          chapter: 22,
          verse: 1,
          text: 'Acontecio despues de estas cosas, que probo Dios a Abraham.',
          version: 'RVR1960',
        ),
      ],
      cleanCover: true,
    );

    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
    expect(
      richNotePlainText(formatted.toStorage()),
      contains('Confianza: obediencia'),
    );
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
