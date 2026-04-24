/// ManaSessionPersistence — guarda el cursor de una sesión Maná en curso.
///
/// Para que el usuario pueda salir de la sesión (interrupción, llamada, etc.)
/// y retomarla más tarde sin perder progreso. Solo persiste la información
/// macro: índice actual, aciertos/errores acumulados, IDs de preguntas y si
/// usó alguna vez la opción "no la sé".
///
/// El estado interno por pregunta (selección actual, texto en input, secuencia
/// de orderEvents…) NO se restaura: al volver, esa pregunta se reinicia desde
/// cero. Es un trade-off honesto: simplicidad vs perfección. La pérdida es 1
/// pregunta como máximo.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManaSessionSnapshot {
  final List<String> questionIds;
  final int idx;
  final int correct;
  final int wrong;
  final bool usedHonesty;
  final int savedAtMs;

  const ManaSessionSnapshot({
    required this.questionIds,
    required this.idx,
    required this.correct,
    required this.wrong,
    required this.usedHonesty,
    required this.savedAtMs,
  });

  Map<String, dynamic> toJson() => {
        'questionIds': questionIds,
        'idx': idx,
        'correct': correct,
        'wrong': wrong,
        'usedHonesty': usedHonesty,
        'savedAtMs': savedAtMs,
      };

  factory ManaSessionSnapshot.fromJson(Map<String, dynamic> j) =>
      ManaSessionSnapshot(
        questionIds:
            (j['questionIds'] as List?)?.map((e) => '$e').toList() ?? const [],
        idx: (j['idx'] as num?)?.toInt() ?? 0,
        correct: (j['correct'] as num?)?.toInt() ?? 0,
        wrong: (j['wrong'] as num?)?.toInt() ?? 0,
        usedHonesty: (j['usedHonesty'] as bool?) ?? false,
        savedAtMs: (j['savedAtMs'] as num?)?.toInt() ?? 0,
      );
}

class ManaSessionPersistence {
  ManaSessionPersistence._();
  static final ManaSessionPersistence I = ManaSessionPersistence._();

  static const String _kKey = 'learning.mana.session_v1';
  // Sesiones más viejas que esto se descartan al cargar.
  static const int _maxAgeMs = 24 * 60 * 60 * 1000; // 24 h

  Future<ManaSessionSnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null || raw.isEmpty) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final snap = ManaSessionSnapshot.fromJson(j);
      final ageMs = DateTime.now().millisecondsSinceEpoch - snap.savedAtMs;
      if (ageMs > _maxAgeMs) {
        await prefs.remove(_kKey);
        return null;
      }
      if (snap.questionIds.isEmpty) return null;
      // Si ya estaba terminada, ignorar.
      if (snap.idx >= snap.questionIds.length) return null;
      return snap;
    } catch (e) {
      debugPrint('🎓 [MANA] Error cargando sesión: $e');
      return null;
    }
  }

  Future<void> save(ManaSessionSnapshot snap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKey, jsonEncode(snap.toJson()));
    } catch (e) {
      debugPrint('🎓 [MANA] Error guardando sesión: $e');
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kKey);
    } catch (_) {/* swallow */}
  }
}
