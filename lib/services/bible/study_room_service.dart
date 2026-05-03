import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/bible/study_room.dart';
import '../auth_service.dart' show kCloudFunctionRegion;

/// Cliente para salas colaborativas de Modo Estudio.
///
/// - `createRoom` / `joinRoom` / `leaveRoom`: callable Cloud Functions.
/// - `currentRoomNotifier`: emite el estado en vivo (snapshot listener) de
///   la sala activa, incluyendo rotación de traducciones.
class StudyRoomService {
  StudyRoomService._();
  static final StudyRoomService I = StudyRoomService._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: kCloudFunctionRegion);
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;

  final ValueNotifier<StudyRoom?> currentRoomNotifier =
      ValueNotifier<StudyRoom?>(null);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _signedIn => _uid != null;

  /// Llamar al iniciar sesión / al iniciar la app si ya hay sesión.
  void init() {
    // No hay rehidratación automática (no persistimos código actual);
    // el usuario debe entrar a la pantalla de Modo Estudio para reconectarse.
  }

  /// Llamar al cerrar sesión.
  Future<void> stop() async {
    await _roomSub?.cancel();
    _roomSub = null;
    currentRoomNotifier.value = null;
  }

  /// Crea una sala. Devuelve la sala creada.
  Future<StudyRoom> createRoom({
    required int bookNumber,
    required String bookName,
    required int chapter,
    required String versionId,
    int? startVerse,
    int? endVerse,
    int swapIntervalMinutes = 15,
  }) async {
    if (!_signedIn) {
      throw StateError('Inicia sesión para crear una sala.');
    }
    final user = FirebaseAuth.instance.currentUser!;
    final result = await _functions.httpsCallable('createStudyRoom').call({
      'bookNumber': bookNumber,
      'bookName': bookName,
      'chapter': chapter,
      'versionId': versionId,
      'startVerse': startVerse,
      'endVerse': endVerse,
      'swapIntervalMinutes': swapIntervalMinutes,
      'displayName': user.displayName ?? 'Hermano(a)',
      'photoUrl': user.photoURL,
    });
    final code = result.data['code'] as String;
    return _bindRoom(code);
  }

  /// Une al usuario a una sala existente.
  Future<StudyRoom> joinRoom({
    required String code,
    required String versionId,
  }) async {
    if (!_signedIn) {
      throw StateError('Inicia sesión para unirte a una sala.');
    }
    final user = FirebaseAuth.instance.currentUser!;
    await _functions.httpsCallable('joinStudyRoom').call({
      'code': code.toUpperCase(),
      'versionId': versionId,
      'displayName': user.displayName ?? 'Hermano(a)',
      'photoUrl': user.photoURL,
    });
    return _bindRoom(code.toUpperCase());
  }

  /// Sale de la sala activa.
  Future<void> leaveRoom() async {
    final code = currentRoomNotifier.value?.code;
    if (code == null) return;
    try {
      await _functions.httpsCallable('leaveStudyRoom').call({'code': code});
    } finally {
      await _roomSub?.cancel();
      _roomSub = null;
      currentRoomNotifier.value = null;
    }
  }

  /// Rota traducciones manualmente (host o cualquier miembro).
  Future<void> rotateNow() async {
    final code = currentRoomNotifier.value?.code;
    if (code == null) return;
    await _functions.httpsCallable('rotateStudyVersions').call({
      'code': code,
      'force': true,
    });
  }

  Future<StudyRoom> _bindRoom(String code) async {
    await _roomSub?.cancel();
    final ref = _db.collection('studyRooms').doc(code);
    final completer = Completer<StudyRoom>();
    _roomSub = ref.snapshots().listen((snap) {
      if (!snap.exists) {
        currentRoomNotifier.value = null;
        if (!completer.isCompleted) {
          completer.completeError(
              StateError('La sala fue cerrada o no existe.'));
        }
        return;
      }
      final data = snap.data()!;
      data['code'] = code;
      final room = StudyRoom.fromMap(data);
      currentRoomNotifier.value = room;
      if (!completer.isCompleted) completer.complete(room);
    }, onError: (e) {
      debugPrint('[STUDY-ROOM] listen error: $e');
      if (!completer.isCompleted) completer.completeError(e);
    });
    return completer.future;
  }
}
