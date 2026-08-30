import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Estado del candado remoto del protegido (espejo sin secretos).
class GuardianLockStatus {
  final bool active;
  final bool pending;
  final String? guardianUid;
  final String? guardianName;
  const GuardianLockStatus({
    required this.active,
    required this.pending,
    this.guardianUid,
    this.guardianName,
  });
}

class GuardianRequest {
  final String protegeUid;
  final String protegeName;
  const GuardianRequest({required this.protegeUid, required this.protegeName});
}

class GuardianOfEntry {
  final String protegeUid;
  final String protegeName;
  final bool active;
  const GuardianOfEntry({
    required this.protegeUid,
    required this.protegeName,
    required this.active,
  });
}

/// Resultado de verificar/quitar con PIN.
class GuardianPinResult {
  final bool ok;
  final int? lockedUntilMs;
  const GuardianPinResult(this.ok, {this.lockedUntilMs});
  bool get isLockedOut => lockedUntilMs != null && !ok;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// CANDADO DEL GUARDIÁN REMOTO (cliente)
///
/// Puente con las Cloud Functions. El PIN se verifica SIEMPRE en el servidor;
/// aquí solo escuchamos espejos de estado (sin secretos) y llamamos callables.
/// ═══════════════════════════════════════════════════════════════════════════
class RemoteGuardianService {
  RemoteGuardianService._();
  static final RemoteGuardianService I = RemoteGuardianService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  StreamSubscription? _lockSub;
  StreamSubscription? _requestsSub;
  StreamSubscription? _guardianOfSub;
  String? _startedUid;

  /// Estado del candado del propio usuario (como protegido).
  final ValueNotifier<GuardianLockStatus?> myLock =
      ValueNotifier<GuardianLockStatus?>(null);

  /// Solicitudes entrantes (como guardián).
  final ValueNotifier<List<GuardianRequest>> incomingRequests =
      ValueNotifier<List<GuardianRequest>>([]);

  /// Personas a las que protejo (como guardián).
  final ValueNotifier<List<GuardianOfEntry>> guardianOf =
      ValueNotifier<List<GuardianOfEntry>>([]);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// UID del usuario actual (para pasarlo como protegeUid al quitar candado).
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  bool get isSupported {
    if (kIsWeb) return false;
    try {
      // cloud_functions funciona en móvil; en escritorio no lo usamos.
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Arranca los listeners si hay sesión y aún no están activos.
  void ensureStarted() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    if (_startedUid == uid) return;
    stop();
    _startedUid = uid;

    _lockSub = _db
        .collection('users')
        .doc(uid)
        .collection('security')
        .doc('guardianLock')
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data == null || data['active'] == null && data['pending'] == null) {
        myLock.value = null;
        return;
      }
      myLock.value = GuardianLockStatus(
        active: data['active'] == true,
        pending: data['pending'] == true,
        guardianUid: data['guardianUid'] as String?,
        guardianName: data['guardianName'] as String?,
      );
    }, onError: (e) => debugPrint('[RemoteGuardian] lock stream error: $e'));

    _requestsSub = _db
        .collection('users')
        .doc(uid)
        .collection('guardianRequests')
        .snapshots()
        .listen((snap) {
      incomingRequests.value = snap.docs
          .map((d) => GuardianRequest(
                protegeUid: (d.data()['protegeUid'] as String?) ?? d.id,
                protegeName:
                    (d.data()['protegeName'] as String?) ?? 'Un compañero',
              ))
          .toList();
    }, onError: (e) => debugPrint('[RemoteGuardian] requests error: $e'));

    _guardianOfSub = _db
        .collection('users')
        .doc(uid)
        .collection('guardianOf')
        .snapshots()
        .listen((snap) {
      guardianOf.value = snap.docs
          .map((d) => GuardianOfEntry(
                protegeUid: (d.data()['protegeUid'] as String?) ?? d.id,
                protegeName:
                    (d.data()['protegeName'] as String?) ?? 'Un compañero',
                active: d.data()['active'] == true,
              ))
          .toList();
    }, onError: (e) => debugPrint('[RemoteGuardian] guardianOf error: $e'));
  }

  void stop() {
    _lockSub?.cancel();
    _requestsSub?.cancel();
    _guardianOfSub?.cancel();
    _lockSub = null;
    _requestsSub = null;
    _guardianOfSub = null;
    _startedUid = null;
  }

  // ── Callables ────────────────────────────────────────────────────────────

  /// (Protegido) Pide a un compañero que sea su guardián.
  Future<bool> requestGuardian(String guardianUid) async {
    try {
      await _functions
          .httpsCallable('requestGuardianLock')
          .call({'guardianUid': guardianUid});
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[RemoteGuardian] request error: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[RemoteGuardian] request error: $e');
      return false;
    }
  }

  /// (Guardián) Define/cambia el PIN del protegido.
  Future<bool> setPin({required String protegeUid, required String pin}) async {
    try {
      await _functions
          .httpsCallable('setGuardianPin')
          .call({'protegeUid': protegeUid, 'pin': pin});
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[RemoteGuardian] setPin error: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[RemoteGuardian] setPin error: $e');
      return false;
    }
  }

  /// (Protegido) Verifica el PIN para desbloquear el escudo.
  Future<GuardianPinResult> verify(String pin) async {
    try {
      final res =
          await _functions.httpsCallable('verifyGuardianPin').call({'pin': pin});
      final data = Map<String, dynamic>.from(res.data as Map);
      return GuardianPinResult(
        data['ok'] == true,
        lockedUntilMs: (data['lockedUntil'] as num?)?.toInt(),
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[RemoteGuardian] verify error: ${e.code} ${e.message}');
      return const GuardianPinResult(false);
    } catch (e) {
      debugPrint('[RemoteGuardian] verify error: $e');
      return const GuardianPinResult(false);
    }
  }

  /// Quita el candado. El guardián no necesita PIN; el protegido sí.
  Future<GuardianPinResult> remove({
    required String protegeUid,
    String? pin,
  }) async {
    try {
      final args = <String, dynamic>{'protegeUid': protegeUid};
      if (pin != null) args['pin'] = pin;
      final res =
          await _functions.httpsCallable('removeGuardianPin').call(args);
      final data = Map<String, dynamic>.from(res.data as Map);
      return GuardianPinResult(
        data['ok'] == true,
        lockedUntilMs: (data['lockedUntil'] as num?)?.toInt(),
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[RemoteGuardian] remove error: ${e.code} ${e.message}');
      return const GuardianPinResult(false);
    } catch (e) {
      debugPrint('[RemoteGuardian] remove error: $e');
      return const GuardianPinResult(false);
    }
  }
}
