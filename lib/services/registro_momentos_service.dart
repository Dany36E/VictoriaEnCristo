/// ═══════════════════════════════════════════════════════════════════════════
/// REGISTRO DE MOMENTOS — tentaciones fuertes y caídas con sus detonantes.
///
/// Sirve para ver patrones (horas y días de más riesgo, detonantes y
/// emociones) en la pantalla "Mis patrones". Es privado: se guarda en el
/// teléfono y en `users/{uid}/triggerLogs` (solo el dueño lo lee). Nunca se
/// comparte con compañeros ni aparece en el resumen semanal.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Qué pasó.
enum TipoMomento {
  tentacion('tentacion', 'Tentación fuerte'),
  caida('caida', 'Caída');

  const TipoMomento(this.id, this.etiqueta);
  final String id;
  final String etiqueta;

  static TipoMomento desdeId(String? id) =>
      TipoMomento.values.firstWhere((t) => t.id == id, orElse: () => tentacion);
}

/// Catálogo de opciones (las emociones coinciden con los detonantes del
/// diario para poder sumarlos).
class CatalogoMomentos {
  CatalogoMomentos._();

  static const emociones = [
    'Soledad',
    'Estrés',
    'Ansiedad',
    'Tristeza',
    'Enojo',
    'Aburrimiento',
    'Cansancio',
    'Rechazo',
    'Vergüenza',
  ];

  static const situaciones = [
    'Noche',
    'Insomnio',
    'Redes sociales',
    'Solo en casa',
    'Después de un conflicto',
    'Imágenes o anuncios',
    'Tiempo libre sin plan',
  ];

  static const lugares = [
    'Mi cuarto',
    'Baño',
    'Otra parte de la casa',
    'Trabajo o escuela',
    'Fuera de casa',
  ];

  static const dispositivos = [
    'Celular',
    'Computadora',
    'Tableta',
    'Televisión',
    'Ninguno',
  ];
}

/// Un momento registrado.
@immutable
class RegistroMomento {
  final String id;
  final DateTime fecha;
  final TipoMomento tipo;

  /// Solo para tentaciones: ¿la venciste?
  final bool? resistio;
  final List<String> emociones;
  final List<String> situaciones;
  final String? lugar;
  final String? dispositivo;

  const RegistroMomento({
    required this.id,
    required this.fecha,
    required this.tipo,
    this.resistio,
    this.emociones = const [],
    this.situaciones = const [],
    this.lugar,
    this.dispositivo,
  });

  /// Todas las etiquetas que cuentan como detonante.
  List<String> get detonantes => [
    ...emociones,
    ...situaciones,
    ?lugar,
    if (dispositivo != null && dispositivo != 'Ninguno') dispositivo!,
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'fecha': fecha.toIso8601String(),
    'tipo': tipo.id,
    if (resistio != null) 'resistio': resistio,
    'emociones': emociones,
    'situaciones': situaciones,
    if (lugar != null) 'lugar': lugar,
    if (dispositivo != null) 'dispositivo': dispositivo,
  };

  static RegistroMomento? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final fecha = DateTime.tryParse(j['fecha'] as String? ?? '');
    if (id is! String || fecha == null) return null;
    List<String> lista(String k) =>
        (j[k] as List?)?.whereType<String>().toList() ?? const [];
    return RegistroMomento(
      id: id,
      fecha: fecha,
      tipo: TipoMomento.desdeId(j['tipo'] as String?),
      resistio: j['resistio'] as bool?,
      emociones: lista('emociones'),
      situaciones: lista('situaciones'),
      lugar: j['lugar'] as String?,
      dispositivo: j['dispositivo'] as String?,
    );
  }
}

class RegistroMomentosService {
  RegistroMomentosService._();
  static final RegistroMomentosService I = RegistroMomentosService._();

  /// Clave por usuario: en un teléfono compartido nadie ve lo de otra cuenta.
  String get _clave {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}
    return 'registro_momentos_v1_${uid ?? 'local'}';
  }

  String? _claveCargada;
  static const _maximo = 500;

  final ValueNotifier<List<RegistroMomento>> registros = ValueNotifier(
    const [],
  );
  bool _cargado = false;

  Future<void> cargar() async {
    if (_cargado && _claveCargada == _clave) return;
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_clave);
    final lista = <RegistroMomento>[];
    if (texto != null) {
      try {
        for (final e in jsonDecode(texto) as List) {
          if (e is Map) {
            final r = RegistroMomento.fromJson(Map<String, dynamic>.from(e));
            if (r != null) lista.add(r);
          }
        }
      } catch (e) {
        debugPrint('📊 [MOMENTOS] Datos locales ilegibles: $e');
      }
    }
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    registros.value = lista;
    _cargado = true;
    _claveCargada = _clave;
    if (lista.isEmpty) unawaited(_restaurarDeLaNube());
  }

  String nuevoId() {
    final r = Random.secure().nextInt(1 << 32).toRadixString(36);
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$r';
  }

  Future<void> agregar(RegistroMomento r) async {
    await cargar();
    final lista = [r, ...registros.value]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    registros.value = lista.take(_maximo).toList();
    await _guardar();
    unawaited(_subir(r));
  }

  Future<void> borrar(String id) async {
    registros.value = registros.value.where((r) => r.id != id).toList();
    await _guardar();
    final ref = _coleccion();
    if (ref != null) {
      unawaited(ref.doc(id).delete().catchError((Object _) {}));
    }
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode(registros.value.map((r) => r.toJson()).toList()),
    );
  }

  CollectionReference<Map<String, dynamic>>? _coleccion() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('triggerLogs');
    } catch (_) {
      return null;
    }
  }

  Future<void> _subir(RegistroMomento r) async {
    final ref = _coleccion();
    if (ref == null) return;
    try {
      await ref.doc(r.id).set(r.toJson());
    } catch (e) {
      debugPrint('📊 [MOMENTOS] No se pudo respaldar: $e');
    }
  }

  Future<void> _restaurarDeLaNube() async {
    final ref = _coleccion();
    if (ref == null) return;
    try {
      final snap = await ref.orderBy('fecha', descending: true).limit(_maximo).get();
      final lista =
          snap.docs
              .map((d) => RegistroMomento.fromJson(d.data()))
              .whereType<RegistroMomento>()
              .toList()
            ..sort((a, b) => b.fecha.compareTo(a.fecha));
      if (lista.isEmpty || registros.value.isNotEmpty) return;
      registros.value = lista;
      await _guardar();
    } catch (e) {
      debugPrint('📊 [MOMENTOS] No se pudo restaurar: $e');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    registros.value = const [];
    _cargado = false;
  }
}
