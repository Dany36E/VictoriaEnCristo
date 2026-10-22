import 'dart:convert';
import 'dart:io';

import 'package:app_quitar/models/bible/bible_verse.dart';
import 'package:app_quitar/models/bible/rich_note_document.dart';
import 'package:app_quitar/models/bible/sermon_note.dart';
import 'package:app_quitar/models/bible/study_chapter_answers.dart';
import 'package:app_quitar/services/bible/estilo_pdf.dart';
import 'package:app_quitar/services/bible/sermon_note_export_service.dart';
import 'package:app_quitar/services/bible/study_export_service.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Genera el PDF de un apunte en el estilo clásico y en el de papel. Las
/// copias quedan en build/qa/ para revisarlas a ojo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('pdf_papel_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('el estilo sigue al tema activo', () async {
    await ThemeService().setTheme('papel');
    final papel = await EstiloPdf.cargar();
    expect(papel.papel, isTrue);
    expect(papel.titulo, isNotNull);
    expect(papel.mano, isNotNull);

    await ThemeService().setTheme('clean_page');
    final clasico = await EstiloPdf.cargar();
    expect(clasico.papel, isFalse);
    expect(clasico.titulo, isNull);
  });

  for (final (tema, portada) in [
    ('papel', true),
    ('papel', false),
    ('clean_page', false),
  ]) {
    test('apunte en PDF con tema $tema${portada ? ' y portada' : ''}', () async {
      await ThemeService().setTheme(tema);
      var doc = const RichNoteDocument(
        text:
            'Puntos principales\n☐ Orar por la familia\n☑ Leer Juan 3\n'
            '• Dios es fiel #gracia\nLa tentación no es pecado; ceder sí.',
        spans: [],
      );
      doc = doc.applyParagraphStyle(0, 0, RichNoteParagraphStyle.title);
      doc = doc.applyFormat(
        68,
        82,
        RichNoteFormat.highlight,
        value: 'amarillo',
      );
      final nota = SermonNote(
        id: 'pdf_$tema',
        title: 'Fiel en la tentación',
        sermonDate: DateTime(2026, 10, 18),
        speaker: 'Pastor Daniel',
        primaryVersionId: 'RVR1960',
        secondaryVersionId: 'NVI',
        centralPassage: const SermonCentralPassage(
          bookNumber: 46,
          bookName: '1 Corintios',
          chapter: 10,
          startVerse: 12,
          endVerse: 13,
        ),
        notes: doc.toStorage(),
        takeaway:
            'Cuando venga la tentación, buscar la salida que Dios ya preparó.',
        verses: const [
          SermonVerseReference(
            bookNumber: 50,
            bookName: 'Filipenses',
            chapter: 4,
            verse: 13,
            versionId: 'RVR1960',
            text: 'Todo lo puedo en Cristo que me fortalece.',
          ),
        ],
        highlights: const [],
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 18),
      );
      const versiculos = [
        BibleVerse(
          bookName: '1 Corintios',
          bookNumber: 46,
          chapter: 10,
          verse: 12,
          text: 'Así que, el que piensa estar firme, mire que no caiga.',
          version: 'RVR1960',
        ),
        BibleVerse(
          bookName: '1 Corintios',
          bookNumber: 46,
          chapter: 10,
          verse: 13,
          text:
              'No os ha sobrevenido ninguna tentación que no sea humana; '
              'pero fiel es Dios, que no os dejará ser tentados más de lo '
              'que podéis resistir.',
          version: 'RVR1960',
        ),
      ];
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );
      final archivo = await SermonNoteExportService.I.exportSermonNoteToPdf(
        note: nota,
        chapterVerses: versiculos,
        imagenes: [ImagenPdf(png, 'Pizarra del domingo')],
        cleanCover: portada,
      );
      expect(await archivo.length(), greaterThan(1000));
      final copia = File(
        'build/qa/pdf_apunte_$tema${portada ? '_portada' : ''}.pdf',
      );
      await copia.parent.create(recursive: true);
      await archivo.copy(copia.path);
    });
  }

  test('reflexión larga en papel se parte entre páginas', () async {
    await ThemeService().setTheme('papel');
    final nota = SermonNote(
      id: 'pdf_papel_largo',
      title: 'Fe que persevera',
      sermonDate: DateTime(2026, 10, 18),
      speaker: 'Pastor Daniel',
      primaryVersionId: 'RVR1960',
      secondaryVersionId: 'NVI',
      centralPassage: null,
      notes: 'Idea central: gracia.',
      takeaway: List.filled(
        95,
        'Me quedo con obedecer pronto y creerle a Dios por encima del temor.',
      ).join(' '),
      verses: const [],
      highlights: const [],
      createdAt: DateTime(2026, 10, 18),
      updatedAt: DateTime(2026, 10, 18),
    );
    final archivo = await SermonNoteExportService.I.exportSermonNoteToPdf(
      note: nota,
      chapterVerses: const [],
    );
    expect(await archivo.length(), greaterThan(1000));
  });

  _estudio();
}

void _estudio() {
  for (final tema in ['papel', 'clean_page']) {
    test('estudio en PDF con tema $tema', () async {
      await ThemeService().setTheme(tema);
      final estudio = StudyChapterAnswers(
        studyId: 'estudio_$tema',
        bookNumber: 46,
        bookName: '1 Corintios',
        chapter: 10,
        versionId: 'RVR1960',
        answers: {
          'application': 'Huir de lo que me hace caer y pedir ayuda a tiempo.',
        },
        generalNotes: const RichNoteDocument(
          text: 'Dios siempre da una salida.',
          spans: [],
        ).toStorage(),
        hopeMessage: 'Fiel es Dios.',
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 18),
      );
      final archivo = await StudyExportService.I.exportStudyToPdf(
        study: estudio,
        chapterVerses: const [
          BibleVerse(
            bookName: '1 Corintios',
            bookNumber: 46,
            chapter: 10,
            verse: 13,
            text:
                'No os ha sobrevenido ninguna tentación que no sea humana; '
                'pero fiel es Dios.',
            version: 'RVR1960',
          ),
        ],
      );
      expect(await archivo.length(), greaterThan(1000));
      final copia = File('build/qa/pdf_estudio_$tema.pdf');
      await copia.parent.create(recursive: true);
      await archivo.copy(copia.path);
    });
  }
}

class _FakePathProvider extends PathProviderPlatform {
  final String path;

  _FakePathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getDownloadsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}
