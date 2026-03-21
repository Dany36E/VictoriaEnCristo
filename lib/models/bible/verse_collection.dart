import 'package:cloud_firestore/cloud_firestore.dart';

/// Referencia ligera a un versículo dentro de una colección.
class VerseRef {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;
  final String version;
  final DateTime addedAt;

  const VerseRef({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.version,
    required this.addedAt,
  });

  String get reference => '$bookName $chapter:$verse';
  String get uniqueKey => '$bookNumber:$chapter:$verse';

  Map<String, dynamic> toMap() => {
        'bookNumber': bookNumber,
        'bookName': bookName,
        'chapter': chapter,
        'verse': verse,
        'text': text,
        'version': version,
        'addedAt': Timestamp.fromDate(addedAt),
      };

  factory VerseRef.fromMap(Map<String, dynamic> m) => VerseRef(
        bookNumber: m['bookNumber'] as int,
        bookName: m['bookName'] as String,
        chapter: m['chapter'] as int,
        verse: m['verse'] as int,
        text: m['text'] as String,
        version: m['version'] as String,
        addedAt: (m['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

/// Colección temática de versículos creada por el usuario.
/// Firestore: /users/{uid}/verseCollections/{docId}
class VerseCollection {
  final String id;
  final String name;
  final String? description;
  final String emoji; // emoji como ícono
  final List<VerseRef> verses;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VerseCollection({
    required this.id,
    required this.name,
    this.description,
    this.emoji = '📖',
    this.verses = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  int get verseCount => verses.length;

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'emoji': emoji,
        'verses': verses.map((v) => v.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory VerseCollection.fromMap(String id, Map<String, dynamic> m) {
    final verseList = (m['verses'] as List<dynamic>?)
            ?.map((v) => VerseRef.fromMap(v as Map<String, dynamic>))
            .toList() ??
        [];
    return VerseCollection(
      id: id,
      name: m['name'] as String? ?? 'Sin nombre',
      description: m['description'] as String?,
      emoji: m['emoji'] as String? ?? '📖',
      verses: verseList,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
