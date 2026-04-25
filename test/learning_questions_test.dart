import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _loadQuestions() {
  final raw = File('assets/content/learning_questions.json').readAsStringSync();
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

String _normalizedText(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('Escuela del Reino question bank', () {
    test('incluye las 100 preguntas agregadas', () {
      final questions = _loadQuestions();
      final added = questions.where((q) => (q['id'] as String).startsWith('q_add_'));

      expect(questions.length, greaterThanOrEqualTo(138));
      expect(added.length, greaterThanOrEqualTo(100));
    });

    test('todas las preguntas tienen forma válida', () {
      final questions = _loadQuestions();
      final ids = <String>{};
      final prompts = <String>{};
      const validTypes = {
        'choose_reference',
        'complete_verse',
        'match_pairs',
        'multiple_choice',
        'order_events',
        'situational',
        'true_false',
        'who_said',
      };
      const choiceTypes = {
        'who_said',
        'true_false',
        'multiple_choice',
        'choose_reference',
        'situational',
      };

      for (final q in questions) {
        final id = q['id'] as String?;
        expect(id, isNotNull, reason: 'id faltante');
        expect(ids.add(id!), isTrue, reason: 'id duplicado: $id');

        final type = q['type'] as String?;
        expect(type, isNotNull, reason: '$id no tiene type');
        expect(validTypes.contains(type), isTrue, reason: '$id tiene type inválido: $type');

        final prompt = (q['prompt'] as String?)?.trim();
        expect(prompt, isNotEmpty, reason: '$id no tiene prompt');
        expect(prompts.add(_normalizedText(prompt!)), isTrue, reason: '$id repite prompt: $prompt');

        final explanation = (q['explanation'] as String?)?.trim();
        expect(explanation, isNotEmpty, reason: '$id no tiene explicación');

        if (choiceTypes.contains(type)) {
          final options = (q['options'] as List).cast<String>();
          final correctIndex = q['correctIndex'] as int;
          expect(options.length, greaterThanOrEqualTo(2), reason: '$id sin opciones');
          expect(
            options.every((option) => option.trim().isNotEmpty),
            isTrue,
            reason: '$id tiene opciones vacías',
          );
          expect(
            options.map(_normalizedText).toSet().length,
            options.length,
            reason: '$id tiene opciones repetidas',
          );
          expect(
            correctIndex,
            inInclusiveRange(0, options.length - 1),
            reason: '$id correctIndex inválido',
          );
        }

        if (type == 'complete_verse') {
          expect((q['answerText'] as String?)?.trim(), isNotEmpty, reason: '$id sin answerText');
        }

        if (type == 'order_events') {
          final options = q['options'] as List;
          final order = (q['correctOrder'] as List).cast<int>();
          expect(order.length, options.length, reason: '$id correctOrder incompleto');
          expect(order.toSet().length, options.length, reason: '$id correctOrder duplicado');
          expect(
            order.every((i) => i >= 0 && i < options.length),
            isTrue,
            reason: '$id correctOrder fuera de rango',
          );
        }

        if (type == 'match_pairs') {
          final pairs = q['pairs'] as List;
          expect(pairs.length, greaterThanOrEqualTo(2), reason: '$id sin pares');
          for (final pair in pairs.cast<Map<String, dynamic>>()) {
            expect((pair['left'] as String?)?.trim(), isNotEmpty, reason: '$id par sin left');
            expect((pair['right'] as String?)?.trim(), isNotEmpty, reason: '$id par sin right');
          }
        }
      }
    });
  });
}
