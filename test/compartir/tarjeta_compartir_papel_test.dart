import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_quitar/vec/vec_tema.dart';
import 'package:app_quitar/vec/vec_widgets.dart';
import 'package:app_quitar/widgets/compartir/tarjeta_compartir_papel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual/theme_matrix.dart';

const _corto = 'Todo lo puedo en Cristo que me fortalece.';
const _largo =
    'No os ha sobrevenido ninguna tentación que no sea humana; pero fiel es '
    'Dios, que no os dejará ser tentados más de lo que podéis resistir, sino '
    'que dará también juntamente con la tentación la salida, para que podáis '
    'soportar.';

Future<void> _capturar(
  WidgetTester tester,
  String nombre,
  Widget tarjeta,
) async {
  final llave = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(key: llave, child: tarjeta),
        ),
      ),
    ),
  );
  // Las imágenes (textura y personaje) se decodifican fuera del reloj falso.
  await tester.runAsync(() async {
    final contexto = llave.currentContext!;
    for (final ruta in [
      'assets/vec/texturas/papel_tile_512.png',
      PersonajeCompartir.victoria.ruta,
      PersonajeCompartir.timoteo.ruta,
    ]) {
      await precacheImage(AssetImage(ruta), contexto);
    }
  });
  await tester.pump();
  expect(tester.takeException(), isNull);
  // El personaje se asoma abajo de la tarjeta, sin taparla (con un margen
  // por el giro de la tarjeta).
  final tarjetaPapel = tester.getRect(find.byType(TarjetaPapel));
  final personaje = tester.getRect(find.byType(Image));
  expect(tarjetaPapel.bottom, lessThanOrEqualTo(personaje.top + 4));
  await tester.runAsync(() async {
    final limite =
        llave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagen = await limite.toImage(pixelRatio: 2);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final archivo = File('build/qa/compartir_$nombre.png');
    await archivo.parent.create(recursive: true);
    await archivo.writeAsBytes(png!.buffer.asUint8List());
  });
}

void main() {
  setUpThemeMatrix();

  testWidgets('tarjeta de papel para compartir en los tres formatos', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _capturar(
      tester,
      'cuadrada',
      const TarjetaCompartirPapel(
        texto: _corto,
        referencia: 'Filipenses 4:13',
        version: 'RVR1960',
        etiqueta: 'Versículo',
      ),
    );
    await _capturar(
      tester,
      'vertical_larga',
      const TarjetaCompartirPapel(
        texto: _largo,
        referencia: '1 Corintios 10:13',
        version: 'RVR1960',
        etiqueta: 'Versículo del día',
        proporcion: 0.8,
        personaje: PersonajeCompartir.timoteo,
      ),
    );
    await _capturar(
      tester,
      'historia',
      const TarjetaCompartirPapel(
        texto: _largo,
        referencia: '1 Corintios 10:13',
        etiqueta: 'Devocional',
        pie: 'La Chequera del Banco de la Fe',
        proporcion: 9 / 16,
      ),
    );
    // Cuadrada (la de la pantalla de plantillas), texto largo a la derecha y
    // letra grande: el personaje no tapa la versión y la letra se ajusta.
    await _capturar(
      tester,
      'cuadrada_larga_derecha',
      const TarjetaCompartirPapel(
        texto: _largo,
        referencia: '1 Corintios 10:13',
        version: 'RVR1960',
        alineacion: TextAlign.right,
        escalaTexto: 1.3,
      ),
    );
    expect(find.byType(FondoPapel), findsNothing);
  });

  // Con un papel oscuro activo, la imagen sale en ese papel (hoja, tarjeta y
  // letra), igual que la app.
  for (final (nombre, paleta) in [
    ('kraft', VecPaleta.kraftOscuro),
    ('noche', VecPaleta.nocheAzul),
  ]) {
    testWidgets('tarjeta para compartir en papel $nombre', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      VecColores.actual = paleta;
      addTearDown(() => VecColores.actual = VecPaleta.claro);

      await _capturar(
        tester,
        'cuadrada_$nombre',
        const TarjetaCompartirPapel(
          texto: _corto,
          referencia: 'Filipenses 4:13',
          version: 'RVR1960',
          etiqueta: 'Versículo',
        ),
      );
      final hoja = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(TarjetaCompartirPapel),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((hoja.decoration as BoxDecoration).color, paleta.crema);
    });
  }

  // Tamaño con que se ve el versículo: la letra por la reducción del
  // FittedBox (el ancho dibujado entre el ancho de su caja).
  double tamanoVisible(WidgetTester tester, String texto) {
    final hallado = find.text(texto);
    final parrafo = tester.renderObject<RenderParagraph>(hallado);
    final reduccion = tester.getSize(hallado).width / parrafo.size.width;
    return tester.widget<Text>(hallado).style!.fontSize! * reduccion;
  }

  testWidgets('el control de tamaño agranda el versículo sin achicarlo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // El deslizador va de 34 a 56: escala de 1 a 1.65.
    for (final (texto, proporcion) in [
      (_corto, 1.0),
      (_largo, 1.0),
      (_largo, 0.8),
    ]) {
      final tamanos = <double>[];
      for (final escala in [1.0, 1.3, 1.65]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: TarjetaCompartirPapel(
                texto: texto,
                referencia: '1 Corintios 10:13',
                proporcion: proporcion,
                escalaTexto: escala,
              ),
            ),
          ),
        );
        tamanos.add(tamanoVisible(tester, texto));
      }
      final caso = '${texto.length} letras, proporción $proporcion: $tamanos';
      for (var i = 1; i < tamanos.length; i++) {
        // Nunca se ve más chico al subir el control.
        expect(
          tamanos[i],
          greaterThanOrEqualTo(tamanos[i - 1] - 0.01),
          reason: caso,
        );
      }
      if (texto == _corto) {
        // Un versículo corto tiene lugar: sí crece.
        expect(tamanos.last, greaterThan(tamanos.first * 1.3), reason: caso);
      }
    }
  });
}
