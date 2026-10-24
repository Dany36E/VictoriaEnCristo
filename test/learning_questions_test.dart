import 'dart:convert';
import 'dart:io';

import 'package:app_quitar/models/learning/learning_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Validación del banco de preguntas de la Escuela del Reino (Maná, Carrera,
/// Duelo Relámpago) contra el texto RVR1960 incluido en la app.

List<Map<String, dynamic>> _loadQuestions() {
  final raw = File('assets/content/learning_questions.json').readAsStringSync();
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

const _accents = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

String _stripAccents(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    b.write(_accents[ch] ?? ch);
  }
  return b.toString();
}

/// Normaliza para comparar textos: minúsculas, sin tildes ni puntuación.
String _norm(String s) => _stripAccents(s)
    .replaceAll(RegExp(r'[^a-z0-9_ ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// libro normalizado → capítulo → versículo → texto.
typedef _Bible = Map<String, Map<int, Map<int, String>>>;

_Bible _loadRvr1960() {
  final doc = XmlDocument.parse(
    File('assets/bible/Reina Valera 1960.xml').readAsStringSync(),
  );
  final bible = <String, Map<int, Map<int, String>>>{};
  for (final book in doc.findAllElements('book')) {
    final chapters = <int, Map<int, String>>{};
    for (final chapter in book.findElements('chapter')) {
      chapters[int.parse(chapter.getAttribute('number')!)] = {
        for (final verse in chapter.findElements('verse'))
          int.parse(verse.getAttribute('number')!): verse.innerText,
      };
    }
    bible[_stripAccents(book.getAttribute('name')!)] = chapters;
  }
  return bible;
}

/// Segmento: «Libro C:V», «Libro C:V-W», «Libro C:V, W-X» o «Libro C:V-C2:W».
/// Varios segmentos se separan con «; » y cada uno repite el libro.
final _segment = RegExp(
  r'^((?:[1-3] )?[^\d;:,]+?) (\d+):(\d+)(?:-(\d+)(?::(\d+))?)?((?:, \d+(?:-\d+)?)*)$',
);

/// Devuelve los textos de los versículos citados o lanza [FormatException].
List<String> _resolveReference(_Bible bible, String reference) {
  final texts = <String>[];
  for (final seg in reference.split('; ')) {
    final m = _segment.firstMatch(seg);
    if (m == null) throw FormatException('segmento inválido «$seg»');
    final book = bible[_stripAccents(m.group(1)!)];
    if (book == null) {
      throw FormatException('libro desconocido «${m.group(1)}»');
    }

    String verse(int c, int v) {
      final t = book[c]?[v];
      if (t == null) throw FormatException('no existe ${m.group(1)} $c:$v');
      return t;
    }

    final c = int.parse(m.group(2)!);
    final v = int.parse(m.group(3)!);
    if (m.group(5) != null) {
      // Rango entre capítulos: C:V-C2:W
      final c2 = int.parse(m.group(4)!);
      final v2 = int.parse(m.group(5)!);
      verse(c, v);
      verse(c2, v2);
      if (c2 < c) throw FormatException('rango invertido en «$seg»');
      for (var ch = c; ch <= c2; ch++) {
        final verses = book[ch]!;
        final lo = ch == c ? v : 1;
        final hi = ch == c2 ? v2 : verses.keys.reduce((a, b) => a > b ? a : b);
        for (var i = lo; i <= hi; i++) {
          if (verses[i] != null) texts.add(verses[i]!);
        }
      }
      continue;
    }
    final ranges = <List<int>>[
      [v, m.group(4) != null ? int.parse(m.group(4)!) : v],
      for (final part in RegExp(r'\d+(?:-\d+)?').allMatches(m.group(6) ?? ''))
        [for (final n in part.group(0)!.split('-')) int.parse(n)],
    ];
    for (final r in ranges) {
      final lo = r.first;
      final hi = r.last;
      if (hi < lo) throw FormatException('rango invertido en «$seg»');
      for (var i = lo; i <= hi; i++) {
        texts.add(verse(c, i));
      }
    }
  }
  return texts;
}

/// Fragmentos citados entre «» dentro de [text], partidos por el hueco o
/// por puntos suspensivos (que indican omisión).
Iterable<String> _quotedFragments(String text) sync* {
  for (final q in RegExp(r'«([^»]+)»').allMatches(text)) {
    for (final part in q.group(1)!.split(RegExp(r'_{3,}|\.\.\.|…'))) {
      final n = _norm(part);
      if (n.isNotEmpty) yield n;
    }
  }
}

void main() {
  late List<Map<String, dynamic>> questions;
  late _Bible bible;

  setUpAll(() {
    questions = _loadQuestions();
    bible = _loadRvr1960();
  });

  group('Escuela del Reino — banco de preguntas', () {
    test('tamaño mínimo y preguntas nuevas presentes', () {
      expect(questions.length, greaterThanOrEqualTo(300));
      final added = questions.where(
        (q) => (q['id'] as String).startsWith('q_v27_'),
      );
      expect(added.length, greaterThanOrEqualTo(30));
    });

    test('todas las preguntas tienen forma válida', () {
      final ids = <String>{};
      final prompts = <String, String>{};
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
        expect(
          validTypes.contains(type),
          isTrue,
          reason: '$id tiene type inválido: $type',
        );

        final prompt = (q['prompt'] as String?)?.trim() ?? '';
        expect(prompt, isNotEmpty, reason: '$id no tiene prompt');
        final normalized = _norm(prompt);
        expect(
          prompts.containsKey(normalized),
          isFalse,
          reason: '$id repite el enunciado de ${prompts[normalized]}: $prompt',
        );
        prompts[normalized] = id;

        expect(
          (q['explanation'] as String?)?.trim(),
          isNotEmpty,
          reason: '$id sin explicación',
        );
        final difficulty = q['difficulty'] as int?;
        expect(
          difficulty,
          inInclusiveRange(1, 3),
          reason: '$id dificultad inválida',
        );

        if (choiceTypes.contains(type)) {
          final options = (q['options'] as List).cast<String>();
          final correctIndex = q['correctIndex'] as int;
          expect(
            options.length,
            greaterThanOrEqualTo(2),
            reason: '$id sin opciones',
          );
          expect(
            options.every((o) => o.trim().isNotEmpty),
            isTrue,
            reason: '$id opción vacía',
          );
          expect(
            options.map(_norm).toSet().length,
            options.length,
            reason: '$id tiene opciones repetidas',
          );
          expect(
            correctIndex,
            inInclusiveRange(0, options.length - 1),
            reason: '$id correctIndex inválido',
          );
          if (type == 'true_false') {
            expect(options, ['Verdadero', 'Falso'], reason: '$id opciones V/F');
          }
        }

        if (type == 'order_events') {
          final options = (q['options'] as List).cast<String>();
          final order = (q['correctOrder'] as List).cast<int>();
          expect(
            options.length,
            greaterThanOrEqualTo(3),
            reason: '$id muy pocos eventos',
          );
          expect(
            order.length,
            options.length,
            reason: '$id correctOrder incompleto',
          );
          expect(
            order.toSet().length,
            options.length,
            reason: '$id correctOrder duplicado',
          );
          expect(
            order.every((i) => i >= 0 && i < options.length),
            isTrue,
            reason: '$id correctOrder fuera de rango',
          );
        }

        if (type == 'match_pairs') {
          final pairs = (q['pairs'] as List).cast<Map<String, dynamic>>();
          expect(
            pairs.length,
            greaterThanOrEqualTo(2),
            reason: '$id sin pares',
          );
          for (final pair in pairs) {
            expect(
              (pair['left'] as String?)?.trim(),
              isNotEmpty,
              reason: '$id par sin left',
            );
            expect(
              (pair['right'] as String?)?.trim(),
              isNotEmpty,
              reason: '$id par sin right',
            );
          }
          expect(
            pairs.map((p) => _norm(p['right'] as String)).toSet().length,
            pairs.length,
            reason: '$id tiene pares con la misma respuesta',
          );
        }
      }
    });

    test('el token de hueco es consistente con el TTS', () {
      expect(LearningQuestion.blankToken, '___');
      for (final q in questions) {
        final id = q['id'];
        final prompt = q['prompt'] as String;
        expect(
          prompt.contains('____'),
          isFalse,
          reason: '$id usa un hueco de más de 3 guiones bajos',
        );
        if (q['type'] == 'complete_verse') {
          expect(
            LearningQuestion.blankToken.allMatches(prompt).length,
            1,
            reason:
                '$id debe tener exactamente un hueco «${LearningQuestion.blankToken}»',
          );
          final answer = (q['answerText'] as String?)?.trim() ?? '';
          expect(answer, isNotEmpty, reason: '$id sin answerText');
          expect(
            answer.contains(' '),
            isFalse,
            reason: '$id answerText debe ser una palabra',
          );
        }
      }
    });

    test('cada referencia existe en la RVR1960 y las citas coinciden', () {
      final problems = <String>[];
      for (final q in questions) {
        final id = q['id'];
        final reference = q['reference'] as String?;
        if (reference == null || reference.trim().isEmpty) {
          problems.add('$id sin referencia');
          continue;
        }
        final List<String> verses;
        try {
          verses = _resolveReference(bible, reference);
        } on FormatException catch (e) {
          problems.add('$id «$reference»: ${e.message}');
          continue;
        }
        final text = _norm(verses.join(' '));
        var prompt = q['prompt'] as String;
        if (q['type'] == 'complete_verse') {
          prompt = prompt.replaceAll(
            LearningQuestion.blankToken,
            q['answerText'] as String,
          );
        }
        for (final fragment in _quotedFragments(prompt)) {
          if (!text.contains(fragment)) {
            problems.add('$id cita «$fragment» que no está en $reference');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });
}
