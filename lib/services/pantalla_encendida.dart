/// ═══════════════════════════════════════════════════════════════════════════
/// PantallaEncendida — evita que la pantalla se apague o bloquee
///
/// En «¿Quién soy?» el celular está en la frente del jugador y nadie lo toca:
/// sin esto, la pantalla se atenúa y se bloquea a mitad de la carta.
/// Envuelve `wakelock_plus` para poder sustituirlo en pruebas.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class PantallaEncendida {
  PantallaEncendida._();

  static Future<void> Function(bool activar) _alternar = _alternarReal;

  static Future<void> _alternarReal(bool activar) =>
      WakelockPlus.toggle(enable: activar);

  /// Mantener la pantalla encendida (`true`) o devolver el comportamiento
  /// normal del sistema (`false`). Nunca lanza: si la plataforma no lo
  /// soporta, el juego sigue igual.
  static Future<void> mantener(bool activar) async {
    try {
      await _alternar(activar);
    } catch (e) {
      debugPrint('🔆 [PANTALLA] No se pudo cambiar el bloqueo: $e');
    }
  }

  /// Sustituye la implementación en pruebas. `null` restaura la real.
  @visibleForTesting
  static set implementacionParaPruebas(
    Future<void> Function(bool activar)? impl,
  ) {
    _alternar = impl ?? _alternarReal;
  }
}
