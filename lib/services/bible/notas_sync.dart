import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// NOTAS SYNC — Guardado local primero para notas, apuntes y estudios.
///
/// Firestore (con persistencia activada) aplica cada `set()`/`delete()` en el
/// teléfono al instante, pero el `Future` que devuelve solo termina cuando el
/// SERVIDOR confirma. Sin conexión ese Future no termina nunca, así que
/// esperarlo dejaba la pantalla en «Guardando…» para siempre.
///
/// Aquí cada escritura se lanza sin esperar al servidor:
///   - el texto ya quedó en la cache local de la app y en la de Firestore;
///   - la ruta queda marcada como pendiente (también en SharedPreferences,
///     para reenviarla si la app se cierra antes de subirla);
///   - al confirmar el servidor, la marca se quita;
///   - si falla (reglas, cuota), la marca se queda y [estado] avisa.
///
/// Las listas usan [fusionarConServidor] para que un cambio local pendiente
/// no desaparezca de la vista mientras el servidor no lo tiene.
/// ═══════════════════════════════════════════════════════════════════════════

/// Escritura remota de un documento. Se abstrae para probar sin Firebase.
abstract class EscritorRemotoNotas {
  Future<void> guardar(
    String ruta,
    Map<String, dynamic> datos, {
    bool fusionar = true,
  });

  Future<void> borrar(String ruta);
}

/// Escritor real: Firestore.
class EscritorFirestoreNotas implements EscritorRemotoNotas {
  const EscritorFirestoreNotas();

  @override
  Future<void> guardar(
    String ruta,
    Map<String, dynamic> datos, {
    bool fusionar = true,
  }) => FirebaseFirestore.instance
      .doc(ruta)
      .set(datos, SetOptions(merge: fusionar));

  @override
  Future<void> borrar(String ruta) =>
      FirebaseFirestore.instance.doc(ruta).delete();
}

/// Cómo van las notas respecto a la nube.
enum EstadoNotasNube {
  /// Todo lo escrito ya está en la nube.
  alDia,

  /// Hay cambios subiendo (todavía no es lento).
  subiendo,

  /// Un cambio lleva un rato sin confirmarse: casi seguro, sin conexión.
  /// Ya está guardado en el teléfono y se subirá al volver la conexión.
  esperandoConexion,

  /// El servidor rechazó un cambio. Sigue guardado en el teléfono.
  error,
}

/// Texto corto para mostrar el estado en un chip.
String etiquetaEstadoNotas(EstadoNotasNube estado) => switch (estado) {
  EstadoNotasNube.alDia => 'Guardado',
  EstadoNotasNube.subiendo => 'Guardado',
  EstadoNotasNube.esperandoConexion =>
    'Guardado en el teléfono · se subirá al volver la conexión',
  EstadoNotasNube.error =>
    'Guardado en el teléfono · no se pudo subir, se reintentará',
};

class _Pendiente {
  final bool borrado;
  final int secuencia;

  const _Pendiente({required this.borrado, required this.secuencia});
}

class NotasSync {
  NotasSync._();
  static final NotasSync I = NotasSync._();

  static const _clavePrefs = 'notas_sync_pendientes_v1';

  /// Tiempo sin confirmación a partir del cual se asume que no hay conexión.
  static Duration demoraSinConexion = const Duration(milliseconds: 1500);

  /// Escritor remoto. Las pruebas lo reemplazan por uno falso.
  EscritorRemotoNotas escritor = const EscritorFirestoreNotas();

  final ValueNotifier<EstadoNotasNube> estado = ValueNotifier(
    EstadoNotasNube.alDia,
  );

  final Map<String, _Pendiente> _pendientes = {};
  final Set<String> _conError = {};
  int _secuencia = 0;
  int _enVuelo = 0;
  Timer? _temporizadorLento;
  SharedPreferences? _prefs;
  bool _cargado = false;

  /// Lee las rutas pendientes de una sesión anterior.
  Future<void> cargar() async {
    if (_cargado) return;
    _prefs ??= await SharedPreferences.getInstance();
    _cargado = true;
    for (final entrada in _prefs!.getStringList(_clavePrefs) ?? const []) {
      final i = entrada.indexOf('|');
      if (i <= 0) continue;
      final ruta = entrada.substring(i + 1);
      if (_pendientes.containsKey(ruta)) continue;
      _pendientes[ruta] = _Pendiente(
        borrado: entrada.substring(0, i) == 'b',
        secuencia: 0,
      );
    }
  }

  /// La ruta tiene un guardado local que el servidor aún no confirmó.
  bool guardadoPendiente(String ruta) =>
      _pendientes[ruta]?.borrado == false;

  /// La ruta tiene un borrado local que el servidor aún no confirmó.
  bool borradoPendiente(String ruta) => _pendientes[ruta]?.borrado == true;

  /// Rutas pendientes bajo [prefijo] (p. ej. `users/uid/chapterNotes/`).
  /// Devuelve el id del documento (lo que sigue al prefijo).
  List<String> idsPendientes(String prefijo, {required bool borrados}) => [
    for (final e in _pendientes.entries)
      if (e.key.startsWith(prefijo) && e.value.borrado == borrados)
        e.key.substring(prefijo.length),
  ];

