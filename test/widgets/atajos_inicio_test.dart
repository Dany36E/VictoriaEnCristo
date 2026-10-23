import 'dart:io';

import 'package:app_quitar/services/atajos_service.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:app_quitar/widgets/home/atajos_inicio.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase's own test transport; no calls reach a remote backend.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child, {AppThemeData? tema}) => _appCon(child, tema ?? AppThemeData.paper);

Widget _appCon(Widget child, AppThemeData tema) =>
    MaterialApp(
      theme: AppTheme.paperTheme,
      builder: (context, c) => AppThemeData.provider(theme: tema, child: c!),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

const _seccion = Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [BotonEditarAtajos(), AtajosInicio()],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'app_theme_id': 'papel'});
    await ThemeService().initialize();
  });

  setUp(() => AtajosService.I.elegidos.value = AtajosService.predeterminados);

  group('AtajosService', () {
    test('sin elección guardada usa Biblia, Estudio bíblico y Apuntes', () async {
      SharedPreferences.setMockInitialValues({});
      AtajosService.I.elegidos.value = const [];
      await AtajosService.I.cargar();
      expect(AtajosService.I.elegidos.value, ['biblia', 'estudio', 'apuntes']);
    });

    test('limpiar quita ids desconocidos y repetidos y respeta el máximo', () {
      expect(
        AtajosService.limpiar(['frasco', 'x', 'frasco', 'biblia']),
        ['frasco', 'biblia'],
      );
      final todos = AtajosService.catalogo.map((a) => a.id);
      expect(AtajosService.limpiar(todos), hasLength(AtajosService.maximo));
    });

    test('guardar persiste el orden, incluso una lista vacía', () async {
      SharedPreferences.setMockInitialValues({});
      await AtajosService.I.guardar(['apuntes', 'biblia']);
      await AtajosService.I.cargar();
      expect(AtajosService.I.elegidos.value, ['apuntes', 'biblia']);

      await AtajosService.I.guardar([]);
      await AtajosService.I.cargar();
      expect(AtajosService.I.elegidos.value, isEmpty);
    });

    test('cada atajo tiene su dibujo de papel, su grupo y se sabe abrir', () {
      for (final a in AtajosService.catalogo) {
        expect(File(a.dibujo).existsSync(), isTrue, reason: a.dibujo);
        expect(AtajosService.grupos, contains(a.grupo), reason: a.id);
        expect(a.tituloCorto.length, lessThanOrEqualTo(12), reason: a.id);
      }
      expect(
        idsQueSeAbren,
        AtajosService.catalogo.map((a) => a.id).toSet(),
      );
    });
  });

  testWidgets('Inicio muestra los tres atajos y se activan con lector de '
      'pantalla', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_seccion));
    await tester.pumpAndSettle();

    for (final titulo in ['Biblia', 'Estudio bíblico', 'Apuntes']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(titulo)),
        isSemantics(label: titulo, isButton: true, hasTapAction: true),
      );
    }
    semantics.dispose();
  });

  testWidgets('Apuntes y Estudio muestran sus opciones', (tester) async {
    await tester.pumpWidget(_app(_seccion));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apuntes'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo apunte'), findsOneWidget);
    expect(find.text('Apuntes guardados'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Estudio bíblico'));
    await tester.pumpAndSettle();
    expect(find.text('Empezar nuevo estudio'), findsOneWidget);
    expect(find.text('Estudio con amigos'), findsOneWidget);
  });

  testWidgets('el editor agrega, quita y reordena atajos', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(_seccion));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar Frasco de versículos'));
    await tester.pump();
    await tester.tap(find.byTooltip('Quitar Biblia'));
    await tester.pump();
    expect(AtajosService.I.elegidos.value, ['estudio', 'apuntes', 'frasco']);

    // Arrastra «Frasco de versículos» al principio.
    final asa = find.byIcon(Icons.drag_handle_rounded);
    await tester.timedDrag(
      asa.at(2),
      tester.getCenter(asa.at(0)) - tester.getCenter(asa.at(2)) -
          const Offset(0, 20),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(AtajosService.I.elegidos.value, ['frasco', 'estudio', 'apuntes']);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Frasco de versículos'), findsOneWidget);
    expect(find.text('Biblia'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(AtajosService.clave), [
      'frasco',
      'estudio',
      'apuntes',
    ]);
  });

  testWidgets('el editor no deja pasar del máximo', (tester) async {
    AtajosService.I.elegidos.value = AtajosService.catalogo
        .take(AtajosService.maximo)
        .map((a) => a.id)
        .toList();
    await tester.pumpWidget(_app(const BotonEditarAtajos()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    final ultimo = AtajosService.catalogo.last;
    await tester.scrollUntilVisible(
      find.byTooltip('Agregar ${ultimo.titulo}'),
      300,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ).first,
    );
    final boton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Agregar ${ultimo.titulo}'),
        matching: find.byType(IconButton),
      ),
    );
    expect(boton.onPressed, isNull);
    expect(AtajosService.I.elegidos.value, hasLength(AtajosService.maximo));
  });

  testWidgets('con letra grande en un teléfono angosto usa dos columnas', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(const AtajosInicio()));
    await tester.pumpAndSettle();

    final dibujos = find.byType(Image);
    final biblia = tester.getTopLeft(dibujos.at(0));
    final estudio = tester.getTopLeft(dibujos.at(1));
    final apuntes = tester.getTopLeft(dibujos.at(2));
    expect(estudio.dy, closeTo(biblia.dy, 2));
    expect(estudio.dx, greaterThan(biblia.dx));
    expect(apuntes.dy, greaterThan(biblia.dy + 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin atajos invita a agregarlos', (tester) async {
    AtajosService.I.elegidos.value = const [];
    await tester.pumpWidget(_app(const AtajosInicio()));
    await tester.pumpAndSettle();
    expect(find.text('Agregar atajos'), findsOneWidget);
  });

  test('Android tiene el dibujo de cada atajo y lo conoce por su id', () {
    final kotlin = File(
      'android/app/src/main/kotlin/com/example/app_quitar/Atajos.kt',
    ).readAsStringSync();
    final deKotlin = RegExp(
      r'"(\w+)" to R\.drawable\.atajo_(\w+)',
    ).allMatches(kotlin).map((m) {
      expect(m[1], m[2]);
      return m[1]!;
    }).toSet();

    expect(deKotlin, AtajosService.catalogo.map((a) => a.id).toSet());
    for (final id in deKotlin) {
      final dibujo = File(
        'android/app/src/main/res/drawable-nodpi/atajo_$id.webp',
      );
      expect(dibujo.existsSync(), isTrue, reason: dibujo.path);
    }
    expect(kotlin, contains('"$prefijoRutaAtajo\$id"'));
  });
}
