import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/bible/study_room.dart';
import '../auth_service.dart' show kCloudFunctionRegion;
import '../../utils/platform_capabilities.dart';

/// Cliente para salas colaborativas de Modo Estudio.
///
/// - `createRoom` / `joinRoom` / `leaveRoom`: callable Cloud Functions.
/// - `currentRoomNotifier`: emite el estado en vivo (snapshot listener) de
///   la sala activa, incluyendo rotación de traducciones.
class StudyRoomService {
  StudyRoomService._();
  static final StudyRoomService I = StudyRoomService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: kCloudFunctionRegion);
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;

  final ValueNotifier<StudyRoom?> currentRoomNotifier = ValueNotifier<StudyRoom?>(null);

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
    final result = await _callFunction('createStudyRoom', {
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
    final code = result['code'] as String;
    return _bindRoom(code);
  }

  /// Une al usuario a una sala existente.
  Future<StudyRoom> joinRoom({required String code, required String versionId}) async {
    if (!_signedIn) {
      throw StateError('Inicia sesión para unirte a una sala.');
    }
    final user = FirebaseAuth.instance.currentUser!;
    await _callFunction('joinStudyRoom', {
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
      await _callFunction('leaveStudyRoom', {'code': code});
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
    await _callFunction('rotateStudyVersions', {'code': code, 'force': true});
  }

  Future<Map<String, dynamic>> _callFunction(String name, Map<String, dynamic> data) async {
    if (PlatformCapabilities.supportsCloudFunctionsPlugin) {
      final result = await _functions.httpsCallable(name).call(data);
      return _asStringMap(result.data);
    }
    return _callFunctionOverHttp(name, data);
  }

  Future<Map<String, dynamic>> _callFunctionOverHttp(String name, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión para usar salas de estudio.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('No se pudo obtener la sesión de Firebase.');
    }

    final projectId = Firebase.app().options.projectId;
    final uri = Uri.https('$kCloudFunctionRegion-$projectId.cloudfunctions.net', '/$name');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 30));

      final body = _decodeJsonObject(response.body);
      final error = body['error'];
      if (error is Map) {
        throw StudyRoomFunctionException(
          _callableErrorCode(error),
          _callableErrorMessage(error),
          details: error['details'],
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StudyRoomFunctionException(
          'http-${response.statusCode}',
          'Firebase respondió con error ${response.statusCode}.',
          details: response.body,
        );
      }
      return _asStringMap(body['result']);
    } on StudyRoomFunctionException {
      rethrow;
    } catch (e) {
      throw StudyRoomFunctionException(
        'network',
        'No se pudo conectar con Firebase Functions. Revisa internet e intenta de nuevo.',
        details: e,
      );
    }
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('La respuesta de Firebase no es un objeto JSON.');
  }

  Map<String, dynamic> _asStringMap(Object? data) {
    if (data == null) return <String, dynamic>{};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{'result': data};
  }

  String _callableErrorCode(Map<dynamic, dynamic> error) {
    final rawCode = error['status'] ?? error['code'] ?? 'unknown';
    return rawCode.toString().toLowerCase().replaceAll('_', '-');
  }

  String _callableErrorMessage(Map<dynamic, dynamic> error) {
    final rawMessage = error['message'];
    if (rawMessage is String && rawMessage.trim().isNotEmpty) {
      return rawMessage;
    }
    return 'No se pudo completar la operación con Firebase.';
  }

  Future<StudyRoom> _bindRoom(String code) async {
    await _roomSub?.cancel();
    final ref = _db.collection('studyRooms').doc(code);
    final completer = Completer<StudyRoom>();
    _roomSub = ref.snapshots().listen(
      (snap) {
        if (!snap.exists) {
          currentRoomNotifier.value = null;
          if (!completer.isCompleted) {
            completer.completeError(StateError('La sala fue cerrada o no existe.'));
          }
          return;
        }
        final data = snap.data()!;
        data['code'] = code;
        final room = StudyRoom.fromMap(data);
        currentRoomNotifier.value = room;
        if (!completer.isCompleted) completer.complete(room);
      },
      onError: (e) {
        debugPrint('[STUDY-ROOM] listen error: $e');
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
    return completer.future;
  }
}

class StudyRoomFunctionException implements Exception {
  const StudyRoomFunctionException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => message;
}
