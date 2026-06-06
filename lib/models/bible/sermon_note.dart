import 'package:cloud_firestore/cloud_firestore.dart';

import 'bible_verse.dart';

class SermonVerseReference {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int verse;
  final String versionId;
  final String text;

  const SermonVerseReference({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.versionId,
    required this.text,
  });

  factory SermonVerseReference.fromVerse(BibleVerse verse) {
    return SermonVerseReference(
      bookNumber: verse.bookNumber,
      bookName: verse.bookName,
      chapter: verse.chapter,
      verse: verse.verse,
      versionId: verse.version,
      text: verse.text,
    );
  }

  String get reference => '$bookName $chapter:$verse';
  String get key => '$versionId:$bookNumber:$chapter:$verse';

  Map<String, dynamic> toMap() => {
    'bookNumber': bookNumber,
    'bookName': bookName,
    'chapter': chapter,
    'verse': verse,
    'versionId': versionId,
    'text': text,
  };

  factory SermonVerseReference.fromMap(Map<String, dynamic> map) {
    return SermonVerseReference(
      bookNumber: _asInt(map['bookNumber']),
      bookName: map['bookName'] as String? ?? '',
      chapter: _asInt(map['chapter']),
      verse: _asInt(map['verse']),
      versionId: map['versionId'] as String? ?? 'RVR1960',
      text: map['text'] as String? ?? '',
    );
  }
}

class SermonCentralPassage {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int startVerse;
  final int endVerse;

  const SermonCentralPassage({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
  });

  String get label {
    final verseLabel = startVerse == endVerse
        ? '$startVerse'
        : '$startVerse-$endVerse';
    return '$bookName $chapter:$verseLabel';
  }

  Map<String, dynamic> toMap() => {
    'bookNumber': bookNumber,
    'bookName': bookName,
    'chapter': chapter,
    'startVerse': startVerse,
    'endVerse': endVerse,
  };

  factory SermonCentralPassage.fromMap(Map<String, dynamic> map) {
    return SermonCentralPassage(
      bookNumber: _asInt(map['bookNumber']),
      bookName: map['bookName'] as String? ?? '',
      chapter: _asInt(map['chapter']),
      startVerse: _asInt(map['startVerse']),
      endVerse: _asInt(map['endVerse']),
    );
  }
}

class SermonNote {
  final String id;
  final String title;
  final DateTime sermonDate;
  final String speaker;
  final String primaryVersionId;
  final String secondaryVersionId;
  final SermonCentralPassage? centralPassage;
  final String notes;
  final String takeaway;
  final List<SermonVerseReference> verses;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SermonNote({
    required this.id,
    required this.title,
    required this.sermonDate,
    required this.speaker,
    required this.primaryVersionId,
    required this.secondaryVersionId,
    required this.centralPassage,
    required this.notes,
    required this.takeaway,
    required this.verses,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SermonNote.empty({
    String? id,
    required String primaryVersionId,
    required String secondaryVersionId,
  }) {
    final now = DateTime.now();
    return SermonNote(
      id: id ?? 'sermon_${now.microsecondsSinceEpoch}',
      title: '',
      sermonDate: DateTime(now.year, now.month, now.day),
      speaker: '',
      primaryVersionId: primaryVersionId,
      secondaryVersionId: secondaryVersionId,
      centralPassage: null,
      notes: '',
      takeaway: '',
      verses: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  bool get hasContent =>
      title.trim().isNotEmpty ||
      speaker.trim().isNotEmpty ||
      notes.trim().isNotEmpty ||
      takeaway.trim().isNotEmpty ||
      centralPassage != null ||
      verses.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'title': title,
    'sermonDate': Timestamp.fromDate(sermonDate),
    'speaker': speaker,
    'primaryVersionId': primaryVersionId,
    'secondaryVersionId': secondaryVersionId,
    'centralPassage': centralPassage?.toMap(),
    'notes': notes,
    'takeaway': takeaway,
    'verses': verses.map((v) => v.toMap()).toList(),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory SermonNote.fromMap(String id, Map<String, dynamic> map) {
    return SermonNote(
      id: id,
      title: map['title'] as String? ?? '',
      sermonDate: _dateFromAny(map['sermonDate'] ?? map['sermonDateMs']),
      speaker: map['speaker'] as String? ?? '',
      primaryVersionId: map['primaryVersionId'] as String? ?? 'RVR1960',
      secondaryVersionId: map['secondaryVersionId'] as String? ?? 'NVI',
      centralPassage: map['centralPassage'] is Map
          ? SermonCentralPassage.fromMap(
              Map<String, dynamic>.from(map['centralPassage'] as Map),
            )
          : null,
      notes: map['notes'] as String? ?? '',
      takeaway: map['takeaway'] as String? ?? '',
      verses:
          (map['verses'] as List?)
              ?.whereType<Map>()
              .map(
                (v) =>
                    SermonVerseReference.fromMap(Map<String, dynamic>.from(v)),
              )
              .toList() ??
          const [],
      createdAt: _dateFromAny(map['createdAt'] ?? map['createdAtMs']),
      updatedAt: _dateFromAny(map['updatedAt'] ?? map['updatedAtMs']),
    );
  }

  SermonNote copyWith({
    String? title,
    DateTime? sermonDate,
    String? speaker,
    String? primaryVersionId,
    String? secondaryVersionId,
    SermonCentralPassage? centralPassage,
    bool clearCentralPassage = false,
    String? notes,
    String? takeaway,
    List<SermonVerseReference>? verses,
  }) {
    return SermonNote(
      id: id,
      title: title ?? this.title,
      sermonDate: sermonDate ?? this.sermonDate,
      speaker: speaker ?? this.speaker,
      primaryVersionId: primaryVersionId ?? this.primaryVersionId,
      secondaryVersionId: secondaryVersionId ?? this.secondaryVersionId,
      centralPassage: clearCentralPassage
          ? null
          : (centralPassage ?? this.centralPassage),
      notes: notes ?? this.notes,
      takeaway: takeaway ?? this.takeaway,
      verses: verses ?? this.verses,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _dateFromAny(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
