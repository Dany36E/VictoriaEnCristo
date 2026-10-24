import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// READER VERSE LOCATOR — Llevar el lector EXACTAMENTE a un versículo.
///
/// Antes se estimaba `índice × tamañoDeLetra × 2.2`, que fallaba con
/// versículos largos, títulos de sección, modo estudio o letra grande.
///
/// Ahora cada versículo construido lleva una GlobalKey. Como la lista es
/// perezosa (SliverList), el versículo buscado puede no existir todavía:
///   1. Si ya está construido → Scrollable.ensureVisible (posición exacta).
///   2. Si no, se mide la posición real de los versículos construidos, se
///      interpola/extrapola dónde debería estar el buscado ([estimateOffset]),
///      se salta ahí y se repite en el siguiente frame (converge en 1-3).
/// ═══════════════════════════════════════════════════════════════════════════
class ReaderVerseLocator {
  final Map<int, GlobalKey> _keys = {};

  /// Clave del versículo [verseNumber] (estable mientras viva el lector).
  GlobalKey keyFor(int verseNumber) => _keys.putIfAbsent(
    verseNumber,
    () => GlobalKey(debugLabel: 'versiculo-$verseNumber'),
  );

  /// Posición de scroll (en píxeles) en la que el borde superior de cada
  /// versículo construido coincide con el borde superior del viewport.
  Map<int, ({double top, double height})> measureBuilt() {
    final out = <int, ({double top, double height})>{};
    _keys.forEach((verse, key) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) return;
      final top = viewport.getOffsetToReveal(box, 0.0).offset;
      out[verse] = (top: top, height: box.size.height);
    });
    return out;
  }

  /// Desplaza hasta [verse]. [topInset] = alto de la cabecera flotante que
  /// tapa el inicio del contenido. Devuelve true si lo logró.
  Future<bool> scrollToVerse(
    ScrollController controller,
    int verse, {
    double topInset = 64,
    Duration duration = const Duration(milliseconds: 450),
    int maxAttempts = 8,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!controller.hasClients) {
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      final position = controller.position;
      final measured = measureBuilt();
      final exact = measured[verse];
      if (exact != null) {
        final target = (exact.top - topInset).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((position.pixels - target).abs() < 1) return true;
        // Tras saltos de aproximación el ajuste final es una animación corta.
        final d = attempt == 0 ? duration : const Duration(milliseconds: 180);
        if (d == Duration.zero) {
          controller.jumpTo(target);
        } else {
          await controller.animateTo(
            target,
            duration: d,
            curve: Curves.easeOut,
          );
        }
        if (!controller.hasClients) return false;
        // Las alturas pueden cambiar al construir (títulos, fuentes): verificar.
        final again = measureBuilt()[verse];
        if (again == null) continue;
        final settled = (again.top - topInset).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((position.pixels - settled).abs() < 2) return true;
        controller.jumpTo(settled);
        return true;
      }
      final estimate = estimateOffset(verse, {
        for (final e in measured.entries) e.key: e.value.top,
      }, fallbackPerVerse: position.viewportDimension / 4);
      if (estimate == null) {
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      controller.jumpTo(
        (estimate - topInset).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
    return false;
  }

  /// Primer versículo visible bajo la cabecera (el «punto de lectura»).
  int? firstVisibleVerse(ScrollController controller, {double topInset = 64}) {
    if (!controller.hasClients) return null;
    final pixels = controller.position.pixels;
    return firstVisibleFrom(measureBuilt(), pixels + topInset);
  }

  /// Lógica pura de [firstVisibleVerse]: el versículo de menor número cuyo
  /// borde inferior queda por debajo de [readingLine] (con un margen de 8 px
  /// para no elegir uno que apenas asoma).
  static int? firstVisibleFrom(
    Map<int, ({double top, double height})> measured,
    double readingLine,
  ) {
    int? best;
    for (final e in measured.entries) {
      final bottom = e.value.top + e.value.height;
      if (bottom > readingLine + 8) {
        if (best == null || e.key < best) best = e.key;
      }
    }
    return best;
  }

  /// Estima el offset del borde superior de [verse] a partir de los offsets
  /// medidos de otros versículos ([samples]: versículo → offset superior).
  /// Interpola entre vecinos medidos o extrapola con la altura media.
  static double? estimateOffset(
    int verse,
    Map<int, double> samples, {
    double fallbackPerVerse = 80,
  }) {
    if (samples.isEmpty) return null;
    final exact = samples[verse];
    if (exact != null) return exact;
    final keys = samples.keys.toList()..sort();
    int? below; // mayor versículo medido < verse
    int? above; // menor versículo medido > verse
    for (final k in keys) {
      if (k < verse) below = k;
      if (k > verse) {
        above = k;
        break;
      }
    }
    if (below != null && above != null) {
      final a = samples[below]!;
      final b = samples[above]!;
      return a + (b - a) * (verse - below) / (above - below);
    }
    double perVerse = fallbackPerVerse;
    if (keys.length >= 2) {
      final span = samples[keys.last]! - samples[keys.first]!;
      final count = keys.last - keys.first;
      if (count > 0 && span > 0) perVerse = span / count;
    }
    if (below != null) {
      return samples[below]! + perVerse * (verse - below);
    }
    return samples[above]! - perVerse * (above! - verse);
  }
}
