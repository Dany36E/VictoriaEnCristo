import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'battle_partner_service.dart';
import 'bible/bible_reading_stats_service.dart';
import 'bible/bible_user_data_service.dart';
import 'bible/chapter_note_service.dart';
import 'bible/collection_service.dart';
import 'bible/study_mode_service.dart';
import 'bible/study_room_service.dart';

/// Inicializa servicios de usuario solo cuando el módulo los necesita.
///
/// Mantiene barato el login: no abre listeners de Biblia/Compañero si el
/// usuario no entra a esas secciones durante la sesión.
class UserScopedServices {
  UserScopedServices._();
  static final UserScopedServices I = UserScopedServices._();

  Future<void>? _battleInit;
  Future<void>? _bibleInit;
  Future<void>? _studyModeInit;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> ensureBattlePartners({bool syncPublicProgress = false}) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    _battleInit ??= BattlePartnerService.I.init(uid);
    await _battleInit;

    if (syncPublicProgress) {
      unawaited(BattlePartnerService.I.syncPublicProgress());
    }
  }

  Future<void> ensureBible() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    _bibleInit ??= Future.wait<void>([
      BibleUserDataService.I.init(uid),
      ChapterNoteService.I.init(uid),
      CollectionService.I.init(uid),
      BibleReadingStatsService.I.init(uid),
    ]);
    await _bibleInit;
  }

  Future<void> ensureStudyMode() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;

    await ensureBible();
    _studyModeInit ??= StudyModeService.I.init(uid);
    await _studyModeInit;
    StudyRoomService.I.init();
  }

  void reset() {
    _battleInit = null;
    _bibleInit = null;
    _studyModeInit = null;
  }
}
