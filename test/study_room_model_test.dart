import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_quitar/models/bible/study_room.dart';

void main() {
  group('StudyRoom', () {
    final now = DateTime.utc(2025, 1, 1, 12);
    final room = StudyRoom(
      code: 'ABC123',
      hostUid: 'host',
      bookNumber: 43,
      bookName: 'Juan',
      chapter: 4,
      startVerse: 44,
      endVerse: 51,
      swapIntervalMinutes: 15,
      createdAt: now,
      lastSwapAt: now,
      memberOrder: const ['host', 'friend'],
      members: {
        'host': StudyRoomMember(
          uid: 'host',
          displayName: 'Host',
          photoUrl: null,
          versionId: 'RVR1960',
          joinedAt: now,
        ),
        'friend': StudyRoomMember(
          uid: 'friend',
          displayName: 'Amigo',
          photoUrl: null,
          versionId: 'NVI',
          joinedAt: now,
        ),
      },
    );

    test('serialización roundtrip preserva los campos', () {
      final map = room.toMap();
      expect(map['code'], 'ABC123');
      expect(map['memberOrder'], ['host', 'friend']);
      final round = StudyRoom.fromMap(Map<String, dynamic>.from(map));
      expect(round.hostUid, 'host');
      expect(round.startVerse, 44);
      expect(round.endVerse, 51);
      expect(round.versionForUid('host'), 'RVR1960');
      expect(round.versionForUid('friend'), 'NVI');
      expect(round.versionForUid('ghost'), isNull);
    });

    test('nextSwapAt y secondsUntilSwap', () {
      expect(room.nextSwapAt, room.lastSwapAt.add(const Duration(minutes: 15)));
      // Si "now" está pasado el próximo swap, devuelve 0.
      final past = DateTime.utc(2025, 1, 1, 13);
      expect(room.secondsUntilSwap(past), 0);
      // Si está antes, devuelve segundos > 0.
      final before = DateTime.utc(2025, 1, 1, 12, 5);
      expect(room.secondsUntilSwap(before), 600);
    });

    test('secondsUntilSwap devuelve null si el timer no inició', () {
      final inactive = StudyRoom.fromMap({
        'code': 'WAIT22',
        'hostUid': 'host',
        'bookNumber': 1,
        'chapter': 1,
        'swapTimerActive': false,
        'createdAt': Timestamp.fromDate(now),
        'lastSwapAt': Timestamp.fromDate(now),
      });
      expect(inactive.swapTimerActive, isFalse);
      expect(inactive.secondsUntilSwap(now), isNull);
    });

    test('fromMap tolera mapas mínimos', () {
      final round = StudyRoom.fromMap({
        'code': 'XYZ987',
        'hostUid': 'u1',
        'bookNumber': 1,
        'chapter': 1,
        'createdAt': Timestamp.fromDate(DateTime.utc(2025)),
        'lastSwapAt': Timestamp.fromDate(DateTime.utc(2025)),
      });
      expect(round.swapIntervalMinutes, 15);
      expect(round.memberOrder, isEmpty);
      expect(round.members, isEmpty);
    });

    test('StudyRoomAnswerSnapshot roundtrip conserva respuestas por usuario', () {
      final snapshot = StudyRoomAnswerSnapshot(
        uid: 'friend',
        displayName: 'Amigo',
        versionId: 'TLA',
        answers: const {'about_god': 'Dios crea con propósito.'},
        generalNotes: 'Nota final',
        hopeMessage: 'Hay esperanza.',
        mainVerses: const [1, 3],
        updatedAt: now,
      );

      final round = StudyRoomAnswerSnapshot.fromMap(snapshot.toMap());
      expect(round.uid, 'friend');
      expect(round.displayName, 'Amigo');
      expect(round.versionId, 'TLA');
      expect(round.answers['about_god'], 'Dios crea con propósito.');
      expect(round.generalNotes, 'Nota final');
      expect(round.hopeMessage, 'Hay esperanza.');
      expect(round.mainVerses, [1, 3]);
    });
  });
}
