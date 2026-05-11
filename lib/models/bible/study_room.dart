import 'package:cloud_firestore/cloud_firestore.dart';

/// Sala colaborativa de Modo Estudio.
///
/// Documento Firestore en `studyRooms/{code}` (code 6 caracteres).
class StudyRoom {
  final String code;
  final String hostUid;
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int? startVerse;
  final int? endVerse;
  final int swapIntervalMinutes;
  final DateTime createdAt;
  final DateTime lastSwapAt;
  final bool swapTimerActive;
  final DateTime? swapTimerStartedAt;
  final List<String> memberOrder; // orden de rotación
  final Map<String, StudyRoomMember> members; // uid -> member

  const StudyRoom({
    required this.code,
    required this.hostUid,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
    required this.swapIntervalMinutes,
    required this.createdAt,
    required this.lastSwapAt,
    this.swapTimerActive = true,
    this.swapTimerStartedAt,
    required this.memberOrder,
    required this.members,
  });

  StudyRoomMember? memberFor(String uid) => members[uid];
  String? versionForUid(String uid) => members[uid]?.versionId;

  /// Marca temporal del próximo swap.
  DateTime get nextSwapAt => lastSwapAt.add(Duration(minutes: swapIntervalMinutes));

  /// Segundos hasta el próximo swap (0 si ya tocó, null si el timer no inició).
  int? secondsUntilSwap(DateTime now) {
    if (!swapTimerActive) return null;
    final diff = nextSwapAt.difference(now).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  Map<String, dynamic> toMap() => {
    'code': code,
    'hostUid': hostUid,
    'bookNumber': bookNumber,
    'bookName': bookName,
    'chapter': chapter,
    if (startVerse != null) 'startVerse': startVerse,
    if (endVerse != null) 'endVerse': endVerse,
    'swapIntervalMinutes': swapIntervalMinutes,
    'createdAt': Timestamp.fromDate(createdAt),
    'lastSwapAt': Timestamp.fromDate(lastSwapAt),
    'swapTimerActive': swapTimerActive,
    if (swapTimerStartedAt != null) 'swapTimerStartedAt': Timestamp.fromDate(swapTimerStartedAt!),
    'memberOrder': memberOrder,
    'members': members.map((k, m) => MapEntry(k, m.toMap())),
  };

  factory StudyRoom.fromMap(Map<String, dynamic> map) {
    final rawMembers = map['members'];
    final members = <String, StudyRoomMember>{};
    if (rawMembers is Map) {
      rawMembers.forEach((k, v) {
        if (v is Map) {
          members[k.toString()] = StudyRoomMember.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }
    return StudyRoom(
      code: map['code'] as String,
      hostUid: map['hostUid'] as String,
      bookNumber: (map['bookNumber'] as num).toInt(),
      bookName: map['bookName'] as String? ?? '',
      chapter: (map['chapter'] as num).toInt(),
      startVerse: (map['startVerse'] as num?)?.toInt(),
      endVerse: (map['endVerse'] as num?)?.toInt(),
      swapIntervalMinutes: (map['swapIntervalMinutes'] as num?)?.toInt() ?? 15,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSwapAt: (map['lastSwapAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      swapTimerActive: map['swapTimerActive'] as bool? ?? true,
      swapTimerStartedAt: (map['swapTimerStartedAt'] as Timestamp?)?.toDate(),
      memberOrder: (map['memberOrder'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      members: members,
    );
  }
}

class StudyRoomMember {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String versionId; // RVR1960, NVI, etc.
  final DateTime joinedAt;

  const StudyRoomMember({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.versionId,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'versionId': versionId,
    'joinedAt': Timestamp.fromDate(joinedAt),
  };

  factory StudyRoomMember.fromMap(Map<String, dynamic> map) => StudyRoomMember(
    uid: map['uid'] as String,
    displayName: map['displayName'] as String? ?? 'Anónimo',
    photoUrl: map['photoUrl'] as String?,
    versionId: map['versionId'] as String? ?? 'RVR1960',
    joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

class StudyRoomAnswerSnapshot {
  final String uid;
  final String displayName;
  final String versionId;
  final Map<String, String> answers;
  final String generalNotes;
  final String hopeMessage;
  final List<int> mainVerses;
  final DateTime updatedAt;

  const StudyRoomAnswerSnapshot({
    required this.uid,
    required this.displayName,
    required this.versionId,
    required this.answers,
    required this.generalNotes,
    required this.hopeMessage,
    required this.mainVerses,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'versionId': versionId,
    'answers': answers,
    'generalNotes': generalNotes,
    'hopeMessage': hopeMessage,
    'mainVerses': mainVerses,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory StudyRoomAnswerSnapshot.fromMap(Map<String, dynamic> map) {
    final rawAnswers = map['answers'];
    final answers = <String, String>{};
    if (rawAnswers is Map) {
      rawAnswers.forEach((key, value) {
        if (value is String && value.trim().isNotEmpty) {
          answers[key.toString()] = value;
        }
      });
    }
    return StudyRoomAnswerSnapshot(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Compañero',
      versionId: map['versionId'] as String? ?? 'RVR1960',
      answers: answers,
      generalNotes: map['generalNotes'] as String? ?? '',
      hopeMessage: map['hopeMessage'] as String? ?? '',
      mainVerses:
          (map['mainVerses'] as List?)
              ?.map((value) => value is num ? value.toInt() : int.tryParse(value.toString()))
              .whereType<int>()
              .toList() ??
          const [],
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
