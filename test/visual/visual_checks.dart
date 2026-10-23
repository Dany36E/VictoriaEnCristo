import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Revisa que el fondo pintado de cada botón (FAB, botones, chips) cubra
/// por completo su texto e íconos. Atrapa casos como un FAB extendido cuyo
/// círculo no cubre la etiqueta "Nueva oración".
void expectButtonBackgroundsCoverContent(WidgetTester tester) {
  expect(
    problemasDeBotones(tester),
    isEmpty,
    reason: 'El fondo de los botones debe cubrir todo su contenido',
  );
}

/// Lo mismo que [expectButtonBackgroundsCoverContent], como lista.
List<String> problemasDeBotones(WidgetTester tester) {
  final buttons = find.byWidgetPredicate(
    (w) =>
        w is FloatingActionButton ||
        w is ButtonStyleButton ||
        w is RawChip ||
        w is ChoiceChip ||
        w is FilterChip ||
        w is ActionChip,
  );
  final problems = <String>[];
  for (final element in buttons.evaluate()) {
    final shape = _firstPhysicalShape(element.renderObject!);
    if (shape == null) continue;
    // La figura que realmente se pinta (círculo, píldora…), no la caja.
    final figura =
        shape.clipper?.getClip(shape.size) ??
        (Path()..addRect(Offset.zero & shape.size));
    _visit(shape, (node) {
      if (node is! RenderParagraph) return;
      final box = node;
      if (!box.hasSize || box.size.isEmpty) return;
      final r = MatrixUtils.transformRect(
        box.getTransformTo(shape),
        Offset.zero & box.size,
      ).deflate(1);
      final puntos = [r.centerLeft, r.centerRight, r.topCenter, r.bottomCenter];
      if (puntos.any((p) => !figura.contains(p))) {
        final texto = node.text.toPlainText();
        // Los íconos de Material son un solo glifo de uso privado.
        final label = texto.runes.every((c) => c >= 0xE000 && c <= 0xF8FF)
            ? 'ícono'
            : '"$texto"';
        problems.add(
          '${element.widget.runtimeType}: $label se sale del fondo '
          '(contenido $r, fondo ${figura.getBounds()})',
        );
      }
    });
  }
  return problems;
}

/// Contraste WCAG de cada texto visible contra lo que realmente está pintado
/// detrás. El color del texto sale de su estilo (con la opacidad de sus
/// ancestros) y el del fondo del color más frecuente de la captura en el área
/// del texto. Atrapa letras oscuras sobre fondo oscuro al cambiar a modo
/// oscuro, y viceversa. El relleno de un texto con contorno se mide contra
/// el color del contorno.
///
/// [captura] son los píxeles RGBA de [limite] (ver [capturarPixeles]).
void expectReadableText(
  WidgetTester tester,
  RenderRepaintBoundary limite,
  ui.Image imagen,
  ByteData captura,
) {
  expect(
    problemasDeContraste(limite, imagen, captura),
    isEmpty,
    reason: 'Todo texto visible debe leerse (WCAG AA) sobre su fondo real',
  );
}

