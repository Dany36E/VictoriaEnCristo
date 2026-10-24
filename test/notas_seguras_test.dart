import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_quitar/models/bible/adjunto_nota.dart';
import 'package:app_quitar/models/bible/bible_note.dart';
import 'package:app_quitar/models/bible/chapter_study_note.dart';
import 'package:app_quitar/models/bible/rich_note_document.dart';
import 'package:app_quitar/models/bible/sermon_note.dart';
import 'package:app_quitar/models/bible/study_chapter_answers.dart';
import 'package:app_quitar/screens/bible/buscar_notas_screen.dart';
import 'package:app_quitar/screens/bible/chapter_note_editor_screen.dart';
import 'package:app_quitar/services/bible/adjuntos_nota_service.dart';
import 'package:app_quitar/services/bible/buscador_notas.dart';
import 'package:app_quitar/services/bible/chapter_note_service.dart';
import 'package:app_quitar/services/bible/notas_sync.dart';
import 'package:app_quitar/services/bible/sermon_note_export_service.dart';
import 'package:app_quitar/services/bible/sermon_note_service.dart';
import 'package:app_quitar/services/bible/study_mode_service.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:app_quitar/theme/bible_reader_theme.dart';
import 'package:app_quitar/widgets/bible/sermon/adjuntos_nota.dart';
import 'package:app_quitar/widgets/bible/sermon/sermon_rich_text_controller.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase simulado: el estilo del PDF y las pantallas leen el tema.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Escritor que nunca recibe respuesta del servidor (como sin conexión).
class _SinConexion implements EscritorRemotoNotas {
  final rutas = <String>[];

  @override
  Future<void> guardar(
    String ruta,
    Map<String, dynamic> datos, {
    bool fusionar = true,
  }) {
    rutas.add(ruta);
    return Completer<void>().future;
  }

  @override
  Future<void> borrar(String ruta) {
    rutas.add('borrar:$ruta');
    return Completer<void>().future;
  }
}

/// Escritor que confirma al instante (con conexión).
class _ConConexion implements EscritorRemotoNotas {
  @override
  Future<void> guardar(
    String ruta,
    Map<String, dynamic> datos, {
    bool fusionar = true,
  }) async {}

  @override
  Future<void> borrar(String ruta) async {}
}

ChapterStudyNote _notaCapitulo(int i, {int capitulo = 1, String texto = ''}) {
  final fecha = DateTime(2025, 1, 1).add(Duration(minutes: i));
  return ChapterStudyNote(
    id: 'n$i',
    versionId: 'RVR1960',
    bookNumber: 43,
    bookName: 'Juan',
    chapter: capitulo,
    title: 'Nota $i',
    content: texto.isEmpty ? 'Contenido $i' : texto,
    createdAt: fecha,
    updatedAt: fecha,
  );
}

