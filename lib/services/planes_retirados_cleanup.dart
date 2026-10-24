/// ═══════════════════════════════════════════════════════════════════════════
/// Limpieza única tras retirar los planes de lectura
///
/// Los 32 planes de lectura se quitaron de la app. Quien actualiza desde una
/// versión anterior puede tener:
///   - recordatorios diarios de plan programados (llevarían a una sección que
///     ya no existe), y
///   - progreso/caché de planes en SharedPreferences.
///
/// Esta limpieza corre una sola vez por dispositivo. Si cancelar los
/// recordatorios falla (p. ej. el plugin no está listo), no se marca como
/// hecha y se reintenta en el próximo arranque. Nunca toca la nube: el
/// progreso en Firestore se borra solo si el usuario elimina su cuenta.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlanesRetiradosCleanup {
  PlanesRetiradosCleanup._();

  /// Marca de que la limpieza ya se hizo en este dispositivo.
  static const String claveHecha = 'planes_retirados_limpieza_v1';

  /// Claves locales que usaban los planes (servicio, repositorio y caché).
  static const List<String> clavesDePlanes = <String>[
    'plan_active_id',
    'plan_all_progress',
    'active_plan_id',
    'plans_cache_v1',
    'plans_pending_writes',
  ];

  /// Ejecuta la limpieza si no se hizo antes.
  ///
  /// [cancelarRecordatorios] debe cancelar los recordatorios de plan
  /// pendientes y devolver `true` si lo logró
  /// (`NotificationService().cancelarRecordatoriosDePlanes`).
  ///
  /// Devuelve `true` si en esta llamada se ejecutó la limpieza completa.
  static Future<bool> ejecutarUnaVez({
    required Future<bool> Function() cancelarRecordatorios,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(claveHecha) ?? false) return false;

      await borrarPreferencias(prefs);
      final cancelados = await cancelarRecordatorios();
      if (!cancelados) {
        debugPrint('🧹 [PLANES] Recordatorios no cancelados; se reintenta luego');
        return false;
      }
      await prefs.setBool(claveHecha, true);
      debugPrint('🧹 [PLANES] Limpieza de planes retirados completada');
      return true;
    } catch (e) {
      debugPrint('🧹 [PLANES] Error en limpieza de planes retirados: $e');
      return false;
    }
  }

  /// Borra el progreso y la caché local de planes. Idempotente.
  static Future<void> borrarPreferencias(SharedPreferences prefs) async {
    for (final clave in clavesDePlanes) {
      if (prefs.containsKey(clave)) await prefs.remove(clave);
    }
  }
}
