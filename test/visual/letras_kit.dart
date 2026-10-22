import 'package:flutter/services.dart';

/// Carga las letras del kit (la app va siempre en papel). Sin ellas las
/// pruebas dibujan con la letra de prueba, más ancha, y salen desbordes que
/// en la app no existen.
Future<void> cargarLetrasDelKit() async {
  for (final (familia, archivo) in [
    ('LilitaOne', 'LilitaOne-Regular.ttf'),
    ('PatrickHand', 'PatrickHand-Regular.ttf'),
    ('CaveatBrush', 'CaveatBrush-Regular.ttf'),
  ]) {
    await (FontLoader(
      familia,
    )..addFont(rootBundle.load('assets/vec/fuentes/$archivo'))).load();
  }
}