/// Lo mismo que [expectReadableText], como lista.
List<String> problemasDeContraste(
  RenderRepaintBoundary limite,
  ui.Image imagen,
  ByteData captura,
) {
  final problemas = <String>[];
  Rect? rectEnCaptura(RenderParagraph node) {
    final rect =
        MatrixUtils.transformRect(
          node.getTransformTo(limite),
          Offset.zero & node.size,
        ).intersect(
          Offset.zero & Size(imagen.width.toDouble(), imagen.height.toDouble()),
        );
    return rect.width < 2 || rect.height < 2 ? null : rect;
  }

  // Texto con contorno (letreros): el mismo texto se pinta dos veces, una con
  // trazo grueso (`foreground` de tipo stroke) y otra encima con el relleno.
  // El relleno se lee contra el contorno, no contra el fondo de la pantalla,
  // solo si el contorno es visible y dice lo mismo.
  final contornos = <(Rect, Color, String)>[];
  _visit(limite, (node) {
    if (node is! RenderParagraph || !node.hasSize || node.size.isEmpty) return;
    final trazo = _trazoGrueso(node.text);
    if (trazo == null || _opacidadVisible(node, limite) == null) return;
    final rect = rectEnCaptura(node);
    if (rect != null) {
      contornos.add((rect, trazo.color, node.text.toPlainText()));
    }
  });
  Color? contornoDe(Rect rect, String texto) {
    for (final (r, color, textoContorno) in contornos) {
      final comun = r.intersect(rect);
      if (textoContorno == texto &&
          comun.width > 0 &&
          comun.height > 0 &&
          comun.width * comun.height >= rect.width * rect.height * 0.9) {
        return color;
      }
    }
    return null;
  }

  _visit(limite, (node) {
    if (node is! RenderParagraph || !node.hasSize || node.size.isEmpty) return;
    final opacidad = _opacidadVisible(node, limite);
    if (opacidad == null) return;
    final rect = rectEnCaptura(node);
    if (rect == null || _tapado(limite, node, rect.center)) return;
    final contorno = contornoDe(rect, node.text.toPlainText());
    final modaGeneral = _colorMasFrecuente(captura, imagen.width, rect)!;
    node.text.visitChildren((span) {
      if (span is! TextSpan) return true;
      final texto = span.text?.trim() ?? '';
      if (texto.isEmpty || !texto.runes.any(_esLetraODigito)) return true;
      final estilo = _estiloEfectivo(node.text, span);
      final color = estilo?.color;
      if (color == null) return true;
      final conOpacidad = color.withValues(alpha: color.a * opacidad);
      // El fondo es el color más frecuente que no sea el del propio texto
      // (en textos gruesos las letras pueden ocupar más área que el fondo).
      final aprox = Color.alphaBlend(conOpacidad, modaGeneral);
      final fondo =
          contorno ??
          _colorMasFrecuente(captura, imagen.width, rect, excepto: aprox) ??
          aprox;
      final frente = Color.alphaBlend(conOpacidad, fondo);
      final ratio = _contraste(frente, fondo);
      final tamano = (estilo!.fontSize ?? 14) * node.textScaler.scale(1);
      final grande =
          tamano >= 18 ||
          (tamano >= 14 &&
              (estilo.fontWeight?.value ?? 400) >= FontWeight.w700.value);
      final minimo = grande ? 3.0 : 4.5;
      if (ratio < minimo) {
        problemas.add(
          '"${texto.length > 40 ? '${texto.substring(0, 40)}…' : texto}" '
          'contraste ${ratio.toStringAsFixed(2)} < $minimo '
          '(texto ${_hex(frente)} sobre ${_hex(fondo)}, '
          '${tamano.toStringAsFixed(0)} px)',
        );
      }
      return true;
    });
  });
  return problemas;
}

/// Si en [punto] (coordenadas de [limite]) queda encima algo ajeno al texto,
/// como un botón flotante sobre contenido que se desplaza (y que según el
/// largo del versículo del día cae debajo o no), la captura no muestra el
/// fondo del texto y su contraste no se puede medir ahí.
bool _tapado(RenderRepaintBoundary limite, RenderParagraph node, Offset punto) {
  final resultado = BoxHitTestResult();
  if (!limite.hitTest(resultado, position: punto)) return false;
  final arriba = resultado.path.first.target;
  if (arriba is! RenderObject) return false;
  // El propio texto, algo que lo contiene o algo dentro de él (WidgetSpan).
  for (RenderObject? r = node; r != null; r = r.parent) {
    if (r == arriba) return false;
  }
  for (RenderObject? r = arriba; r != null; r = r.parent) {
    if (r == node) return false;
  }
  return true;
}

/// Píxeles RGBA de [limite], para [expectReadableText].
Future<(ui.Image, ByteData)> capturarPixeles(
  RenderRepaintBoundary limite,
) async {
  final imagen = await limite.toImage();
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
  return (imagen, datos!);
}

/// Opacidad acumulada de los ancestros, o null si el texto no se pinta
/// (fuera de escena, pestaña oculta o casi transparente a propósito).
double? _opacidadVisible(RenderObject node, RenderObject limite) {
  var opacidad = 1.0;
  RenderObject? hijo = node;
  var actual = node.parent;
  while (actual != null && actual != limite) {
    if (actual is RenderOffstage && actual.offstage) return null;
    if (actual is RenderIndexedStack) {
      final visible = actual.index == null
          ? null
          : _hijoEn(actual, actual.index!);
      if (visible != hijo) return null;
    }
    if (actual is RenderOpacity) opacidad *= actual.opacity;
    if (actual is RenderAnimatedOpacity) opacidad *= actual.opacity.value;
    hijo = actual;
    actual = actual.parent;
  }
  return opacidad < 0.15 ? null : opacidad;
}

