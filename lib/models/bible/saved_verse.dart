import 'package:cloud_firestore/cloud_firestore.dart';

/// Versículo guardado/marcado por el usuario.
class SavedVerse {
  final String id; // Firestore doc ID
  final int bookNumber;
  final int chapter;
  final int verse;

  /// Último versículo cuando se guardó un pasaje («1 Tes 5:16-18»).
  /// null = un solo versículo (lo normal desde el lector).
  final int? endVerse;
  final String bookName;
  final String text;
  final String version;
  final DateTime savedAt;

  const SavedVerse({
    required this.id,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    this.endVerse,
    required this.bookName,
    required this.text,
    required this.version,
    required this.savedAt,
  });

  /// Referencia legible
  String get reference => endVerse != null && endVerse! > verse
      ? '$bookName $chapter:$verse-$endVerse'
      : '$bookName $chapter:$verse';

  /// Clave del versículo para lookup
  String get verseKey => '$bookNumber:$chapter:$verse';

  Map<String, dynamic> toMap() => {
        'bookNumber': bookNumber,
        'chapter': chapter,
        'verse': verse,
        if (endVerse != null) 'endVerse': endVerse,
        'bookName': bookName,
        'text': text,
        'version': version,
        'savedAt': Timestamp.fromDate(savedAt),
      };

  factory SavedVerse.fromMap(String id, Map<String, dynamic> map) => SavedVerse(
        id: id,
        bookNumber: map['bookNumber'] as int,
        chapter: map['chapter'] as int,
        verse: map['verse'] as int,
        endVerse: (map['endVerse'] as num?)?.toInt(),
        bookName: map['bookName'] as String? ?? '',
        text: map['text'] as String? ?? '',
        version: map['version'] as String? ?? 'RVR1960',
        savedAt: (map['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