  /// Guarda sin esperar al servidor. El Future devuelto termina cuando el
  /// servidor confirma (true) o rechaza (false); NO hace falta esperarlo.
  Future<bool> guardar(
    String ruta,
    Map<String, dynamic> datos, {
    bool fusionar = true,
  }) => _lanzar(
    ruta,
    borrado: false,
    escritura: () => escritor.guardar(ruta, datos, fusionar: fusionar),
  );

  /// Borra sin esperar al servidor (mismo contrato que [guardar]).
  Future<bool> borrar(String ruta) =>
      _lanzar(ruta, borrado: true, escritura: () => escritor.borrar(ruta));

  Future<bool> _lanzar(
    String ruta, {
    required bool borrado,
    required Future<void> Function() escritura,
  }) {
    final secuencia = ++_secuencia;
    _pendientes[ruta] = _Pendiente(borrado: borrado, secuencia: secuencia);
    unawaited(_persistir());
    _enVuelo++;
    _actualizarEstado();

    final confirmacion = Completer<bool>();
    Future<void> remoto;
    try {
      // Se llama en este mismo instante: Firestore aplica el cambio en su
      // cache local antes de devolver el Future del servidor.
      remoto = escritura();
    } catch (e) {
      remoto = Future<void>.error(e);
    }
    remoto.then(
      (_) {
        if (_pendientes[ruta]?.secuencia == secuencia) {
          _pendientes.remove(ruta);
          unawaited(_persistir());
        }
        _conError.remove(ruta);
        _terminar();
        confirmacion.complete(true);
      },
      onError: (Object e) {
        debugPrint('[NOTAS-SYNC] No se pudo subir $ruta: $e');
        _conError.add(ruta);
        _terminar();
        confirmacion.complete(false);
      },
    );
    return confirmacion.future;
  }

  void _terminar() {
    _enVuelo = (_enVuelo - 1).clamp(0, 1 << 30);
    _actualizarEstado();
  }

  void _actualizarEstado() {
    if (_conError.isNotEmpty) {
      _temporizadorLento?.cancel();
      _temporizadorLento = null;
      estado.value = EstadoNotasNube.error;
      return;
    }
    if (_enVuelo == 0) {
      _temporizadorLento?.cancel();
      _temporizadorLento = null;
      estado.value = EstadoNotasNube.alDia;
      return;
    }
    if (estado.value == EstadoNotasNube.esperandoConexion) return;
    estado.value = EstadoNotasNube.subiendo;
    _temporizadorLento ??= Timer(demoraSinConexion, () {
      _temporizadorLento = null;
      if (_enVuelo > 0 && _conError.isEmpty) {
        estado.value = EstadoNotasNube.esperandoConexion;
      }
    });
  }

  Future<void> _persistir() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setStringList(_clavePrefs, [
        for (final e in _pendientes.entries)
          '${e.value.borrado ? 'b' : 's'}|${e.key}',
      ]);
    } catch (e) {
      debugPrint('[NOTAS-SYNC] No se pudo guardar la cola: $e');
    }
  }

  /// Solo para pruebas: vuelve al estado inicial.
  @visibleForTesting
  void reiniciarParaPruebas({EscritorRemotoNotas? escritor}) {
    _pendientes.clear();
    _conError.clear();
    _enVuelo = 0;
    _secuencia = 0;
    _temporizadorLento?.cancel();
    _temporizadorLento = null;
    _prefs = null;
    _cargado = false;
    estado.value = EstadoNotasNube.alDia;
    this.escritor = escritor ?? const EscritorFirestoreNotas();
  }
}

/// Une lo que hay en el teléfono con un snapshot COMPLETO del servidor
/// (consulta sin `limit`), sin perder nada:
///   - lo que llega del servidor reemplaza la copia local, salvo que haya un
///     guardado local pendiente (la copia local es más nueva);
///   - lo que está en el teléfono y no llegó se conserva si tiene un guardado
///     pendiente o si el snapshot viene de la cache (puede estar incompleta);
///     si el servidor confirma que ya no existe, se quita (borrado en otro
///     dispositivo);
///   - lo borrado en el teléfono no reaparece mientras el borrado no se suba.
Map<String, T> fusionarConServidor<T>({
  required Map<String, T> local,
  required Map<String, T> remoto,
  required bool desdeCache,
  required bool Function(String clave) guardadoPendiente,
  required bool Function(String clave) borradoPendiente,
}) {
  final resultado = <String, T>{};
  remoto.forEach((clave, valor) {
    if (borradoPendiente(clave)) return;
    final copiaLocal = local[clave];
    resultado[clave] = copiaLocal != null && guardadoPendiente(clave)
        ? copiaLocal
        : valor;
  });
  local.forEach((clave, valor) {
    if (resultado.containsKey(clave) || remoto.containsKey(clave)) return;
    if (borradoPendiente(clave)) return;
    if (desdeCache || guardadoPendiente(clave)) resultado[clave] = valor;
  });
  return resultado;
}
