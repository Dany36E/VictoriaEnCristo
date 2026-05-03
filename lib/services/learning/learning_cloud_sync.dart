/// ═══════════════════════════════════════════════════════════════════════════
/// LearningCloudSync — sincronización unificada de la Escuela del Reino.
///
/// Problema que resuelve:
///   Los 11 servicios de aprendizaje (LearningProgress, VerseMemory, Journey,
///   Heroes, Parables, Timeline, Fruit, Book, BibleMap, Prophecy, BibleOrder)
///   solo guardaban en SharedPreferences. El usuario perdía TODO su progreso
///   al reinstalar o cambiar de dispositivo.
///
/// Filosofía (misma que TalentsService):
///   1. Offline-first: SharedPreferences es la verdad local. La sync es best
///      effort y nunca bloquea al usuario.
///   2. Token-friendly con Firestore: 1 lectura al login, y 1 ÚNICA escritura
///      por ventana de 30 s (debounce) agrupando TODOS los cambios de los
///      11 servicios. Sin listeners realtime.
///   3. Conflict resolution: last-write-wins por `updatedAtMs`. Caso real:
///      el usuario rara vez juega en 2 dispositivos simultáneamente. Si lo
///      hace, el último en sincronizar gana — aceptable para un juego.
///
/// Doc Firestore:
///   users/{uid}/learning/state
///     `{
///       prefs: { key: json-string, ... },
///       updatedAtMs: int,
///       updatedAt:   server-timestamp,
///     }`
///
/// Coste estimado por usuario activo:
///   • 1 read/login.
///   • ~5–15 writes/hora (debounce 30 s) — 1 doc de ~5–30 KB.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningCloudSync {
  LearningCloudSync._();
  static final LearningCloudSync I = LearningCloudSync._();

  // ── Claves de SharedPreferences que deben viajar con el usuario ──────────
  // Orden: progreso general → módulos → versículos.
  static const List<String> _syncedKeys = <String>[
    // LearningProgressService
    'learning.progress.v2',
    // JourneyProgressService
    'journey_progress_v1',
    // HeroesProgressService
    'heroes_progress_v1',
    // BibleMapProgressService
    'bible_map_progress_v1',
    // ParableProgressService
    'parable_progress_v1',
    // TimelineProgressService
    'timeline_progress_v1',
    // FruitProgressService
    'fruit_progress_v1',
    // BookProgressService (2 keys)
    'book.studied',
    'book.scores',
    // ProphecyProgressService
    'prophecy.stars',
    // BibleOrderProgressService
    'bible_order.stars',
    // VerseMemoryService (2 keys)
    'verse_memory_states_v1',
    'verse_memory_version_v1',
    // Talents y Coleccionables viven en TalentsService (doc propio `economy`);
    // no se duplican aquí para no escribir 2 veces lo mismo.
  ];

  static const String _kLocalUpdatedAtMs = 'learning.sync.updatedAtMs.v1';
  static const Duration _debounce = Duration(seconds: 30);

  SharedPreferences? _prefs;
  Timer? _timer;
  bool _dirty = false;
  String? _bootstrappedUid;
  bool _listenersAttached = false;
  final List<VoidCallback> _detachers = [];

  /// Ejecutar ANTES de inicializar los *ProgressService para que éstos carguen
  /// de SharedPreferences ya hidratadas con los datos más recientes del cloud.
  /// Es idempotente por usuario.
  Future<void> bootstrap({bool force = false}) async {
    _prefs = await SharedPreferences.getInstance();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      debugPrint('☁️ [LEARN_SYNC] Sin usuario, skip bootstrap');
      return;
    }
    if (!force && _bootstrappedUid == uid) return;
    _bootstrappedUid = uid;

    final ref = _docRef(uid);

    try {
      final snap = await ref.get();
      if (!snap.exists) {
        debugPrint('☁️ [LEARN_SYNC] Doc remoto no existe, subiré lo local');
        // Nada que hidratar. Programamos un push si hay datos locales.
        if (_hasLocalData()) _schedulePush();
        return;
      }
      final data = snap.data() ?? {};
      final remoteMs = (data['updatedAtMs'] as num?)?.toInt() ?? 0;
      final localMs = _prefs?.getInt(_kLocalUpdatedAtMs) ?? 0;

      if (remoteMs > localMs) {
        // Remoto gana: hidratar prefs locales.
        final remotePrefs = (data['prefs'] as Map?) ?? const {};
        int restored = 0;
        for (final k in _syncedKeys) {
          final v = remotePrefs[k];
          if (v is String) {
            await _prefs?.setString(k, v);
            restored++;
          } else if (v is List) {
            // book.studied se guarda como StringList — aceptamos ambos formatos.
            await _prefs?.setStringList(k, v.map((e) => '$e').toList());
            restored++;
          }
        }
        await _prefs?.setInt(_kLocalUpdatedAtMs, remoteMs);
        debugPrint(
          '☁️ [LEARN_SYNC] Hidratado desde cloud: $restored keys (remote=$remoteMs > local=$localMs)',
        );
      } else if (localMs > remoteMs && _hasLocalData()) {
        // Local gana: programar push.
        debugPrint('☁️ [LEARN_SYNC] Local es más reciente ($localMs > $remoteMs), push programado');
        _schedulePush();
      } else {
        debugPrint('☁️ [LEARN_SYNC] Sincronizado (both=$localMs)');
      }
    } catch (e) {
      // Firestore offline / red caída: la app sigue con datos locales.
      debugPrint('☁️ [LEARN_SYNC] Bootstrap falló: $e');
    }
  }

  /// Enganchar listeners a los ValueNotifiers de los servicios. Cada cambio
  /// programa un push debounceado. Se llama UNA vez tras `initAll`.
  void attachListeners(List<Listenable> notifiers) {
    if (_listenersAttached) return;
    _listenersAttached = true;
    for (final n in notifiers) {
      void cb() => markDirty();
      n.addListener(cb);
      _detachers.add(() => n.removeListener(cb));
    }
    debugPrint('☁️ [LEARN_SYNC] Observando ${notifiers.length} notifiers');
  }

  /// Marca que hay cambios locales pendientes. Debouncea el push 30 s.
  void markDirty() {
    if (_bootstrappedUid == null) return;
    _dirty = true;
    _prefs?.setInt(_kLocalUpdatedAtMs, DateTime.now().millisecondsSinceEpoch);
    _schedulePush();
  }

  void _schedulePush() {
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(_push()));
  }

  /// Fuerza un push inmediato (logout, dispose).
  Future<void> flush() async {
    _timer?.cancel();
    if (_dirty) await _push();
  }

  void resetForSignOut() {
    _timer?.cancel();
    _dirty = false;
    _bootstrappedUid = null;
  }

  Future<void> clearLocalCache() async {
    _prefs ??= await SharedPreferences.getInstance();
    for (final key in _syncedKeys) {
      await _prefs?.remove(key);
    }
    await _prefs?.remove(_kLocalUpdatedAtMs);
    resetForSignOut();
  }

  /// Desengancha listeners (útil en tests o sign-out con reset completo).
  void detachAll() {
    for (final d in _detachers) {
      d();
    }
    _detachers.clear();
    _listenersAttached = false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Implementación interna
  // ══════════════════════════════════════════════════════════════════════════

  DocumentReference<Map<String, dynamic>> _docRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learning')
        .doc('state');
  }

  bool _hasLocalData() {
    final p = _prefs;
    if (p == null) return false;
    for (final k in _syncedKeys) {
      if (p.containsKey(k)) return true;
    }
    return false;
  }

  Map<String, dynamic> _collectPrefs() {
    final p = _prefs;
    final out = <String, dynamic>{};
    if (p == null) return out;
    for (final k in _syncedKeys) {
      // La mayoría son strings JSON. book.studied es StringList → lo pasamos
      // como list; Firestore lo serializa correctamente.
      final v = p.get(k);
      if (v == null) continue;
      if (v is String) {
        out[k] = v;
      } else if (v is List) {
        out[k] = v.map((e) => '$e').toList();
      } else {
        // int/bool/double — improbable pero por seguridad.
        out[k] = '$v';
      }
    }
    return out;
  }

  Future<void> _push() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      _dirty = false;
      return;
    }
    final ref = _docRef(uid);
    final prefsMap = _collectPrefs();
    if (prefsMap.isEmpty) {
      _dirty = false;
      return;
    }
    final updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final snap = await ref.get();
      final remotePrefs = Map<String, dynamic>.from(
        (snap.data()?['prefs'] as Map?) ?? const <String, dynamic>{},
      );
      final mergedPrefs = <String, dynamic>{...remotePrefs, ...prefsMap};
      await ref.set({
        'prefs': mergedPrefs,
        'updatedAtMs': updatedAtMs,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _prefs?.setInt(_kLocalUpdatedAtMs, updatedAtMs);
      _dirty = false;
      debugPrint('☁️ [LEARN_SYNC] Push OK (${prefsMap.length} keys, ms=$updatedAtMs)');
    } catch (e) {
      // No reintentamos explícitamente; el próximo `markDirty` reprograma.
      debugPrint('☁️ [LEARN_SYNC] Push falló: $e');
    }
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _timer?.cancel();
    detachAll();
    _bootstrappedUid = null;
    _dirty = false;
    await _prefs?.remove(_kLocalUpdatedAtMs);
  }
}
