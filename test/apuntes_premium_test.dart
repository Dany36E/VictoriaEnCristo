import 'dart:convert';
import 'dart:io';

import 'package:app_quitar/models/bible/adjunto_nota.dart';
import 'package:app_quitar/models/bible/dibujo_nota.dart';
import 'package:app_quitar/models/bible/etiquetas_nota.dart';
import 'package:app_quitar/models/bible/listas_nota.dart';
import 'package:app_quitar/models/bible/rich_note_document.dart';
import 'package:app_quitar/models/bible/sermon_note.dart';
import 'package:app_quitar/services/bible/sermon_note_export_service.dart';
import 'package:app_quitar/utils/tinta.dart';
import 'package:app_quitar/widgets/bible/sermon/lienzo/edicion_trazos.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase simulado: el estilo del PDF lee el tema de la Biblia.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

List<PuntoTinta> _linea(double x0, double y, double x1) => [
  for (var x = x0; x <= x1; x += 5) PuntoTinta(x, y, 0.5),
];

Trazo _trazo(List<PuntoTinta> puntos) => Trazo(
  herramienta: HerramientaTrazo.pluma,
  color: 0xFF2B2622,
  grosor: 6,
  puntos: puntos,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async => Firebase.initializeApp());
  group('tinta', () {
    test('un trazo con presión da un contorno cerrado', () {
      final contorno = contornoTinta(
        _linea(0, 10, 200),
        const OpcionesTinta(tamano: 8),
      );
      expect(contorno.length, greaterThan(10));
      expect(svgDeContorno(contorno), startsWith('M'));
    });

    test('sin grosor no hay contorno', () {
      expect(
        contornoTinta(_linea(0, 0, 50), const OpcionesTinta(tamano: 0)),
        isEmpty,
      );
    });
  });

  group('dibujo', () {
    test('el SVG guarda los trazos para volver a editarlos', () {
      final dibujo = DatosDibujo(
        alto: 1500,
        fondo: FondoLienzo.cuadricula,
        trazos: [
          _trazo(_linea(10, 20, 300)),
          Trazo(
            herramienta: HerramientaTrazo.resaltador,
            color: 0xFFFFE066,
            grosor: 30,
            puntos: [const PuntoTinta(12.34, 56.78, 0.9), const PuntoTinta(90, 56, 0.4)],
          ),
        ],
      );
      final leido = DatosDibujo.desdeSvg(dibujo.aSvg())!;
      expect(leido.alto, 1500);
      expect(leido.fondo, FondoLienzo.cuadricula);
      expect(leido.trazos, hasLength(2));
      expect(leido.trazos[1].herramienta, HerramientaTrazo.resaltador);
      expect(leido.trazos[1].puntos.first.x, closeTo(12.3, 0.11));
      expect(leido.trazos[1].puntos.first.presion, closeTo(0.9, 0.011));
    });

    test('un SVG ajeno no se toma como dibujo', () {
      expect(DatosDibujo.desdeSvg('<svg><path d="M0 0"/></svg>'), isNull);
    });
  });

  group('edición de trazos', () {
    test('el borrador quita el trazo que toca y deja los demás', () {
      final trazos = [_trazo(_linea(0, 0, 100)), _trazo(_linea(0, 200, 100))];
      final quedan = borrarTrazosCompletos(trazos, const Offset(50, 2), 6);
      expect(quedan, hasLength(1));
      expect(quedan.single.puntos.first.y, 200);
    });

    test('el borrador parcial parte el trazo en dos', () {
      final quedan = borrarParcial([_trazo(_linea(0, 0, 200))], const Offset(100, 0), 8);
      expect(quedan, hasLength(2));
    });

    test('el lazo elige los trazos que encierra', () {
      final trazos = [_trazo(_linea(10, 10, 50)), _trazo(_linea(300, 300, 350))];
      final lazo = [const Offset(0, 0), const Offset(100, 0), const Offset(100, 40), const Offset(0, 40)];
      expect(seleccionarConLazo(trazos, lazo), {0});
    });

    test('la línea recta va de punta a punta', () {
      final recta = lineaRecta(const PuntoTinta(0, 0), const PuntoTinta(120, 60));
      expect(recta.first.x, 0);
      expect(recta.last.x, 120);
      expect(recta.last.y, 60);
    });
  });

  group('listas', () {
    test('poner y quitar tareas en varias líneas', () {
      const texto = 'Orar\nLeer';
      final puesta = alternarLista(texto, 0, texto.length, TipoLista.tareas);
      final conTareas = puesta.aplicarA(texto);
      expect(conTareas, '☐ Orar\n☐ Leer');
      final quitada = alternarLista(conTareas, 0, conTareas.length, TipoLista.tareas);
      expect(quitada.aplicarA(conTareas), texto);
    });

    test('las numeradas cuentan desde 1', () {
      const texto = 'uno\ndos\ntres';
      expect(
        alternarLista(texto, 0, texto.length, TipoLista.numerada).aplicarA(texto),
        '1. uno\n2. dos\n3. tres',
      );
    });

    test('Enter sigue la lista y un elemento vacío la termina', () {
      const texto = '2. dos\n';
      final sigue = continuarLista(texto, texto.length)!;
      expect(sigue.aplicarA(texto), '2. dos\n3. ');
      expect(sigue.cursor, '2. dos\n3. '.length);

      const vacio = '• uno\n• \n';
      final termina = continuarLista(vacio, vacio.length)!;
      expect(termina.aplicarA(vacio), '• uno\n');
    });

    test('tocar la casilla marca y desmarca la tarea', () {
      const texto = 'Hoy\n☐ Orar';
      final marcada = alternarTareaEn(texto, 4)!.aplicarA(texto);
      expect(marcada, 'Hoy\n☑ Orar');
      expect(alternarTareaEn(marcada, 4)!.aplicarA(marcada), texto);
      expect(alternarTareaEn(texto, 8), isNull);
    });
  });

  group('formato', () {
    test('cursiva, resaltado y color se ponen y se quitan', () {
      var doc = const RichNoteDocument(text: 'Dios es fiel', spans: []);
      doc = doc.applyFormat(0, 4, RichNoteFormat.italic);
      doc = doc.applyFormat(5, 12, RichNoteFormat.highlight, value: 'amarillo');
      doc = doc.applyFormat(0, 4, RichNoteFormat.color, value: 'azul');
      final restaurado = RichNoteDocument.fromStorage(doc.toStorage());
      expect(restaurado.formatIn(0, 4).italic, isTrue);
      expect(restaurado.formatIn(0, 4).color, 'azul');
      expect(restaurado.formatIn(5, 12).highlight, 'amarillo');

      doc = doc.applyFormat(0, 4, RichNoteFormat.italic);
      doc = doc.applyFormat(5, 12, RichNoteFormat.highlight);
      expect(doc.formatIn(0, 4).italic, isFalse);
      expect(doc.formatIn(5, 12).highlight, isNull);
    });

    test('el estilo Título se aplica a toda la línea', () {
      var doc = const RichNoteDocument(text: 'Gracia\nTexto', spans: []);
      doc = doc.applyParagraphStyle(2, 2, RichNoteParagraphStyle.title);
      final titulo = doc.formatIn(0, 6);
      expect(titulo.bold, isTrue);
      expect(titulo.fontSize, 24);
      expect(doc.formatIn(7, 12).fontSize, isNull);
      doc = doc.applyParagraphStyle(0, 0, RichNoteParagraphStyle.body);
      expect(doc.formatIn(0, 6).fontSize, isNull);
    });
  });

  test('las #etiquetas se leen sin repetir ni confundir correos', () {
    expect(
      etiquetasDe('#Gracia y #gracia, correo a#b, #x y #Oración'),
      ['gracia', 'oración'],
    );
    expect(rangosEtiquetas('Hola #fe'), [(5, 8)]);
  });

  test('el apunte guarda sus fotos, dibujos y si está fijado', () {
    final foto = AdjuntoNota.nuevo(TipoAdjunto.foto, proporcion: 0.75).copyWith(pie: 'Pizarra');
    final nota = SermonNote(
      id: 'n1',
      title: 'Fe',
      sermonDate: DateTime(2026, 10, 18),
      speaker: '',
      primaryVersionId: 'RVR1960',
      secondaryVersionId: 'NVI',
      centralPassage: null,
      notes: '',
      takeaway: '',
      verses: const [],
      highlights: const [],
      adjuntos: [foto],
      fijada: true,
      createdAt: DateTime(2026, 10, 18),
      updatedAt: DateTime(2026, 10, 18),
    );
    final leida = SermonNote.fromMap('n1', nota.toMap());
    expect(leida.fijada, isTrue);
    expect(leida.adjuntos.single.id, foto.id);
    expect(leida.adjuntos.single.pie, 'Pizarra');
    expect(leida.adjuntos.single.archivo, '${foto.id}.jpg');
    expect(leida.hasContent, isTrue);
  });

  group('PDF', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('apuntes_pdf_test_');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('exporta tareas, resaltados y fotos', () async {
      var doc = const RichNoteDocument(
        text: 'Pendientes\n☐ Orar\n☑ Leer Juan 3\n• Fe #gracia',
        spans: [],
      );
      doc = doc.applyParagraphStyle(0, 0, RichNoteParagraphStyle.title);
      doc = doc.applyFormat(19, 23, RichNoteFormat.highlight, value: 'verde');
      final nota = SermonNote(
        id: 'pdf',
        title: 'Apunte con fotos',
        sermonDate: DateTime(2026, 10, 18),
        speaker: 'Pastor Daniel',
        primaryVersionId: 'RVR1960',
        secondaryVersionId: 'NVI',
        centralPassage: null,
        notes: doc.toStorage(),
        takeaway: 'Orar más',
        verses: const [],
        highlights: const [],
        createdAt: DateTime(2026, 10, 18),
        updatedAt: DateTime(2026, 10, 18),
      );
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );
      final archivo = await SermonNoteExportService.I.exportSermonNoteToPdf(
        note: nota,
        chapterVerses: const [],
        imagenes: [ImagenPdf(png, 'Pizarra del domingo')],
      );
      expect(await archivo.exists(), isTrue);
      expect(await archivo.length(), greaterThan(1000));
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
}
