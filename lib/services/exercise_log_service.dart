import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una compleción registrada de un ejercicio.
@immutable
class ExerciseCompletion {
  final String id;
  final String exerciseId;
  final DateTime completedAt;
  final int durationSeconds;
  final int? moodBefore; // 1..5
  final int? moodAfter; // 1..5

  const ExerciseCompletion({
    required this.id,
    required this.exerciseId,
    required this.completedAt,
    required this.durationSeconds,
    this.moodBefore,
    this.moodAfter,
  });

  /// Delta de estado de ánimo (positivo = mejoró). null si faltan datos.
  int? get moodDelta {
    if (moodBefore == null || moodAfter == null) return null;
    return moodAfter! - moodBefore!;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'completedAt': completedAt.toUtc().toIso8601String(),
        'durationSeconds': durationSeconds,
        if (moodBefore != null) 'moodBefore': moodBefore,
        if (moodAfter != null) 'moodAfter': moodAfter,
      };

  factory ExerciseCompletion.fromJson(Map<String, dynamic> json) {
    return ExerciseCompletion(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      completedAt:
          DateTime.tryParse(json['completedAt'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      moodBefore: (json['moodBefore'] as num?)?.toInt(),
      moodAfter: (json['moodAfter'] as num?)?.toInt(),
    );
  }
}

/// Singleton que registra y consulta la compleción de ejercicios.
///
/// Estrategia offline-first:
///   • SharedPreferences como fuente de verdad local (rápida, sin red).
///   • Firestore como mejor-esfuerzo para sincronizar entre dispositivos.
///
/// Notifica a sus listeners ante cualquier cambio (UI reactiva).
class ExerciseLogService extends ChangeNotifier {
  ExerciseLogService._();
  static final ExerciseLogService I = ExerciseLogService._();

  static const String _kPrefsKey = 'exercise_log_v1';
  static const int _kMaxLocal = 200;

  /// `completedAt` (ISO UTC) del registro más nuevo que ya está en la nube.
  /// Con esto, al abrir la app solo se descarga lo que llegó después en vez
  /// de los 200 registros completos.
  static const String _kSyncKey = 'exercise_log_sync_v1';

  final List<ExerciseCompletion> _entries = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Cargar log local desde SharedPreferences. Idempotente.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _entries
          ..clear()
          ..addAll(list
              .whereType<Map<String, dynamic>>()
              .map(ExerciseCompletion.fromJson));
      }
    } catch (e) {
      debugPrint('⚠️ [ExerciseLog] init error: $e');
    }
    _initialized = true;
    notifyListeners();
  }

  /// Limpia el log local (usado al cerrar sesión).
  Future<void> clearLocal() async {
    _entries.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefsKey);
      await prefs.remove(_kSyncKey);
    } catch (_) {}
    notifyListeners();
  }

  /// Descarga el log del usuario desde Firestore al iniciar sesión.
  /// Se invoca desde `AccountSessionManager._bootstrapNewUser` después
  /// de la conexión de los repositorios principales.
  ///
  /// Estrategia: union last-write-wins por `id` (millis). La nube es
  /// autoritativa para entradas que sólo existen allí; entradas locales
  /// que no están en cloud se suben en background.
  ///
  /// Para no gastar lecturas en cada arranque, después de la primera vez
  /// solo pide los registros más nuevos que la última sincronización, y solo
  /// sube los locales que faltan en la nube.
  Future<void> hydrateFromCloud() async {
    if (!_initialized) await init();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final marca = _entries.isEmpty ? null : prefs.getString(_kSyncKey);
      Query<Map<String, dynamic>> consulta = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('exerciseLogs');
      if (marca != null) {
        consulta = consulta.where('completedAt', isGreaterThan: marca);
      }
      final snap = await consulta
          .orderBy('completedAt', descending: true)
          .limit(_kMaxLocal)
          .get();

      final enNube = <String>{};
      String? masNuevaEnNube;
      // Merge: byId, prefer cloud.
      final byId = <String, ExerciseCompletion>{
        for (final e in _entries) e.id: e,
      };
      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          final c = ExerciseCompletion.fromJson(data);
          byId[c.id] = c;
          enNube.add(c.id);
          final iso = data['completedAt'] as String?;
          if (iso != null &&
              (masNuevaEnNube == null || iso.compareTo(masNuevaEnNube) > 0)) {
            masNuevaEnNube = iso;
          }
        } catch (_) {}
      }
      if (snap.docs.isNotEmpty) {
        final merged = byId.values.toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
        _entries
          ..clear()
          ..addAll(merged.take(_kMaxLocal));
        notifyListeners();
        unawaited(_persistLocal());
      }
      // Subir solo los locales que faltan en la nube (los anteriores a la
      // marca ya se subieron en una sincronización pasada).
      final pendientes = porSubir(_entries, enNube: enNube, marca: marca);
      final subidos = await _backfillRemote(pendientes);
      if (subidos) {
        final candidatos = [
          ?marca,
          ?masNuevaEnNube,
          for (final e in pendientes) _iso(e),
        ];
        if (candidatos.isNotEmpty) {
          candidatos.sort();
          await prefs.setString(_kSyncKey, candidatos.last);
        }
      }
      debugPrint(
        '🏋️ [ExerciseLog] ${snap.docs.length} nuevos de la nube, '
        '${pendientes.length} por subir',
      );
    } catch (e) {
      debugPrint('⚠️ [ExerciseLog] hydrateFromCloud error: $e');
    }
  }

  static String _iso(ExerciseCompletion e) =>
      e.completedAt.toUtc().toIso8601String();

  /// Locales que faltan en la nube: no vinieron en la descarga y son más
  /// nuevos que la última sincronización (lo anterior ya se subió).
  @visibleForTesting
  static List<ExerciseCompletion> porSubir(
    List<ExerciseCompletion> locales, {
    required Set<String> enNube,
    String? marca,
  }) => [
    for (final e in locales)
      if (!enNube.contains(e.id) &&
          (marca == null || _iso(e).compareTo(marca) > 0))
        e,
  ];

  /// Sube [entradas] (best-effort). Devuelve false si falló la subida.
  Future<bool> _backfillRemote(List<ExerciseCompletion> entradas) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (entradas.isEmpty) return true;
    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('exerciseLogs');
      // Batch de hasta 50 writes (Firestore admite 500 por batch).
      final batch = FirebaseFirestore.instance.batch();
      for (final e in entradas.take(50)) {
        batch.set(col.doc(e.id), e.toJson(), SetOptions(merge: true));
      }
      await batch.commit();
      return entradas.length <= 50;
    } catch (e) {
      debugPrint('⚠️ [ExerciseLog] backfill skipped: $e');
      return false;
    }
  }

  // ──────────────────────────── Lectura ────────────────────────────

  List<ExerciseCompletion> get all => List.unmodifiable(_entries);

  int get totalCount => _entries.length;

  int countFor(String exerciseId) =>
      _entries.where((e) => e.exerciseId == exerciseId).length;

  bool wasDoneToday(String exerciseId) {
    final now = DateTime.now();
    return _entries.any((e) =>
        e.exerciseId == exerciseId && _isSameDay(e.completedAt, now));
  }

  /// IDs de ejercicios completados hoy (para mostrar check ✓).
  Set<String> todayCompletedIds() {
    final now = DateTime.now();
    return _entries
        .where((e) => _isSameDay(e.completedAt, now))
        .map((e) => e.exerciseId)
        .toSet();
  }

  // ──────────────────────────── Escritura ────────────────────────────

  /// Registra una compleción. Persiste local + sincroniza Firestore (best-effort).
  Future<void> log({
    required String exerciseId,
    required int durationSeconds,
    int? moodBefore,
    int? moodAfter,
  }) async {
    final completion = ExerciseCompletion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      exerciseId: exerciseId,
      completedAt: DateTime.now(),
      durationSeconds: durationSeconds,
      moodBefore: moodBefore,
      moodAfter: moodAfter,
    );

    _entries.insert(0, completion);
    if (_entries.length > _kMaxLocal) {
      _entries.removeRange(_kMaxLocal, _entries.length);
    }
    notifyListeners();

    // Persistencia local
    unawaited(_persistLocal());

    // Sincronización Firestore (best-effort, no bloquea UI)
    unawaited(_persistRemote(completion));
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(_entries.map((e) => e.toJson()).toList(growable: false));
      await prefs.setString(_kPrefsKey, encoded);
    } catch (e) {
      debugPrint('⚠️ [ExerciseLog] _persistLocal error: $e');
    }
  }

  Future<void> _persistRemote(ExerciseCompletion completion) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('exerciseLogs')
          .doc(completion.id)
          .set(completion.toJson(), SetOptions(merge: true));
    } catch (e) {
      // No es crítico — los datos viven en local hasta la próxima sync.
      debugPrint('⚠️ [ExerciseLog] _persistRemote skipped: $e');
    }
  }

  // ──────────────────────────── Helpers ────────────────────────────

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
