import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Revisa que el fondo pintado de cada botón (FAB, botones, chips) cubra
/// por completo su texto e íconos. Atrapa casos como un FAB extendido cuyo
/// círculo no cubre la etiqueta "Nueva oración".
void expectButtonBackgroundsCoverContent(WidgetTester tester) {
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
  expect(
    problems,
    isEmpty,
    reason: 'El fondo de los botones debe cubrir todo su contenido',
  );
}

/// Contraste WCAG del texto contra lo que realmente está pintado detrás
/// (lee los píxeles de la captura). Atrapa letras oscuras sobre fondo
/// oscuro al cambiar a modo oscuro, y viceversa.
Future<void> expectReadableText(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}

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
