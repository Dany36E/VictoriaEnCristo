import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Códigos de color del Modo Estudio (alineados con el método de estudio
/// inductivo: rojo = palabras clave/repetidas, verde = sinónimos/antónimos,
/// azul = lugares/geografía, amarillo = marcatextos general).
enum StudyHighlightCode {
  red(key: 'red', label: 'Palabras clave', colorHex: '#EF5350'),
  green(key: 'green', label: 'Sinónimos / Antónimos', colorHex: '#66BB6A'),
  blue(key: 'blue', label: 'Lugares / Geografía', colorHex: '#42A5F5'),
  yellow(key: 'yellow', label: 'Marcatextos', colorHex: '#FFEE58');

  final String key;
  final String label;
  final String colorHex;
  const StudyHighlightCode({required this.key, required this.label, required this.colorHex});

  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  static StudyHighlightCode fromKey(String? key) {
    return StudyHighlightCode.values.firstWhere(
      (c) => c.key == key,
      orElse: () => StudyHighlightCode.yellow,
    );
  }
}

/// Subrayado granular dentro del Modo Estudio.
///
/// `startWord` y `endWord` son índices [start, end) sobre la lista de tokens
/// del versículo (separados por espacios al renderizar). Si abarca el versículo
/// completo, `startWord = 0` y `endWord = wordCount`.
class StudyWordHighlight {
  final String id;
  final int bookNumber;
  final int chapter;
  final int verse;
  final int startWord;
  final int endWord;
  final String code; // StudyHighlightCode.key
  final DateTime createdAt;

  const StudyWordHighlight({
    required this.id,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.startWord,
    required this.endWord,
    required this.code,
    required this.createdAt,
  });

  StudyHighlightCode get codeEnum => StudyHighlightCode.fromKey(code);
  String get verseKey => '$bookNumber:$chapter:$verse';
  String get chapterKey => '$bookNumber:$chapter';

  bool overlapsWord(int wordIndex) =>
      wordIndex >= startWord && wordIndex < endWord;

  Map<String, dynamic> toMap() => {
        'bookNumber': bookNumber,
        'chapter': chapter,
        'verse': verse,
        'startWord': startWord,
        'endWord': endWord,
        'code': code,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory StudyWordHighlight.fromMap(String id, Map<String, dynamic> map) =>
      StudyWordHighlight(
        id: id,
        bookNumber: map['bookNumber'] as int,
        chapter: map['chapter'] as int,
        verse: map['verse'] as int,
        startWord: map['startWord'] as int? ?? 0,
        endWord: map['endWord'] as int? ?? 0,
        code: map['code'] as String? ?? 'yellow',
        createdAt:
            (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