RenderBox? _hijoEn(RenderIndexedStack stack, int index) {
  var i = 0;
  RenderBox? encontrado;
  stack.visitChildren((c) {
    if (i++ == index) encontrado = c as RenderBox;
  });
  return encontrado;
}

/// El `foreground` de trazo grueso de un texto con contorno, si lo tiene
/// (Text.rich envuelve los spans en uno con el estilo por defecto).
Paint? _trazoGrueso(InlineSpan span) {
  final f = span.style?.foreground;
  if (f != null && f.style == PaintingStyle.stroke && f.strokeWidth >= 3) {
    return f;
  }
  if (span is TextSpan) {
    for (final hijo in span.children ?? const <InlineSpan>[]) {
      final trazo = _trazoGrueso(hijo);
      if (trazo != null) return trazo;
    }
  }
  return null;
}

TextStyle? _estiloEfectivo(InlineSpan raiz, InlineSpan objetivo) {
  TextStyle? resultado;
  bool buscar(InlineSpan span, TextStyle? heredado) {
    final estilo = heredado?.merge(span.style) ?? span.style;
    if (identical(span, objetivo)) {
      resultado = estilo;
      return true;
    }
    if (span is TextSpan) {
      for (final hijo in span.children ?? const <InlineSpan>[]) {
        if (buscar(hijo, estilo)) return true;
      }
    }
    return false;
  }

  buscar(raiz, null);
  return resultado;
}

bool _esLetraODigito(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0xC0 && c <= 0x24F);

Color? _colorMasFrecuente(ByteData datos, int ancho, Rect r, {Color? excepto}) {
  bool cercaDelTexto(int cr, int cg, int cb) {
    if (excepto == null) return false;
    final dr = cr - (excepto.r * 255), dg = cg - (excepto.g * 255);
    final db = cb - (excepto.b * 255);
    return dr * dr + dg * dg + db * db < 48 * 48;
  }

  final cuenta = <int, int>{};
  var total = 0;
  final paso = (r.width * r.height > 4000) ? 2 : 1;
  for (var y = r.top.floor(); y < r.bottom.floor(); y += paso) {
    for (var x = r.left.floor(); x < r.right.floor(); x += paso) {
      final i = (y * ancho + x) * 4;
      total++;
      if (cercaDelTexto(
        datos.getUint8(i),
        datos.getUint8(i + 1),
        datos.getUint8(i + 2),
      )) {
        continue;
      }
      // Agrupar en 16 niveles por canal para que el ruido no divida la moda.
      final clave =
          (datos.getUint8(i) >> 4) << 8 |
          (datos.getUint8(i + 1) >> 4) << 4 |
          (datos.getUint8(i + 2) >> 4);
      cuenta[clave] = (cuenta[clave] ?? 0) + 1;
    }
  }
  // Casi todo el área tiene el color del texto: el texto es invisible y
  // lo demás son píxeles sueltos (bordes, subrayados), no el fondo.
  final restantes = cuenta.values.fold(0, (a, b) => a + b);
  if (restantes < total * 0.15) return null;
  final moda = cuenta.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  // Promedio exacto de los píxeles de ese grupo.
  var rs = 0, gs = 0, bs = 0, n = 0;
  for (var y = r.top.floor(); y < r.bottom.floor(); y += paso) {
    for (var x = r.left.floor(); x < r.right.floor(); x += paso) {
      final i = (y * ancho + x) * 4;
      final cr = datos.getUint8(i),
          cg = datos.getUint8(i + 1),
          cb = datos.getUint8(i + 2);
      if (((cr >> 4) << 8 | (cg >> 4) << 4 | (cb >> 4)) == moda) {
        rs += cr;
        gs += cg;
        bs += cb;
        n++;
      }
    }
  }
  return Color.fromARGB(255, rs ~/ n, gs ~/ n, bs ~/ n);
}

double _contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final claro = la > lb ? la : lb, oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

String _hex(Color c) =>
    (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

RenderPhysicalShape? _firstPhysicalShape(RenderObject root) {
  RenderPhysicalShape? found;
  void walk(RenderObject node) {
    if (found != null) return;
    if (node is RenderPhysicalShape) {
      found = node;
      return;
    }
    node.visitChildren(walk);
  }

  walk(root);
  return found;
}

void _visit(RenderObject node, void Function(RenderObject) f) {
  f(node);
  node.visitChildren((c) => _visit(c, f));
}
