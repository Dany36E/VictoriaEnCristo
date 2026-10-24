/// Dibuja un widget de Flutter a PNG fuera de pantalla, para que los widgets
/// de Android muestren exactamente la misma tarjeta que se ve en la app.
///
/// Es la idea de `HomeWidget.renderFlutterWidget`, pero espera a que las
/// imágenes y los SVG del kit terminen de cargar (se vuelven a construir
/// varias veces) y da un `MediaQuery` con la densidad pedida.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class WidgetSnapshotRenderer {
  WidgetSnapshotRenderer._();

  /// Carga [rutas] en la caché de imágenes antes de dibujar, para que
  /// `Image.asset` las tenga desde el primer cuadro.
  static Future<void> precargar(
    Iterable<String> rutas, {
    double pixelRatio = 1,
  }) async {
    final config = ImageConfiguration(devicePixelRatio: pixelRatio);
    await Future.wait(
      rutas.map((ruta) {
        final completer = Completer<void>();
        final stream = AssetImage(ruta).resolve(config);
        late final ImageStreamListener listener;
        listener = ImageStreamListener(
          (_, _) {
            if (!completer.isCompleted) completer.complete();
            stream.removeListener(listener);
          },
          onError: (_, _) {
            if (!completer.isCompleted) completer.complete();
            stream.removeListener(listener);
          },
        );
        stream.addListener(listener);
        return completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
      }),
    );
  }

  /// PNG de [widget] dibujado en una caja de [logicalSize] a [pixelRatio].
  /// Devuelve `null` si no se pudo dibujar.
  static Future<Uint8List?> renderPng(
    Widget widget, {
    required Size logicalSize,
    double pixelRatio = 2,
    int pasadas = 4,
    Duration espera = const Duration(milliseconds: 40),
  }) async {
    final view = ui.PlatformDispatcher.instance.implicitView;
    if (view == null) return null;

    final boundary = RenderRepaintBoundary();
    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());
    RenderObjectToWidgetElement<RenderBox>? root;
    try {
      final renderView = RenderView(
        view: view,
        child: RenderPositionedBox(
          alignment: Alignment.center,
          child: boundary,
        ),
        configuration: ViewConfiguration(
          logicalConstraints: BoxConstraints.tight(logicalSize),
          devicePixelRatio: 1,
        ),
      );
      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      root = RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: MediaQuery(
          data: MediaQueryData(
            size: logicalSize,
            devicePixelRatio: pixelRatio,
            textScaler: TextScaler.noScaling,
            disableAnimations: true,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: DefaultTextStyle(
              style: const TextStyle(),
              child: SizedBox.fromSize(size: logicalSize, child: widget),
            ),
          ),
        ),
      ).attachToRenderTree(buildOwner);

      void cuadro() {
        buildOwner.buildScope(root!);
        buildOwner.finalizeTree();
        pipelineOwner.flushLayout();
        pipelineOwner.flushCompositingBits();
        pipelineOwner.flushPaint();
      }

      // Las imágenes y los SVG avisan con setState al terminar de cargar:
      // unas pasadas con pausa dejan que lleguen antes de la foto.
      cuadro();
      for (var i = 1; i < pasadas; i++) {
        await Future<void>.delayed(espera);
        cuadro();
      }

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes?.buffer.asUint8List();
    } catch (e) {
      debugPrint('📱 [WIDGET] renderPng error: $e');
      return null;
    } finally {
      // Desmontar el árbol para soltar los listeners de imágenes.
      try {
        if (root != null) {
          RenderObjectToWidgetAdapter<RenderBox>(
            container: boundary,
          ).attachToRenderTree(buildOwner, root);
          buildOwner.finalizeTree();
        }
      } catch (_) {}
    }
  }
}
