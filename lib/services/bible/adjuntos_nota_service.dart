import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/bible/adjunto_nota.dart';
import '../../models/bible/dibujo_nota.dart';

/// Dónde está un archivo de adjunto.
/// [demasiadoGrande]: pasa del límite de la nube; se queda solo en este
/// teléfono (nunca se borra de aquí).
enum EstadoNube { soloTelefono, subiendo, enNube, demasiadoGrande }

/// Fotos y dibujos de Apuntes. Cada archivo se guarda primero en el
/// teléfono (`<documentos>/apuntes/<uid>/<notaId>/`) y luego se sube a
/// Firebase Storage (`users/<uid>/apuntes/<notaId>/`). Lo que no se pudo
/// subir o borrar sin conexión queda en una cola que se reintenta.
class AdjuntosNotaService {
  AdjuntosNotaService._();
  static final AdjuntosNotaService I = AdjuntosNotaService._();

  static const _clavePendientes = 'apuntes_adjuntos_pendientes_v1';

  /// Mismos límites que storage.rules: 5 MB para dibujos y 3 MB para fotos
  /// (una foto de 2048 px al 82 % pesa mucho menos).
  static const int limiteBytes = 5 * 1024 * 1024;
  static const int limiteFoto = 3 * 1024 * 1024;

  static int limiteDe(String archivo) =>
      archivo.endsWith('.jpg') ? limiteFoto : limiteBytes;

  /// Estado de cada archivo, por `<notaId>/<archivo>`.
  final ValueNotifier<Map<String, EstadoNube>> estados = ValueNotifier(
    const {},
  );

  /// Sube cada vez que cambia un archivo (para refrescar las vistas).
  final ValueNotifier<int> cambios = ValueNotifier(0);

  /// Último aviso para el usuario (p. ej. una foto que pasa del límite).
  /// Las pantallas lo muestran en un SnackBar y lo limpian.
  final ValueNotifier<String?> aviso = ValueNotifier(null);

  final Map<String, Uint8List> _memoria = {};
  bool _reintentando = false;

  /// Llegó un pedido de reintento mientras otro estaba en curso: al terminar
  /// se da otra vuelta (antes, lo nuevo esperaba a la siguiente sesión).
  bool _otraVuelta = false;
  StreamSubscription<List<ConnectivityResult>>? _conexion;

