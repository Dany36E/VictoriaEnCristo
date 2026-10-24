import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/bible/sermon_note.dart';
import 'adjuntos_nota_service.dart';
import 'notas_sync.dart';

class SermonNoteService {
  SermonNoteService._();
  static final SermonNoteService I = SermonNoteService._();

  SharedPreferences? _prefs;
  StreamSubscription? _subscription;
  String? _uid;

  static const _coleccion = 'sermonNotes';
  static const _cachePrefix = 'sermon_notes_cache_v1';

  final ValueNotifier<Map<String, SermonNote>> notesNotifier = ValueNotifier(
    const {},
  );

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

  /// Vuelve a lanzar lo que quedó sin confirmar en una sesión anterior.
  void _reenviarPendientes(String uid) {
    final prefijo = _prefijo(uid);
    for (final id in NotasSync.I.idsPendientes(prefijo, borrados: false)) {
      final nota = notesNotifier.value[id];
      if (nota != null) {
        unawaited(NotasSync.I.guardar('$prefijo$id', nota.toMap()));
      }
    }
    for (final id in NotasSync.I.idsPendientes(prefijo, borrados: true)) {
      unawaited(NotasSync.I.borrar('$prefijo$id'));
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    notesNotifier.value = const {};
    _uid = null;
  }

  SermonNote? noteById(String? id) {
    if (id == null || id.isEmpty) return null;
    return notesNotifier.value[id];
  }

  List<SermonNote> get allNotes {
    final list = notesNotifier.value.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<String> get speakers {
    final values =
        notesNotifier.value.values
            .map((note) => note.speaker.trim())
            .where((speaker) => speaker.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  /// Guarda el apunte en el teléfono y lanza la subida SIN esperar al
  /// servidor: sin conexión termina igual (antes se quedaba «Guardando…» y
  /// el PDF no salía). El Future de la nube está en [NotasSync].
  Future<void> saveNote(SermonNote note) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final updated = note.copyWith();
    final next = Map<String, SermonNote>.from(notesNotifier.value);
    next[updated.id] = updated;
    notesNotifier.value = Map.unmodifiable(next);
    await _saveLocalCache(next);
    unawaited(
      NotasSync.I.guardar('${_prefijo(uid)}${updated.id}', updated.toMap()),
    );
  }

  /// Fija o suelta un apunte sin cambiar su fecha de edición.
  Future<void> fijar(String id, bool fijada) async {
    final uid = _uid;
    final nota = notesNotifier.value[id];
    if (uid == null || uid.isEmpty || nota == null) return;
    if (nota.fijada == fijada) return;
    final actualizada = SermonNote.fromMap(id, {
      ...nota.toMap(),
      'fijada': fijada,
    });
    final next = Map<String, SermonNote>.from(notesNotifier.value);
    next[id] = actualizada;
    notesNotifier.value = Map.unmodifiable(next);
    await _saveLocalCache(next);
    unawaited(NotasSync.I.guardar('${_prefijo(uid)}$id', {'fijada': fijada}));
  }

  Future<void> deleteNote(String id) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final adjuntos = notesNotifier.value[id]?.adjuntos ?? const [];
    if (adjuntos.isNotEmpty) {
      unawaited(AdjuntosNotaService.I.borrarNota(id, adjuntos));
    }
    final next = Map<String, SermonNote>.from(notesNotifier.value)..remove(id);
    notesNotifier.value = Map.unmodifiable(next);
    await _saveLocalCache(next);
    unawaited(NotasSync.I.borrar('${_prefijo(uid)}$id'));
  }

  void _listen() {
    final uid = _uid;
    if (uid == null) return;
    try {
      // Sin límite: con `.limit(300)` los apuntes más viejos desaparecían de
      // la lista (y de la cache local) al pasar de 300.
      _subscription = _col
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
            if (_uid != uid) return;
            final remoto = <String, SermonNote>{};
            for (final doc in snap.docs) {
              try {
                remoto[doc.id] = SermonNote.fromMap(doc.id, doc.data());
              } catch (e) {
                debugPrint('[SERMON-NOTES] parse error: $e');
              }
            }
            aplicarSnapshot(remoto, desdeCache: snap.metadata.isFromCache);
          }, onError: (e) => debugPrint('[SERMON-NOTES] listen error: $e'));
    } catch (e) {
      debugPrint('[SERMON-NOTES] No se pudo escuchar la nube: $e');
    }
  }

  /// Une un snapshot COMPLETO de la nube con lo que hay en el teléfono.
  @visibleForTesting
  void aplicarSnapshot(
    Map<String, SermonNote> remoto, {
    required bool desdeCache,
  }) {
    final uid = _uid;
    if (uid == null) return;
    final prefijo = _prefijo(uid);
    final unidos = fusionarConServidor<SermonNote>(
      local: notesNotifier.value,
      remoto: remoto,
      desdeCache: desdeCache,
      guardadoPendiente: (id) => NotasSync.I.guardadoPendiente('$prefijo$id'),
      borradoPendiente: (id) => NotasSync.I.borradoPendiente('$prefijo$id'),
    );
    notesNotifier.value = Map.unmodifiable(unidos);
    unawaited(_saveLocalCache(unidos));
  }

  String _cacheKey(String uid) => '$_cachePrefix.$uid';

  Future<void> _loadLocalCache(String uid) async {
    try {
      final raw = _prefs?.getString(_cacheKey(uid));
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final notes = decoded.whereType<Map>().map((raw) {
        final data = Map<String, dynamic>.from(raw);
        final id = data.remove('id') as String? ?? '';
        if (id.isEmpty) return null;
        return SermonNote.fromMap(id, data);
      }).whereType<SermonNote>();
      notesNotifier.value = Map.unmodifiable({for (final n in notes) n.id: n});
    } catch (e) {
      debugPrint('[SERMON-NOTES] local cache load error: $e');
    }
  }

  Future<void> _saveLocalCache(Map<String, SermonNote> notes) async {
    final uid = _uid;
    if (uid == null) return;
    final encoded = notes.values.map((note) {
      final map = note.toMap();
      map['id'] = note.id;
      map['sermonDateMs'] = note.sermonDate.millisecondsSinceEpoch;
      map['createdAtMs'] = note.createdAt.millisecondsSinceEpoch;
      map['updatedAtMs'] = note.updatedAt.millisecondsSinceEpoch;
      map.remove('sermonDate');
      map.remove('createdAt');
      map.remove('updatedAt');
      return map;
    }).toList();
    try {
      await _prefs?.setString(_cacheKey(uid), jsonEncode(encoded));
    } catch (e) {
      debugPrint('[SERMON-NOTES] local cache save error: $e');
    }
  }
}
