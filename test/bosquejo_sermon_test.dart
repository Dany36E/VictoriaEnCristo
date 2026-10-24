import 'dart:async';
import 'dart:io';

import 'package:app_quitar/models/bible/bosquejo_sermon.dart';
import 'package:app_quitar/screens/bible/bosquejo_editor_screen.dart';
import 'package:app_quitar/screens/bible/bosquejos_screen.dart';
import 'package:app_quitar/screens/bible/modo_pulpito_screen.dart';
import 'package:app_quitar/services/bible/bosquejo_export_service.dart';
import 'package:app_quitar/services/bible/bosquejo_sermon_service.dart';
import 'package:app_quitar/services/bible/notas_sync.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
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

const _juan = VersiculoBosquejo(
  referencia: 'Juan 3:16',
  bookNumber: 43,
  chapter: 3,
  verseStart: 16,
  verseEnd: 16,
  versionId: 'RVR1960',
  texto: 'Porque de tal manera amó Dios al mundo.',
);

BosquejoSermon _ejemplo() {
  final base = BosquejoSermon.nuevo(id: 'bosquejo_1');
  return base.copyWith(
    titulo: 'El amor de Dios',
    textoPrincipal: 'Juan 3:16-18',
    introduccion: 'Todos buscamos ser amados.',
    ilustracion: 'El padre que espera al hijo pródigo.',
    conclusion: 'Recibe hoy ese amor.',
    puntos: [
      const PuntoBosquejo(
        id: 'p1',
        titulo: 'Un amor grande',
        versiculos: [_juan],
        subpuntos: [
          SubpuntoBosquejo(id: 's1', texto: 'Alcanza al mundo'),
          SubpuntoBosquejo(id: 's2', texto: 'Nos alcanza a ti y a mí'),
          SubpuntoBosquejo(id: 's3', texto: 'No tiene condiciones'),
        ],
      ),
      const PuntoBosquejo(id: 'p2', titulo: 'Un amor que da'),
      const PuntoBosquejo(id: 'p3', titulo: 'Un amor que salva'),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  late Directory temporal;

  setUpAll(() async {
    await Firebase.initializeApp();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporal = await Directory.systemTemp.createTemp('bosquejo_test_');
    PathProviderPlatform.instance = _FakePathProvider(temporal.path);
    NotasSync.I.reiniciarParaPruebas(escritor: _SinConexion());
    BosquejoSermonService.I.stop();
  });

  tearDown(() async {
    BosquejoSermonService.I.stop();
    NotasSync.I.reiniciarParaPruebas();
    if (await temporal.exists()) await temporal.delete(recursive: true);
  });

  group('modelo', () {
    test('reordena puntos con la semántica de ReorderableListView', () {
      final b = _ejemplo();
      // Bajar el primero al final: onReorder(0, 3).
      expect(b.reordenarPunto(0, 3).puntos.map((p) => p.id), [
        'p2',
        'p3',
        'p1',
      ]);
      // Subir el último al principio: onReorder(2, 0).
      expect(b.reordenarPunto(2, 0).puntos.map((p) => p.id), [
        'p3',
        'p1',
        'p2',
      ]);
      // Soltar en el mismo lugar no cambia nada.
      expect(b.reordenarPunto(1, 2).puntos.map((p) => p.id), [
        'p1',
        'p2',
        'p3',
      ]);
    });

    test('reordena subpuntos solo dentro de su punto', () {
      final b = _ejemplo().reordenarSubpunto('p1', 2, 0);
      expect(b.puntos.first.subpuntos.map((s) => s.id), ['s3', 's1', 's2']);
      expect(b.puntos[1].subpuntos, isEmpty);
      final abajo = _ejemplo().reordenarSubpunto('p1', 0, 2);
      expect(abajo.puntos.first.subpuntos.map((s) => s.id), [
        's2',
        's1',
        's3',
      ]);
    });

    test('ida y vuelta por Firestore y por la cache local', () {
      final b = _ejemplo();
      for (final mapa in [b.toMap(), b.toLocalMap()]) {
        final leido = BosquejoSermon.fromMap(b.id, mapa);
        expect(leido.titulo, b.titulo);
        expect(leido.textoPrincipal, b.textoPrincipal);
        expect(leido.puntos.map((p) => p.id), ['p1', 'p2', 'p3']);
        expect(leido.puntos.first.subpuntos.map((s) => s.texto), [
          'Alcanza al mundo',
          'Nos alcanza a ti y a mí',
          'No tiene condiciones',
        ]);
        expect(leido.puntos.first.versiculos.single.texto, _juan.texto);
        expect(leido.huellaContenido, b.huellaContenido);
        expect(
          leido.updatedAt.millisecondsSinceEpoch,
          b.updatedAt.millisecondsSinceEpoch,
        );
      }
    });

    test('textoBuscable incluye puntos, subpuntos y versículos', () {
      final texto = _ejemplo().textoBuscable;
      expect(texto, contains('Un amor que salva'));
      expect(texto, contains('No tiene condiciones'));
      expect(texto, contains('amó Dios al mundo'));
      expect(BosquejoSermon.nuevo().hasContent, isFalse);
    });
  });

  group('exportar', () {
    test('Markdown en orden: texto, introducción, puntos, conclusión', () {
      final md = BosquejoExportService.aMarkdown(_ejemplo());
      expect(md, startsWith('# El amor de Dios\n'));
      expect(md, contains('**Texto:** Juan 3:16-18'));
      expect(md, contains('> Juan 3:16 — Porque de tal manera amó Dios'));
      expect(md, contains('- a. Alcanza al mundo'));
      expect(md, contains('- c. No tiene condiciones'));
      final orden = [
        '## Introducción',
        '## 1. Un amor grande',
        '## 2. Un amor que da',
        '## 3. Un amor que salva',
        '## Ilustración',
        '## Conclusión',
      ].map(md.indexOf).toList();
      expect(orden.every((i) => i >= 0), isTrue);
      expect([...orden]..sort(), orden);

      final reordenado = BosquejoExportService.aMarkdown(
        _ejemplo().reordenarPunto(0, 3),
      );
      expect(
        reordenado.indexOf('## 1. Un amor que da'),
        lessThan(reordenado.indexOf('## 3. Un amor grande')),
      );
    });

    test('PDF sin conexión', () async {
      final archivo = await BosquejoExportService.I.exportarPdf(_ejemplo());
      expect(await archivo.exists(), isTrue);
      expect(await archivo.length(), greaterThan(0));
    });

    test('Modo púlpito: introducción, un punto por página y conclusión', () {
      final paginas = PaginaPulpito.de(_ejemplo());
      expect(paginas.map((p) => p.etiqueta), [
        'Introducción',
        'Punto 1 de 3',
        'Punto 2 de 3',
        'Punto 3 de 3',
        'Ilustración',
        'Conclusión',
      ]);
      expect(paginas[1].subpuntos.first.$1, 'a. Alcanza al mundo');
    });
  });

  group('servicio', () {
    test('guardar sin conexión no se queda esperando al servidor', () async {
      final escritor = _SinConexion();
      NotasSync.I.reiniciarParaPruebas(escritor: escritor);
      NotasSync.demoraSinConexion = const Duration(milliseconds: 20);
      addTearDown(
        () => NotasSync.demoraSinConexion = const Duration(milliseconds: 1500),
      );
      await BosquejoSermonService.I.initSinNube('u1');

      await BosquejoSermonService.I
          .guardar(_ejemplo())
          .timeout(const Duration(seconds: 2));

      expect(BosquejoSermonService.I.porId('bosquejo_1')?.titulo,
          'El amor de Dios');
      expect(escritor.rutas, ['users/u1/sermonOutlines/bosquejo_1']);
      expect(
        NotasSync.I.guardadoPendiente('users/u1/sermonOutlines/bosquejo_1'),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(NotasSync.I.estado.value, EstadoNotasNube.esperandoConexion);

      // Al volver a abrir la app sigue en el teléfono y se reenvía.
      BosquejoSermonService.I.stop();
      await BosquejoSermonService.I.initSinNube('u1');
      expect(BosquejoSermonService.I.todos.single.id, 'bosquejo_1');
      expect(escritor.rutas.length, 2);
    });

    test('la nube no oculta bosquejos: más de 300 siguen visibles', () async {
      await BosquejoSermonService.I.initSinNube('u1');
      final servicio = BosquejoSermonService.I;
      BosquejoSermon n(int i) => BosquejoSermon.nuevo(
        id: 'b$i',
      ).copyWith(titulo: 'Bosquejo $i');
      servicio.aplicarSnapshot({
        for (var i = 0; i < 350; i++) 'b$i': n(i),
      }, desdeCache: false);
      expect(servicio.todos.length, 350);

      // Un snapshot de la cache incompleto no borra nada.
      servicio.aplicarSnapshot({
        for (var i = 0; i < 300; i++) 'b$i': n(i),
      }, desdeCache: true);
      expect(servicio.todos.length, 350);

      // Uno nuevo hecho en el teléfono sigue aunque el servidor no lo tenga.
      await servicio.guardar(n(999));
      // El servidor confirma que b0 se borró en otro dispositivo.
      servicio.aplicarSnapshot({
        for (var i = 1; i < 350; i++) 'b$i': n(i),
      }, desdeCache: false);
      expect(servicio.porId('b0'), isNull);
      expect(servicio.porId('b999'), isNotNull);
      expect(servicio.todos.length, 350);
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

    testWidgets('lista vacía con botón para crear', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const BosquejosScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Nuevo bosquejo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el editor reordena puntos y agrega uno sin desbordes', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await tester.runAsync(() => BosquejoSermonService.I.initSinNube('u1'));
      await tester.runAsync(() => BosquejoSermonService.I.guardar(_ejemplo()));

      await tester.pumpWidget(
        app(const BosquejoEditorScreen(bosquejoId: 'bosquejo_1')),
      );
      await tester.pump();
      expect(find.text('Punto 1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Mover el primer punto hacia abajo desde su menú (alternativa
      // accesible al arrastre).
      await tester.tap(find.byTooltip('Opciones del punto 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover abajo'));
      await tester.pumpAndSettle();
      final campos = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((c) => c.controller?.text)
          .where((t) => t == 'Un amor grande' || t == 'Un amor que da')
          .toList();
      expect(campos, ['Un amor que da', 'Un amor grande']);

      await tester.scrollUntilVisible(
        find.text('Agregar punto'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Agregar punto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar punto'));
      await tester.pump();
      expect(find.text('Punto 4', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Al salir se guarda en el teléfono.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      final guardado = BosquejoSermonService.I.porId('bosquejo_1')!;
      expect(guardado.puntos.map((p) => p.titulo).take(2), [
        'Un amor que da',
        'Un amor grande',
      ]);
      expect(guardado.puntos.length, 4);
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
