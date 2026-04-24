/// ═══════════════════════════════════════════════════════════════════════════
/// QuestionRepository — carga las preguntas de la Escuela del Reino
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../models/learning/learning_models.dart';

class QuestionRepository {
  QuestionRepository._();
  static final QuestionRepository I = QuestionRepository._();

  List<LearningQuestion>? _questions;
  bool _loading = false;

  bool get isLoaded => _questions != null;
  List<LearningQuestion> get all => _questions ?? const [];

  Future<void> load() async {
    if (_questions != null || _loading) return;
    _loading = true;
    try {
      final raw =
          await rootBundle.loadString('assets/content/learning_questions.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _questions = list.map(LearningQuestion.fromJson).toList();
      debugPrint('🎓 [LEARNING] Loaded ${_questions!.length} questions');
    } catch (e) {
      debugPrint('🎓 [LEARNING] Error loading questions: $e');
      _questions = const [];
    } finally {
      _loading = false;
    }
  }

  /// Selecciona [count] preguntas variadas para una sesión.
  /// Heurística Fase 1: shuffle + tomar N; asegura mezcla de tipos si hay.
  List<LearningQuestion> pickSession({
    int count = 7,
    int? seed,
  }) {
    final pool = List<LearningQuestion>.from(all);
    if (pool.isEmpty) return const [];
    final rnd = seed != null ? Random(seed) : Random();
    pool.shuffle(rnd);
    if (pool.length <= count) return pool;
    // Intentar balance por tipo
    final byType = <QuestionType, List<LearningQuestion>>{};
    for (final q in pool) {
      byType.putIfAbsent(q.type, () => []).add(q);
    }
    final result = <LearningQuestion>[];
    final types = byType.keys.toList()..shuffle(rnd);
    var i = 0;
    while (result.length < count && byType.values.any((l) => l.isNotEmpty)) {
      final t = types[i % types.length];
      final bucket = byType[t]!;
      if (bucket.isNotEmpty) {
        result.add(bucket.removeAt(0));
      }
      i++;
    }
    return result;
  }
}
