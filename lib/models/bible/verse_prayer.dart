import 'package:cloud_firestore/cloud_firestore.dart';

/// Oración escrita por el usuario sobre un versículo.
class VersePrayer {
  final String id; // Firestore doc ID
  final int bookNumber;
  final int chapter;
  final int verse;
  final String bookName;
  final String prayerText;
  final DateTime createdAt;

  const VersePrayer({
    required this.id,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.bookName,
    required this.prayerText,
    required this.createdAt,
  });

  /// Referencia legible
  String get reference => '$bookName $chapter:$verse';

  /// Clave del versículo
  String get verseKey => '$bookNumber:$chapter:$verse';

  Map<String, dynamic> toMap() => {
        'bookNumber': bookNumber,
        'chapter': chapter,
        'verse': verse,
        'bookName': bookName,
        'prayerText': prayerText,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory VersePrayer.fromMap(String id, Map<String, dynamic> map) => VersePrayer(
        id: id,
        bookNumber: map['bookNumber'] as int,
        chapter: map['chapter'] as int,
        verse: map['verse'] as int,
        bookName: map['bookName'] as String? ?? '',
        prayerText: map['prayerText'] as String,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
