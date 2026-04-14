import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Nota de estudio asociada a un capítulo completo (no a un versículo).
class ChapterStudyNote {
  final String id;
  final String versionId; // 'RVR1960', etc.
  final int bookNumber;
  final String bookName;
  final int chapter;
  final String title;
  final String content;
  final List<String> tags;
  final String colorHex; // Color de la nota (hex sin '#')
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChapterStudyNote({
    required this.id,
    required this.versionId,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.title,
    required this.content,
    this.tags = const [],
    this.colorHex = 'D4A853',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Referencia legible: "Génesis 1"
  String get reference => '$bookName $chapter';

  /// Clave única para lookup por capítulo
  String get chapterKey => '$bookNumber:$chapter';

  /// Color parseado
  int get colorValue {
    try {
      return int.parse('FF$colorHex', radix: 16);
    } catch (e) {
      debugPrint('⚠️ [StudyNote] colorValue parse error: $e');
      return 0xFFD4A853;
    }
  }

  Map<String, dynamic> toMap() => {
        'versionId': versionId,
        'bookNumber': bookNumber,
        'bookName': bookName,
        'chapter': chapter,
        'title': title,
        'content': content,
        'tags': tags,
        'colorHex': colorHex,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory ChapterStudyNote.fromMap(String id, Map<String, dynamic> map) =>
      ChapterStudyNote(
        id: id,
        versionId: map['versionId'] as String? ?? 'RVR1960',
        bookNumber: map['bookNumber'] as int,
        bookName: map['bookName'] as String? ?? '',
        chapter: map['chapter'] as int,
        title: map['title'] as String? ?? '',
        content: map['content'] as String? ?? '',
        tags: (map['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        colorHex: map['colorHex'] as String? ?? 'D4A853',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  ChapterStudyNote copyWith({
    String? title,
    String? content,
    List<String>? tags,
    String? colorHex,
  }) =>
      ChapterStudyNote(
        id: id,
        versionId: versionId,
        bookNumber: bookNumber,
        bookName: bookName,
        chapter: chapter,
        title: title ?? this.title,
        content: content ?? this.content,
        tags: tags ?? this.tags,
        colorHex: colorHex ?? this.colorHex,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
