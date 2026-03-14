import 'package:cloud_firestore/cloud_firestore.dart';

/// Nota personal asociada a un versículo.
class BibleNote {
  final String id; // Firestore doc ID
  final int bookNumber;
  final int chapter;
  final int verse;
  final String bookName;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BibleNote({
    required this.id,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.bookName,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Referencia legible
  String get reference => '$bookName $chapter:$verse';

  /// Clave del versículo para lookup
  String get verseKey => '$bookNumber:$chapter:$verse';

  Map<String, dynamic> toMap() => {
        'bookNumber': bookNumber,
        'chapter': chapter,
        'verse': verse,
        'bookName': bookName,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory BibleNote.fromMap(String id, Map<String, dynamic> map) => BibleNote(
        id: id,
        bookNumber: map['bookNumber'] as int,
        chapter: map['chapter'] as int,
        verse: map['verse'] as int,
        bookName: map['bookName'] as String? ?? '',
        text: map['text'] as String,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      );

  BibleNote copyWith({String? text, DateTime? updatedAt}) => BibleNote(
        id: id,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        bookName: bookName,
        text: text ?? this.text,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
