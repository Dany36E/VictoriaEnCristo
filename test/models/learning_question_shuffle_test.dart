import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_quitar/models/learning/learning_models.dart';
import 'package:flutter_test/flutter_test.dart';

List<LearningQuestion> _bank() {
  final raw = File('assets/content/learning_questions.json').readAsStringSync();
  return (jsonDecode(raw) as List)
      .cast<Map<String, dynamic>>()
      .map(LearningQuestion.fromJson)
      .toList();
}

/// Secuencia cronológica de textos según la pregunta (como la califica Maná).
List<String> _chronology(LearningQuestion q) => [
  for (final i in q.effectiveCorrectOrder) q.options[i],
];

bool _isIdentity(List<int> order) {
  for (var i = 0; i < order.length; i++) {
    if (order[i] != i) return false;
  }
  return true;
}

void main() {
  group('Ordena los eventos — barajado', () {
    final orderQuestions = _bank()
        .where((q) => q.type == QuestionType.orderEvents)
        .toList();

    test('el banco tiene preguntas de ordenar', () {
      expect(orderQuestions, isNotEmpty);
    });

    test(
      'nunca se presentan ya ordenadas y se califican contra la cronología real',
      () {
        for (final q in orderQuestions) {
          final expectedChronology = _chronology(q);
          for (var seed = 0; seed < 300; seed++) {
            final shown = q.shuffledChoices(Random(seed));
            expect(shown.options.toSet(), q.options.toSet(), reason: q.id);
            expect(
              _isIdentity(shown.effectiveCorrectOrder),
              isFalse,
              reason: '${q.id} (seed $seed) se mostró ya en orden correcto',
            );
            expect(
              shown.options,
              isNot(equals(expectedChronology)),
              reason:
                  '${q.id} (seed $seed) opciones visibles en orden cronológico',
            );
            // El orden correcto remapeado sigue describiendo la misma cronología.
            expect(
              _chronology(shown),
              expectedChronology,
              reason: '${q.id} (seed $seed)',
            );

            // Simula al usuario tocando los eventos en orden cronológico,
            // tal como lo registra ManaSessionScreen (_orderSeq).
            final taps = [
              for (final e in expectedChronology) shown.options.indexOf(e),
            ];
            expect(
              taps,
              shown.effectiveCorrectOrder,
              reason: '${q.id} (seed $seed)',
            );
          }
        }
      },
    );

    test('con correctOrder vacío asume que las opciones vienen en orden', () {
      const q = LearningQuestion(
        id: 't',
        type: QuestionType.orderEvents,
        prompt: 'Ordena',
        options: ['A', 'B', 'C'],
        correctIndex: 0,
        explanation: 'x',
      );
      expect(q.effectiveCorrectOrder, [0, 1, 2]);
      for (var seed = 0; seed < 50; seed++) {
        final shown = q.shuffledChoices(Random(seed));
        expect(_chronology(shown), ['A', 'B', 'C']);
        expect(shown.options, isNot(equals(['A', 'B', 'C'])));
      }
    });

    test('dos eventos también se invierten siempre', () {
      const q = LearningQuestion(
        id: 't2',
        type: QuestionType.orderEvents,
        prompt: 'Ordena',
        options: ['Primero', 'Segundo'],
        correctIndex: 0,
        explanation: 'x',
        correctOrder: [0, 1],
      );
      for (var seed = 0; seed < 50; seed++) {
        expect(q.shuffledChoices(Random(seed)).options, ['Segundo', 'Primero']);
      }
    });
  });

  group('Opción múltiple — barajado', () {
    test('la respuesta correcta se conserva tras barajar', () {
      for (final q in _bank()) {
        final shown = q.shuffledChoices(Random(q.id.hashCode));
        if (q.type == QuestionType.orderEvents) continue;
        if (q.options.isEmpty) continue;
        expect(
          shown.options[shown.correctIndex],
          q.options[q.correctIndex],
          reason: q.id,
        );
      }
    });

    test('verdadero/falso no se baraja', () {
      for (final q in _bank().where((q) => q.type == QuestionType.trueFalse)) {
        expect(
          identical(q.shuffledChoices(Random(1)), q),
          isTrue,
          reason: q.id,
        );
      }
    });
  });
}