  /// Al volver la conexión, sube lo pendiente.
  void _escucharConexion() {
    if (_conexion != null) return;
    try {
      _conexion = Connectivity().onConnectivityChanged.listen(
        (estados) {
          if (estados.any((e) => e != ConnectivityResult.none)) {
            unawaited(reintentarPendientes());
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // Sin el plugin (pruebas): se reintenta al guardar o al abrir Apuntes.
    }
  }

  static String _mb(int bytes) =>
      (bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  bool get _nubeDisponible {
    try {
      return Firebase.apps.isNotEmpty &&
          (Firebase.app().options.storageBucket ?? '').isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _clave(String notaId, String archivo) => '$notaId/$archivo';

  EstadoNube estadoDe(String notaId, String archivo) =>
      estados.value[_clave(notaId, archivo)] ?? EstadoNube.enNube;

  void _marcar(String notaId, String archivo, EstadoNube estado) {
    estados.value = Map.unmodifiable({
      ...estados.value,
      _clave(notaId, archivo): estado,
    });
  }

  Future<Directory> _carpeta(String uid, String notaId) async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/apuntes/$uid/$notaId');
  }

  Future<File> _archivoLocal(String uid, String notaId, String archivo) async =>
      File('${(await _carpeta(uid, notaId)).path}/$archivo');

  Reference _referencia(String uid, String notaId, String archivo) =>
      FirebaseStorage.instance.ref('users/$uid/apuntes/$notaId/$archivo');

  static String tipoDeContenido(String archivo) =>
      archivo.endsWith('.svg') ? 'image/svg+xml' : 'image/jpeg';

  void _recordar(String clave, Uint8List bytes) {
    _memoria.remove(clave);
    _memoria[clave] = bytes;
    while (_memoria.length > 24) {
      _memoria.remove(_memoria.keys.first);
    }
  }

  // ── Alta de adjuntos ────────────────────────────────────────────────────

  /// Agrega una foto (JPEG) al apunte. Devuelve el adjunto ya guardado en el
  /// teléfono; la subida sigue en segundo plano.
  Future<AdjuntoNota?> agregarFoto(String notaId, Uint8List jpeg) async {
    if (jpeg.isEmpty) return null;
    var proporcion = 4 / 3;
    try {
      final codec = await ui.instantiateImageCodec(jpeg);
      final cuadro = await codec.getNextFrame();
      proporcion = cuadro.image.width / cuadro.image.height;
      cuadro.image.dispose();
      codec.dispose();
    } catch (_) {
      // Si no se puede leer el tamaño, se usa 4:3 hasta cargarla.
    }
    final adjunto = AdjuntoNota.nuevo(TipoAdjunto.foto, proporcion: proporcion);
    final ok = await guardarArchivo(notaId, adjunto.archivo, jpeg);
    return ok ? adjunto : null;
  }

  /// Crea o actualiza un dibujo del apunte.
  Future<AdjuntoNota?> guardarDibujo(
    String notaId,
    DatosDibujo dibujo, {
    AdjuntoNota? existente,
  }) async {
    final adjunto =
        existente?.copyWith(proporcion: dibujo.proporcion) ??
        AdjuntoNota.nuevo(TipoAdjunto.dibujo, proporcion: dibujo.proporcion);
    final bytes = Uint8List.fromList(utf8.encode(dibujo.aSvg()));
    final ok = await guardarArchivo(notaId, adjunto.archivo, bytes);
    return ok ? adjunto : null;
  }

  /// Guarda las marcas dibujadas sobre una foto.
  Future<AdjuntoNota?> guardarMarcas(
    String notaId,
    AdjuntoNota foto,
    DatosDibujo marcas,
  ) async {
    if (marcas.vacio) {
      if (foto.conMarcas) await _borrarArchivo(notaId, foto.archivoMarcas);
      return foto.copyWith(conMarcas: false);
    }
    final bytes = Uint8List.fromList(utf8.encode(marcas.aSvg(conPapel: false)));
    final ok = await guardarArchivo(notaId, foto.archivoMarcas, bytes);
    return ok ? foto.copyWith(conMarcas: true) : null;
  }

  // ── Lectura ─────────────────────────────────────────────────────────────

  /// Bytes de un archivo: del teléfono, o de la nube si es otro dispositivo.
  Future<Uint8List?> leerArchivo(String notaId, String archivo) async {
    final uid = _uid;
    if (uid == null) return null;
    final clave = _clave(notaId, archivo);
    final enMemoria = _memoria[clave];
    if (enMemoria != null) return enMemoria;
    try {
      final local = await _archivoLocal(uid, notaId, archivo);
      if (await local.exists()) {
        final bytes = await local.readAsBytes();
        _recordar(clave, bytes);
        return bytes;
      }
      if (!_nubeDisponible) return null;
      // Sin conexión, Storage reintenta durante minutos: no dejar colgada la
      // vista ni la exportación del PDF.
      final bytes = await _referencia(
        uid,
        notaId,
        archivo,
      ).getData(limiteBytes).timeout(const Duration(seconds: 20));
      if (bytes == null) return null;
      await local.parent.create(recursive: true);
      await local.writeAsBytes(bytes, flush: true);
      _recordar(clave, bytes);
      return bytes;
    } catch (e) {
      debugPrint('[ADJUNTOS] No se pudo leer $archivo: $e');
      return null;
    }
  }

  Future<DatosDibujo?> leerDibujo(String notaId, String archivo) async {
    final bytes = await leerArchivo(notaId, archivo);
    if (bytes == null) return null;
    return DatosDibujo.desdeSvg(utf8.decode(bytes, allowMalformed: true));
  }

  // ── Escritura y borrado ─────────────────────────────────────────────────

  /// Escribe el archivo en el teléfono y lo pone en la cola de subida.
  Future<bool> guardarArchivo(
    String notaId,
    String archivo,
    Uint8List bytes,
  ) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final local = await _archivoLocal(uid, notaId, archivo);
      await local.parent.create(recursive: true);
      await local.writeAsBytes(bytes, flush: true);
      _recordar(_clave(notaId, archivo), bytes);
      cambios.value++;
      await _encolar('s', uid, notaId, archivo);
      if (bytes.length >= limiteDe(archivo)) {
        // Se guarda igual en el teléfono (no se pierde), pero se avisa.
        _marcar(notaId, archivo, EstadoNube.demasiadoGrande);
        aviso.value =
            '${archivo.endsWith('.jpg') ? 'La foto' : 'El dibujo'} pesa '
            '${_mb(bytes.length)} MB y el límite de la nube es '
            '${_mb(limiteDe(archivo))} MB. Se queda guardado solo en este '
            'teléfono.';
        return true;
      }
      _marcar(notaId, archivo, EstadoNube.soloTelefono);
      unawaited(reintentarPendientes());
      return true;
    } catch (e) {
      debugPrint('[ADJUNTOS] No se pudo guardar $archivo: $e');
      return false;
    }
  }

  /// Quita un adjunto: sus archivos del teléfono y de la nube.
  Future<void> borrarAdjunto(String notaId, AdjuntoNota adjunto) async {
    for (final archivo in [adjunto.archivo, adjunto.archivoMarcas]) {
      await _borrarArchivo(notaId, archivo);
    }
  }

  /// Quita todos los archivos de un apunte borrado.
  Future<void> borrarNota(String notaId, List<AdjuntoNota> adjuntos) async {
    for (final a in adjuntos) {
      await borrarAdjunto(notaId, a);
    }
    final uid = _uid;
    if (uid == null) return;
    try {
      final carpeta = await _carpeta(uid, notaId);
      if (await carpeta.exists()) await carpeta.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> _borrarArchivo(String notaId, String archivo) async {
    final uid = _uid;
    if (uid == null) return;
    _memoria.remove(_clave(notaId, archivo));
    try {
      final local = await _archivoLocal(uid, notaId, archivo);
      if (await local.exists()) await local.delete();
    } catch (_) {}
    await _quitarDeCola('s', uid, notaId, archivo);
    await _encolar('b', uid, notaId, archivo);
    unawaited(reintentarPendientes());
  }

  /// Al cerrar sesión: quita del teléfono los archivos de la cuenta, salvo
  /// los que aún no se subieron (se suben al volver a entrar).
  Future<void> borrarCacheLocal() async {
    // Se vuelve a escuchar la conexión al entrar con otra cuenta.
    await _conexion?.cancel();
    _conexion = null;
    _memoria.clear();
    estados.value = const {};
    try {
      final base = await getApplicationDocumentsDirectory();
      final carpeta = Directory('${base.path}/apuntes');
      if (!await carpeta.exists()) return;
      final pendientes = archivosSinSubir(await _leerCola());
      await for (final f in carpeta.list(recursive: true)) {
        if (f is! File) continue;
        final relativo = rutaRelativa(carpeta.path, f.path);
        if (!pendientes.contains(relativo)) await f.delete();
      }
    } catch (_) {}
  }

  /// Archivos (`uid/notaId/archivo`) que todavía no están confirmados en la
  /// nube según la cola: esos nunca se borran del teléfono.
  @visibleForTesting
  static Set<String> archivosSinSubir(List<String> cola) => {
    for (final e in cola)
      if (e.startsWith('s|')) e.substring(2).replaceAll('|', '/'),
  };

  /// Ruta de [archivo] relativa a [carpeta], siempre con `/` (en Windows
  /// `File.path` usa `\` y antes no coincidía con la cola: se borraban
  /// fotos sin subir).
  @visibleForTesting
  static String rutaRelativa(String carpeta, String archivo) {
    final c = carpeta.replaceAll('\\', '/');
    final a = archivo.replaceAll('\\', '/');
    final relativo = a.startsWith(c) ? a.substring(c.length) : a;
    return relativo.replaceFirst(RegExp(r'^/+'), '');
  }

  // ── Cola de pendientes ──────────────────────────────────────────────────

  Future<List<String>> _leerCola() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_clavePendientes) ?? <String>[];
  }

  Future<void> _escribirCola(List<String> cola) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_clavePendientes, cola);
  }

  Future<void> _encolar(
    String op,
    String uid,
    String notaId,
    String archivo,
  ) async {
    final entrada = '$op|$uid|$notaId|$archivo';
    final cola = await _leerCola();
    if (!cola.contains(entrada)) await _escribirCola([...cola, entrada]);
  }

  Future<void> _quitarDeCola(
    String op,
    String uid,
    String notaId,
    String archivo,
  ) async {
    final entrada = '$op|$uid|$notaId|$archivo';
    final cola = await _leerCola();
    if (cola.contains(entrada)) {
      await _escribirCola([...cola]..remove(entrada));
    }
  }

  /// Sube o borra en la nube lo pendiente de la cuenta actual.
  Future<void> reintentarPendientes() async {
    final uid = _uid;
    if (uid == null || !_nubeDisponible) return;
    _escucharConexion();
    if (_reintentando) {
      _otraVuelta = true;
      return;
    }
    _reintentando = true;
    try {
      do {
        _otraVuelta = false;
        for (final entrada in await _leerCola()) {
          final partes = entrada.split('|');
          if (partes.length != 4 || partes[1] != uid) continue;
          final op = partes[0], notaId = partes[2], archivo = partes[3];
          final hecho = op == 's'
              ? await _subir(uid, notaId, archivo)
              : await _borrarEnNube(uid, notaId, archivo);
          if (hecho) await _quitarDeCola(op, uid, notaId, archivo);
        }
      } while (_otraVuelta && _uid == uid);
    } finally {
      _reintentando = false;
    }
  }

  Future<bool> _subir(String uid, String notaId, String archivo) async {
    try {
      final local = await _archivoLocal(uid, notaId, archivo);
      // Ya no existe en el teléfono (se quitó el adjunto): nada que subir.
      if (!await local.exists()) return true;
      if (await local.length() >= limiteDe(archivo)) {
        // NO se da por subido: seguir en la cola es lo que impide que se
        // borre del teléfono al cerrar sesión.
        debugPrint('[ADJUNTOS] $archivo pasa del límite; se queda en el teléfono');
        _marcar(notaId, archivo, EstadoNube.demasiadoGrande);
        return false;
      }
      _marcar(notaId, archivo, EstadoNube.subiendo);
      await _referencia(uid, notaId, archivo).putFile(
        local,
        SettableMetadata(contentType: tipoDeContenido(archivo)),
      );
      _marcar(notaId, archivo, EstadoNube.enNube);
      return true;
    } catch (e) {
      debugPrint('[ADJUNTOS] Subida pendiente de $archivo: $e');
      _marcar(notaId, archivo, EstadoNube.soloTelefono);
      return false;
    }
  }

  Future<bool> _borrarEnNube(String uid, String notaId, String archivo) async {
    try {
      await _referencia(uid, notaId, archivo).delete();
      return true;
    } on FirebaseException catch (e) {
      // Ya no existe: no hay nada que borrar.
      return e.code == 'object-not-found';
    } catch (_) {
      return false;
    }
  }
}
