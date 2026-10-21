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

Widget _app(Widget child, {AppThemeData tema = AppThemeData.paper}) =>
    MaterialApp(
      theme: tema.isPaper ? AppTheme.paperTheme : ThemeData.dark(),
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
        AtajosService.limpiar(['diario', 'x', 'diario', 'biblia']),
        ['diario', 'biblia'],
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

    test('cada atajo tiene su dibujo de papel', () {
      for (final a in AtajosService.catalogo) {
        expect(File(a.dibujo).existsSync(), isTrue, reason: a.dibujo);
      }
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

  testWidgets('el editor agrega y quita atajos', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app(_seccion));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    final hoja = find.byType(BottomSheet);
    await tester.tap(find.descendant(of: hoja, matching: find.text('Diario')));
    await tester.pump();
    await tester.tap(find.descendant(of: hoja, matching: find.text('Biblia')));
    await tester.pump();
    expect(AtajosService.I.elegidos.value, ['estudio', 'apuntes', 'diario']);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Diario'), findsOneWidget);
    expect(find.text('Biblia'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(AtajosService.clave), [
      'estudio',
      'apuntes',
      'diario',
    ]);
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

  testWidgets('en los temas normales usa íconos de Material', (tester) async {
    await tester.pumpWidget(
      _app(const AtajosInicio(), tema: AppThemeData.nightPure),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  test('el widget y los accesos del ícono de Android abren atajos que '
      'existen', () {
    final accesos = File(
      'android/app/src/main/res/xml/shortcuts.xml',
    ).readAsStringSync();
    final widget = File(
      'android/app/src/main/kotlin/com/example/app_quitar/'
      'AtajosWidgetProvider.kt',
    ).readAsStringSync();
    final deAccesos = RegExp(
      '$prefijoRutaAtajo(\\w+)',
    ).allMatches(accesos).map((m) => m[1]!).toSet();
    final deWidget = RegExp(
      r'_texto, "(\w+)"\)',
    ).allMatches(widget).map((m) => m[1]!).toSet();

    const esperados = {'biblia', 'estudio', 'apuntes'};
    expect(deAccesos, esperados);
    expect(deWidget, esperados);
    for (final id in esperados) {
      expect(AtajosService.porId(id), isNotNull, reason: id);
    }
  });
}
