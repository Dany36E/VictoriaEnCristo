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
  final String versionId;
  final int bookNumber;
  final int chapter;
  final int verse;
  final int startWord;
  final int endWord;
  final String code; // StudyHighlightCode.key
  final String? ownerUid;
  final String? ownerName;
  final DateTime createdAt;

  const StudyWordHighlight({
    required this.id,
    required this.versionId,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.startWord,
    required this.endWord,
    required this.code,
    this.ownerUid,
    this.ownerName,
    required this.createdAt,
  });

  StudyHighlightCode get codeEnum => StudyHighlightCode.fromKey(code);
  String get verseKey => '$versionId:$bookNumber:$chapter:$verse';
  String get chapterKey => '$versionId:$bookNumber:$chapter';

  bool overlapsWord(int wordIndex) => wordIndex >= startWord && wordIndex < endWord;

  bool overlapsRange(int start, int end) => startWord < end && start < endWord;

  StudyWordHighlight copyWith({
    String? id,
    int? startWord,
    int? endWord,
    String? ownerUid,
    String? ownerName,
  }) => StudyWordHighlight(
    id: id ?? this.id,
    versionId: versionId,
    bookNumber: bookNumber,
    chapter: chapter,
    verse: verse,
    startWord: startWord ?? this.startWord,
    endWord: endWord ?? this.endWord,
    code: code,
    ownerUid: ownerUid ?? this.ownerUid,
    ownerName: ownerName ?? this.ownerName,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'versionId': versionId,
    'bookNumber': bookNumber,
    'chapter': chapter,
    'verse': verse,
    'startWord': startWord,
    'endWord': endWord,
    'code': code,
    if (ownerUid != null) 'ownerUid': ownerUid,
    if (ownerName != null) 'ownerName': ownerName,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory StudyWordHighlight.fromMap(String id, Map<String, dynamic> map) => StudyWordHighlight(
    id: id,
    versionId: map['versionId'] as String? ?? 'RVR1960',
    bookNumber: map['bookNumber'] as int,
    chapter: map['chapter'] as int,
    verse: map['verse'] as int,
    startWord: map['startWord'] as int? ?? 0,
    endWord: map['endWord'] as int? ?? 0,
    code: map['code'] as String? ?? 'yellow',
    ownerUid: map['ownerUid'] as String?,
    ownerName: map['ownerName'] as String?,
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
