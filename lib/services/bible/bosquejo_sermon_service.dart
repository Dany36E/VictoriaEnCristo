import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/bible/bosquejo_sermon.dart';
import 'notas_sync.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BOSQUEJO SERMON SERVICE — Singleton
///
/// Bosquejos de sermón del usuario. Se guardan primero en el teléfono
/// (SharedPreferences) y se suben a Firestore sin esperar al servidor
/// (ver [NotasSync]), así que funcionan igual sin conexión.
///
/// Colección: /users/{uid}/sermonOutlines/{id}
/// ═══════════════════════════════════════════════════════════════════════════
class BosquejoSermonService {
  BosquejoSermonService._();
  static final BosquejoSermonService I = BosquejoSermonService._();

  static const _coleccion = 'sermonOutlines';
  static const _cachePrefix = 'sermon_outlines_cache_v1';

  SharedPreferences? _prefs;
  StreamSubscription? _subscription;
  String? _uid;

  final ValueNotifier<Map<String, BosquejoSermon>> bosquejosNotifier =
      ValueNotifier(const {});

  /// Firestore se pide solo al escuchar: las pruebas no lo necesitan.
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid!)
      .collection(_coleccion);

  String _prefijo(String uid) => 'users/$uid/$_coleccion/';

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    await _preparar(uid);
    _listen();
  }

  /// Igual que [init] pero sin escuchar Firestore (para pruebas).
  @visibleForTesting
  Future<void> initSinNube(String uid) => _preparar(uid);

  Future<void> _preparar(String uid) async {
    stop();
    _uid = uid;
    _prefs ??= await SharedPreferences.getInstance();
    await NotasSync.I.cargar();
    await _loadLocalCache(uid);
    _reenviarPendientes(uid);
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    bosquejosNotifier.value = const {};
    _uid = null;
  }

  BosquejoSermon? porId(String? id) {
    if (id == null || id.isEmpty) return null;
    return bosquejosNotifier.value[id];
  }

  List<BosquejoSermon> get todos {
    final list = bosquejosNotifier.value.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Guarda en el teléfono y lanza la subida sin esperar al servidor.
  Future<void> guardar(BosquejoSermon bosquejo) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final next = Map<String, BosquejoSermon>.from(bosquejosNotifier.value);
    next[bosquejo.id] = bosquejo;
    bosquejosNotifier.value = Map.unmodifiable(next);
    await _saveLocalCache(next);
    unawaited(
      NotasSync.I.guardar('${_prefijo(uid)}${bosquejo.id}', bosquejo.toMap()),
    );
  }

  Future<void> borrar(String id) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final next = Map<String, BosquejoSermon>.from(bosquejosNotifier.value)
      ..remove(id);
    bosquejosNotifier.value = Map.unmodifiable(next);
    await _saveLocalCache(next);
    unawaited(NotasSync.I.borrar('${_prefijo(uid)}$id'));
  }

  /// Vuelve a lanzar lo que quedó sin confirmar en una sesión anterior.
  void _reenviarPendientes(String uid) {
    final prefijo = _prefijo(uid);
    for (final id in NotasSync.I.idsPendientes(prefijo, borrados: false)) {
      final bosquejo = bosquejosNotifier.value[id];
      if (bosquejo != null) {
        unawaited(NotasSync.I.guardar('$prefijo$id', bosquejo.toMap()));
      }
    }
    for (final id in NotasSync.I.idsPendientes(prefijo, borrados: true)) {
      unawaited(NotasSync.I.borrar('$prefijo$id'));
    }
  }

  void _listen() {
    final uid = _uid;
    if (uid == null) return;
    try {
      _subscription = _col
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snap) {
              if (_uid != uid) return;
              final remoto = <String, BosquejoSermon>{};
              for (final doc in snap.docs) {
                try {
                  remoto[doc.id] = BosquejoSermon.fromMap(doc.id, doc.data());
                } catch (e) {
                  debugPrint('[BOSQUEJOS] parse error: $e');
                }
              }
              aplicarSnapshot(remoto, desdeCache: snap.metadata.isFromCache);
            },
            onError: (e) => debugPrint('[BOSQUEJOS] listen error: $e'),
          );
    } catch (e) {
      debugPrint('[BOSQUEJOS] No se pudo escuchar la nube: $e');
    }
  }

  /// Une un snapshot COMPLETO de la nube con lo que hay en el teléfono.
  @visibleForTesting
  void aplicarSnapshot(
    Map<String, BosquejoSermon> remoto, {
    required bool desdeCache,
  }) {
    final uid = _uid;
    if (uid == null) return;
    final prefijo = _prefijo(uid);
    final unidos = fusionarConServidor<BosquejoSermon>(
      local: bosquejosNotifier.value,
      remoto: remoto,
      desdeCache: desdeCache,
      guardadoPendiente: (id) => NotasSync.I.guardadoPendiente('$prefijo$id'),
      borradoPendiente: (id) => NotasSync.I.borradoPendiente('$prefijo$id'),
    );
    bosquejosNotifier.value = Map.unmodifiable(unidos);
    unawaited(_saveLocalCache(unidos));
  }

  String _cacheKey(String uid) => '$_cachePrefix.$uid';

  Future<void> _loadLocalCache(String uid) async {
    try {
      final raw = _prefs?.getString(_cacheKey(uid));
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final lista = <BosquejoSermon>[];
      for (final item in decoded.whereType<Map>()) {
        final data = Map<String, dynamic>.from(item);
        final id = data['id'] as String? ?? '';
        if (id.isEmpty) continue;
        lista.add(BosquejoSermon.fromMap(id, data));
      }
      bosquejosNotifier.value = Map.unmodifiable({
        for (final b in lista) b.id: b,
      });
    } catch (e) {
      debugPrint('[BOSQUEJOS] local cache load error: $e');
    }
  }

  Future<void> _saveLocalCache(Map<String, BosquejoSermon> data) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _prefs?.setString(
        _cacheKey(uid),
        jsonEncode([for (final b in data.values) b.toLocalMap()]),
      );
    } catch (e) {
      debugPrint('[BOSQUEJOS] local cache save error: $e');
    }
  }
}
