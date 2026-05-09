/// ═══════════════════════════════════════════════════════════════════════════
/// CLIPBOARD HELPERS
///
/// `copyToClipboardWithAutoClear` — copia [text] al portapapeles y lo borra
/// pasados [clearAfter] segundos. Defensa en profundidad: apps maliciosas
/// que monitorean el portapapeles tendrán una ventana corta de oportunidad.
///
/// Uso:
///   await copyToClipboardWithAutoClear(inviteCode);
///
/// Notas:
///  - Sólo borra el contenido si el portapapeles aún contiene [text]
///    (no pisamos lo que el usuario haya copiado después).
///  - El timer no bloquea la UI ni se cancela al salir de la pantalla; la
///    autopurga sucede igual aunque la app pase a background.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const Duration _kDefaultClipboardTtl = Duration(seconds: 60);

Future<void> copyToClipboardWithAutoClear(
  String text, {
  Duration clearAfter = _kDefaultClipboardTtl,
}) async {
  if (text.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  Timer(clearAfter, () async {
    try {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[clipboard] auto-clear error: $e');
      }
    }
  });
}
