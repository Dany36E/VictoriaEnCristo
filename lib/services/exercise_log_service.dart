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
    } catch (_) {}
    notifyListeners();
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
