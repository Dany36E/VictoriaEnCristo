/// ═══════════════════════════════════════════════════════════════════════════
/// DayChangeService — detecta el cambio de día local
///
/// Si la app queda en segundo plano y se reabre al día siguiente (o sigue
/// abierta al pasar la medianoche), todo lo que depende de la fecha debe
/// refrescarse: versículo del día, «Prácticas de hoy», devocional
/// completado, check-in matutino, racha…
///
/// Fuentes de detección:
///   - [comprobar] al volver la app al frente (lo llama `main.dart`).
///   - Un temporizador que despierta justo después de la medianoche mientras
///     la app está en primer plano ([iniciarTemporizador]).
///
/// Quien dependa de la fecha escucha [hoy] (ISO `YYYY-MM-DD`). El reloj es
/// inyectable vía [TimeUtils.relojParaPruebas] o el constructor.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/time_utils.dart';

class DayChangeService {
  DayChangeService({DateTime Function()? reloj}) : _reloj = reloj {
    hoy = ValueNotifier<String>(TimeUtils.dateToISO(_ahora()));
  }

  static final DayChangeService I = DayChangeService();

  final DateTime Function()? _reloj;
  Timer? _temporizador;

  /// Fecha local actual (ISO). Notifica a los oyentes al cambiar de día.
  late final ValueNotifier<String> hoy;

  DateTime _ahora() => (_reloj ?? TimeUtils.now)();

  /// `true` si hay un temporizador de medianoche activo.
  bool get temporizadorActivo => _temporizador?.isActive ?? false;

  /// Compara la fecha actual con la última conocida. Si cambió, actualiza
  /// [hoy] (lo que avisa a los oyentes) y devuelve `true`.
  bool comprobar() {
    final iso = TimeUtils.dateToISO(_ahora());
    if (iso == hoy.value) return false;
    debugPrint('🌅 [DAY_CHANGE] ${hoy.value} → $iso');
    hoy.value = iso;
    return true;
  }

  /// Tiempo hasta un instante después de la próxima medianoche local.
  @visibleForTesting
  Duration tiempoHastaMedianoche() {
    final ahora = _ahora();
    final manana = DateTime(ahora.year, ahora.month, ahora.day + 1);
    final espera = manana.difference(ahora);
    // Margen para no despertar unos milisegundos antes de las 00:00 (y por
    // si el reloj del sistema va algo desfasado respecto al temporizador).
    return (espera.isNegative ? Duration.zero : espera) +
        const Duration(seconds: 2);
  }

  /// Programa la comprobación de medianoche (mientras la app está al frente).
  /// Se reprograma sola cada día.
  void iniciarTemporizador() {
    _temporizador?.cancel();
    _temporizador = Timer(tiempoHastaMedianoche(), () {
      comprobar();
      iniciarTemporizador();
    });
  }

  /// Cancela el temporizador (al pasar a segundo plano).
  void detenerTemporizador() {
    _temporizador?.cancel();
    _temporizador = null;
  }
}