const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  late Directory temporal;
  late _SinConexion sinConexion;

  setUpAll(() async {
    await Firebase.initializeApp();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporal = await Directory.systemTemp.createTemp('notas_seguras_test_');
    PathProviderPlatform.instance = _FakePathProvider(temporal.path);
    sinConexion = _SinConexion();
    NotasSync.I.reiniciarParaPruebas(escritor: sinConexion);
    ChapterNoteService.I.stop();
    SermonNoteService.I.stop();
    StudyModeService.I.stop();
  });

  tearDown(() async {
    ChapterNoteService.I.stop();
    SermonNoteService.I.stop();
    StudyModeService.I.stop();
    NotasSync.I.reiniciarParaPruebas();
    if (await temporal.exists()) await temporal.delete(recursive: true);
  });

  group('guardado sin conexión no se cuelga', () {
    test('NotasSync no espera al servidor y avisa que está en el teléfono',
        () async {
      NotasSync.demoraSinConexion = const Duration(milliseconds: 20);
      final confirmacion = NotasSync.I.guardar('users/u/x/1', {'a': 1});
      expect(NotasSync.I.guardadoPendiente('users/u/x/1'), isTrue);
      expect(NotasSync.I.estado.value, EstadoNotasNube.subiendo);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(NotasSync.I.estado.value, EstadoNotasNube.esperandoConexion);
      expect(
        etiquetaEstadoNotas(NotasSync.I.estado.value),
        contains('se subirá al volver la conexión'),
      );
      // La confirmación nunca llega, pero nadie la espera.
      var termino = false;
      unawaited(confirmacion.then((_) => termino = true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(termino, isFalse);
      NotasSync.demoraSinConexion = const Duration(milliseconds: 1500);
    });

    test('con conexión la marca de pendiente se quita al confirmar', () async {
      NotasSync.I.reiniciarParaPruebas(escritor: _ConConexion());
      final ok = await NotasSync.I.guardar('users/u/x/1', {'a': 1});
      expect(ok, isTrue);
      expect(NotasSync.I.guardadoPendiente('users/u/x/1'), isFalse);
      expect(NotasSync.I.estado.value, EstadoNotasNube.alDia);
    });

    test('nota de capítulo: saveNote termina y la nota queda visible', () async {
      await ChapterNoteService.I.initSinNube('u1');
      final nota = await ChapterNoteService.I
          .saveNote(
            versionId: 'RVR1960',
            bookNumber: 43,
            bookName: 'Juan',
            chapter: 3,
            title: 'Nuevo nacimiento',
            content: 'Hay que nacer de nuevo.',
          )
          .timeout(const Duration(seconds: 2));
      expect(nota, isNotNull);
      expect(ChapterNoteService.I.getNoteForChapter(43, 3)?.content,
          'Hay que nacer de nuevo.');
      expect(sinConexion.rutas.single, 'users/u1/chapterNotes/${nota!.id}');

      // Editar una nota borrada en otro dispositivo: set(merge), sin error.
      await ChapterNoteService.I
          .saveNote(
            existingId: nota.id,
            versionId: 'RVR1960',
            bookNumber: 43,
            bookName: 'Juan',
            chapter: 3,
            title: 'Nuevo nacimiento',
            content: 'Editada sin conexión.',
          )
          .timeout(const Duration(seconds: 2));
      expect(ChapterNoteService.I.noteById(nota.id)?.content,
          'Editada sin conexión.');
    });

    test('apunte: saveNote termina sin esperar al servidor', () async {
      await SermonNoteService.I.initSinNube('u1');
      final apunte = SermonNote.empty(
        id: 'sermon_1',
        primaryVersionId: 'RVR1960',
        secondaryVersionId: 'NVI',
      ).copyWith(title: 'La fe', notes: 'Texto');
      await SermonNoteService.I
          .saveNote(apunte)
          .timeout(const Duration(seconds: 2));
      expect(SermonNoteService.I.noteById('sermon_1')?.title, 'La fe');
      await SermonNoteService.I
          .deleteNote('sermon_1')
          .timeout(const Duration(seconds: 2));
      expect(SermonNoteService.I.noteById('sermon_1'), isNull);
    });

    test('Modo Estudio: saveAnswers termina sin esperar al servidor', () async {
      await StudyModeService.I.initSinNube('u1');
      final estudio = StudyChapterAnswers.empty(
        studyId: 'st_prueba',
        bookNumber: 43,
        bookName: 'Juan',
        chapter: 3,
        versionId: 'RVR1960',
      ).copyWith(answers: {'q1': 'Dios ama al mundo'});
      await StudyModeService.I
          .saveAnswers(estudio)
          .timeout(const Duration(seconds: 2));
      expect(
        StudyModeService.I.answersForStudyId('st_prueba')?.answers['q1'],
        'Dios ama al mundo',
      );
      expect(sinConexion.rutas, contains('users/u1/studyAnswers/st_prueba'));
    });

    test('lo pendiente se reenvía al volver a abrir la app', () async {
      await ChapterNoteService.I.initSinNube('u1');
      final nota = await ChapterNoteService.I.saveNote(
        versionId: 'RVR1960',
        bookNumber: 1,
        bookName: 'Génesis',
        chapter: 1,
        title: 'Principio',
        content: 'En el principio',
      );
      ChapterNoteService.I.stop();
      // Nueva sesión: la cola sigue en SharedPreferences.
      final otra = _SinConexion();
      NotasSync.I.reiniciarParaPruebas(escritor: otra);
      await ChapterNoteService.I.initSinNube('u1');
      expect(otra.rutas, contains('users/u1/chapterNotes/${nota!.id}'));
      expect(ChapterNoteService.I.noteById(nota.id)?.content, 'En el principio');
    });
  });

  group('las notas no desaparecen de la vista', () {
    test('fusionar conserva más de 300 notas y lo pendiente', () {
      final local = {for (var i = 0; i < 350; i++) 'n$i': i};
      final remoto = {for (var i = 0; i < 349; i++) 'n$i': i};
      final unidos = fusionarConServidor<int>(
        local: {...local, 'nueva': -1},
        remoto: remoto,
        desdeCache: false,
        guardadoPendiente: (id) => id == 'nueva',
        borradoPendiente: (_) => false,
      );
      // n349 no llegó del servidor y no estaba pendiente: se borró en otro
      // dispositivo. La nueva (sin subir) se conserva.
      expect(unidos.length, 350);
      expect(unidos.containsKey('nueva'), isTrue);
      expect(unidos.containsKey('n349'), isFalse);
    });

    test('un snapshot de la cache (incompleto) no borra nada', () {
      final unidos = fusionarConServidor<int>(
        local: {'a': 1, 'b': 2},
        remoto: {'a': 1},
        desdeCache: true,
        guardadoPendiente: (_) => false,
        borradoPendiente: (_) => false,
      );
      expect(unidos.keys, containsAll(['a', 'b']));
    });

    test('lo borrado en el teléfono no reaparece y lo editado gana', () {
      final unidos = fusionarConServidor<String>(
        local: {'a': 'nuevo'},
        remoto: {'a': 'viejo', 'b': 'borrada'},
        desdeCache: false,
        guardadoPendiente: (id) => id == 'a',
        borradoPendiente: (id) => id == 'b',
      );
      expect(unidos, {'a': 'nuevo'});
    });

    test('notas de capítulo: 350 visibles y dos en el mismo capítulo',
        () async {
      await ChapterNoteService.I.initSinNube('u1');
      final remoto = {
        for (var i = 0; i < 350; i++) 'n$i': _notaCapitulo(i, capitulo: 1),
      };
      ChapterNoteService.I.aplicarSnapshot(remoto, desdeCache: false);
      expect(ChapterNoteService.I.allNotes.length, 350);
      expect(ChapterNoteService.I.notesForChapter(43, 1).length, 350);
      // La lectura sigue viendo la más reciente del capítulo.
      expect(ChapterNoteService.I.getNoteForChapter(43, 1)?.id, 'n349');

      // Borrada en otro dispositivo: el servidor ya no la trae.
      ChapterNoteService.I.aplicarSnapshot(
        Map.of(remoto)..remove('n0'),
        desdeCache: false,
      );
      expect(ChapterNoteService.I.noteById('n0'), isNull);
      expect(ChapterNoteService.I.allNotes.length, 349);
    });

    test('Modo Estudio: más de 500 estudios siguen visibles', () async {
      await StudyModeService.I.initSinNube('u1');
      final remoto = <String, StudyChapterAnswers>{};
      for (var i = 0; i < 520; i++) {
        final a = StudyChapterAnswers.empty(
          studyId: 'st_$i',
          bookNumber: 1,
          bookName: 'Génesis',
          chapter: 1,
          versionId: 'RVR1960',
        );
        remoto[a.chapterKey] = a;
      }
      StudyModeService.I.aplicarSnapshotRespuestas(remoto, desdeCache: false);
      expect(StudyModeService.I.answersNotifier.value.length, 520);
      expect(StudyModeService.docIdDeClave('43:3'), '43_3');
      expect(StudyModeService.docIdDeClave('st_abc'), 'st_abc');
    });
  });

  group('fotos dentro del texto', () {
    test('se inserta en el cursor, en su propia línea', () {
      const doc = RichNoteDocument(text: 'Antes\nDespués', spans: []);
      final (nuevo, cursor) = doc.insertarAdjunto(5, 'a1');
      expect(nuevo.text, 'Antes\n$kMarcaAdjunto\nDespués');
      expect(nuevo.embeds, ['a1']);
      expect(cursor, nuevo.text.indexOf('Después'));
      // Al final de una línea sin salto: agrega uno antes y uno después.
      final (alFinal, _) = const RichNoteDocument(
        text: 'Diapositiva',
        spans: [],
      ).insertarAdjunto(11, 'a2');
      expect(alFinal.text, 'Diapositiva\n$kMarcaAdjunto\n');
    });

    test('el orden se conserva al guardar y al escribir alrededor', () {
      var doc = const RichNoteDocument(text: 'Uno\nDos\n', spans: []);
      doc = doc.insertarAdjunto(4, 'foto1').$1;
      doc = doc.insertarAdjunto(doc.text.length, 'foto2').$1;
      expect(doc.idsEnLinea, ['foto1', 'foto2']);
      final leido = RichNoteDocument.fromStorage(doc.toStorage());
      expect(leido.idsEnLinea, ['foto1', 'foto2']);
      // Escribir antes de la primera foto no las desordena.
      final editado = leido.replaceText('Cero\n${leido.text}');
      expect(editado.idsEnLinea, ['foto1', 'foto2']);
      // Borrar la marca de la primera la saca del texto (se ve al final).
      final i = editado.text.indexOf(kMarcaAdjunto);
      final sinPrimera = editado.replaceText(
        editado.text.replaceRange(i, i + 1, ''),
      );
      expect(sinPrimera.idsEnLinea, ['foto2']);
      expect(richNotePlainText(doc.toStorage()).contains(kMarcaAdjunto), isFalse);
    });

    test('las notas antiguas (fotos al final) se leen igual', () {
      final antigua = jsonEncode({
        'kind': 'victoria_rich_note_v1',
        'text': 'Notas sin fotos dentro',
        'spans': [],
      });
      final doc = RichNoteDocument.fromStorage(antigua);
      expect(doc.text, 'Notas sin fotos dentro');
      expect(doc.idsEnLinea, isEmpty);
      expect(jsonDecode(doc.toStorage()).containsKey('embeds'), isFalse);
    });

    test('bloques en orden: texto, foto, comentario', () {
      var doc = const RichNoteDocument(text: 'Diapositiva 1', spans: []);
      doc = doc.insertarAdjunto(doc.text.length, 'f1').$1;
      doc = doc.replaceText('${doc.text}Mi comentario');
      final bloques = doc.bloques();
      expect(bloques.length, 3);
      expect(bloques[0].segmentos.map((s) => s.text).join(), 'Diapositiva 1\n');
      expect(bloques[1].adjuntoId, 'f1');
      expect(bloques[2].segmentos.map((s) => s.text).join(), '\nMi comentario');

      final bytes = base64Decode(_png1x1);
      final orden = ordenarNotasConImagenes(bloques, [
        ImagenPdf(bytes, 'vieja', id: 'f0'),
        ImagenPdf(bytes, 'en línea', id: 'f1'),
      ]);
      expect(orden.contenido[1], isA<ImagenPdf>());
      expect((orden.contenido[1] as ImagenPdf).id, 'f1');
      expect(orden.alFinal.map((i) => i.id), ['f0']);
    });

    test('el controlador inserta en el cursor y se puede deshacer', () {
      final c = SermonRichTextController(
        document: const RichNoteDocument(text: 'Hola mundo', spans: []),
      );
      c.selection = const TextSelection.collapsed(offset: 4);
      c.insertarAdjunto('a1');
      expect(c.text, 'Hola\n$kMarcaAdjunto\n mundo');
      expect(c.document.embeds, ['a1']);
      c.quitarAdjunto('a1');
      expect(c.document.embeds, isEmpty);
      c.undo();
      expect(c.document.embeds, ['a1']);
      c.undo();
      expect(c.text, 'Hola mundo');
      c.dispose();
    });

    test('el PDF sale con la foto dentro del texto (sin conexión)', () async {
      var doc = const RichNoteDocument(text: 'Antes de la foto', spans: []);
      doc = doc.insertarAdjunto(doc.text.length, 'f1').$1;
      doc = doc.replaceText('${doc.text}Después de la foto');
      final nota = SermonNote.empty(
        id: 'sermon_pdf',
        primaryVersionId: 'RVR1960',
        secondaryVersionId: 'NVI',
      ).copyWith(
        title: 'Con foto',
        notes: doc.toStorage(),
        adjuntos: [
          AdjuntoNota(
            id: 'f1',
            tipo: TipoAdjunto.foto,
            proporcion: 1,
            creadoEn: DateTime(2026),
          ),
        ],
      );
      final archivo = await SermonNoteExportService.I.exportSermonNoteToPdf(
        note: nota,
        chapterVerses: const [],
        imagenes: [ImagenPdf(base64Decode(_png1x1), 'Diapositiva', id: 'f1')],
      );
      expect(await archivo.exists(), isTrue);
      expect(await archivo.length(), greaterThan(1000));
    });
  });

  group('adjuntos: nunca borrar lo que no se subió', () {
    test('rutas de Windows coinciden con la cola', () {
      expect(
        AdjuntosNotaService.rutaRelativa(
          r'C:\docs\apuntes',
          r'C:\docs\apuntes\u1\nota\a1.jpg',
        ),
        'u1/nota/a1.jpg',
      );
      expect(
        AdjuntosNotaService.rutaRelativa('/d/apuntes', '/d/apuntes/u1/n/a.svg'),
        'u1/n/a.svg',
      );
      final pendientes = AdjuntosNotaService.archivosSinSubir([
        's|u1|nota|a1.jpg',
        'b|u1|nota|viejo.jpg',
      ]);
      expect(pendientes, {'u1/nota/a1.jpg'});
    });
  });

  group('buscar en todas mis notas', () {
    final fecha = DateTime(2026, 5, 1);
    final capitulo = ChapterStudyNote(
      id: 'c1',
      versionId: 'RVR1960',
      bookNumber: 49,
      bookName: 'Efesios',
      chapter: 2,
      title: 'Salvos por gracia',
      content: 'Por GRACIA sois salvos por medio de la fe.',
      tags: const ['gracia'],
      createdAt: fecha,
      updatedAt: fecha,
    );
    final espejo = ChapterStudyNote(
      id: 'c2',
      versionId: 'RVR1960',
      bookNumber: 49,
      bookName: 'Efesios',
      chapter: 2,
      title: 'Modo Estudio',
      content: 'gracia',
      tags: const ['modo-estudio'],
      createdAt: fecha,
      updatedAt: fecha,
    );
    final apunte = SermonNote.empty(
      id: 's1',
      primaryVersionId: 'RVR1960',
      secondaryVersionId: 'NVI',
    ).copyWith(
      title: 'Domingo',
      notes: const RichNoteDocument(
        text: 'La gracía de Dios #esperanza',
        spans: [],
      ).toStorage(),
    );
    final estudio = StudyChapterAnswers.empty(
      studyId: 'st_1',
      bookNumber: 43,
      bookName: 'Juan',
      chapter: 3,
      versionId: 'RVR1960',
    ).copyWith(answers: {'q1': 'Su gracia es suficiente'});
    final versiculo = BibleNote(
      id: 'v1',
      bookNumber: 45,
      chapter: 5,
      verse: 20,
      bookName: 'Romanos',
      text: 'Sobreabundó la gracia',
      createdAt: fecha,
      updatedAt: fecha,
    );
    final espejoVersiculo = BibleNote(
      id: 'v2',
      bookNumber: 45,
      chapter: 5,
      verse: 21,
      bookName: 'Romanos',
      text: '⟦modo-estudio⟧ gracia',
      createdAt: fecha,
      updatedAt: fecha,
    );

    List<ResultadoNota> buscar(String q, {String? etiqueta}) =>
        BuscadorNotas.buscar(
          q,
          etiqueta: etiqueta,
          notasCapitulo: [capitulo, espejo],
          apuntes: [apunte],
          estudios: [estudio],
          notasVersiculo: [versiculo, espejoVersiculo],
        );

    test('encuentra en los cuatro tipos sin acentos ni mayúsculas', () {
      final r = buscar('gracia');
      expect(r.map((e) => e.tipo).toSet(), {
        TipoNotaBuscada.capitulo,
        TipoNotaBuscada.apunte,
        TipoNotaBuscada.estudio,
        TipoNotaBuscada.versiculo,
      });
      // Las copias del Modo Estudio no se repiten.
      expect(r.length, 4);
      for (final e in r) {
        expect(e.tieneResaltado, isTrue);
        expect(
          BuscadorNotas.normalizar(e.fragmento.substring(e.inicio, e.fin)),
          'gracia',
        );
      }
    });

    test('filtra por etiqueta y por referencia', () {
      expect(buscar('', etiqueta: 'esperanza').single.id, 's1');
      expect(buscar('', etiqueta: 'gracia').single.id, 'c1');
      expect(buscar('romanos 5').single.tipo, TipoNotaBuscada.versiculo);
      expect(buscar('nada que ver'), isEmpty);
      expect(buscar(''), isEmpty);
    });
  });

  group('pantallas', () {
    Widget app(Widget hijo) => MaterialApp(
      theme: AppTheme.paperTheme,
      builder: (context, c) =>
          AppThemeData.provider(theme: AppThemeData.paper, child: c!),
      home: hijo,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({'app_theme_id': 'papel'});
      await ThemeService().initialize();
    });

    testWidgets('nota de capítulo: ✓ vacía avisa y volver atrás guarda', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await tester.runAsync(() => ChapterNoteService.I.initSinNube('u1'));

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChapterNoteEditorScreen(
                        bookNumber: 43,
                        bookName: 'Juan',
                        chapter: 3,
                        versionId: 'RVR1960',
                      ),
                    ),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Guardar y cerrar'));
      await tester.pump();
      expect(find.textContaining('Escribe un título'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Reflexión sin ✓');
      await tester.pump();
      // Volver con la flecha, sin tocar ✓: no se pierde.
      await tester.tap(find.byTooltip('Volver (se guarda solo)'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('abrir'), findsOneWidget);
      expect(
        ChapterNoteService.I.getNoteForChapter(43, 3)?.content,
        'Reflexión sin ✓',
      );
      expect(tester.takeException(), isNull);
      // Deja correr el aviso de «sin conexión» para no dejar timers vivos.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('la foto se dibuja dentro del editor y responde al toque', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      var doc = const RichNoteDocument(text: 'Diapositiva', spans: []);
      doc = doc.insertarAdjunto(doc.text.length, 'f1').$1;
      doc = doc.replaceText('${doc.text}Comentario');
      final adjunto = AdjuntoNota(
        id: 'f1',
        tipo: TipoAdjunto.foto,
        proporcion: 4 / 3,
        creadoEn: DateTime(2026),
      );
      final acciones = <AccionAdjunto>[];
      final controller = SermonRichTextController(document: doc)
        ..constructorAdjunto = (id) => id == 'f1'
            ? AdjuntoEnLinea(
                theme: BibleReaderThemeData.fromId('papel'),
                notaId: 'sermon_1',
                adjunto: adjunto,
                onAccion: acciones.add,
              )
            : null;
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: controller, maxLines: null, minLines: 4),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AdjuntoEnLinea), findsOneWidget);
      final caja = tester.getRect(find.byType(AdjuntoEnLinea));
      expect(caja.width, greaterThan(250)); // todo el ancho del editor
      await tester.tap(find.byType(VistaAdjunto));
      await tester.pump();
      expect(acciones, [AccionAdjunto.ver]);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('buscar notas: vacía y con resultados, sin desbordes', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await tester.runAsync(() => ChapterNoteService.I.initSinNube('u1'));
      ChapterNoteService.I.aplicarSnapshot({
        'n1': _notaCapitulo(1, capitulo: 3, texto: 'El viento sopla de donde quiere'),
      }, desdeCache: false);
      await tester.pumpWidget(
        app(const BuscarNotasScreen(consultaInicial: 'viento')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1 resultado'), findsOneWidget);
      expect(find.text('NOTA DE CAPÍTULO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
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
