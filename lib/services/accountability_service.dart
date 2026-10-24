/// ═══════════════════════════════════════════════════════════════════════════
/// RENDICIÓN DE CUENTAS — qué recibe cada compañero (siempre opcional).
///
/// El usuario elige, compañero por compañero:
/// - Avisos del Escudo: si el Escudo de Pureza se apaga o deja de dar señal
///   por más de un día, el compañero recibe un aviso breve (sin sitios, sin
///   horas exactas, sin detalles).
/// - Resumen semanal: el domingo por la tarde (hora del usuario) recibe el
///   texto que se muestra en "Lo que verá tu compañero", solo con lo que el
///   usuario decidió compartir.
///
/// Se guarda en `accountability/{uid}` (solo el dueño lo lee o escribe; las
/// Cloud Functions lo leen para enviar avisos y resúmenes).
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../utils/resumen_semanal.dart';
import 'battle_partner_service.dart';
import 'shield_status_service.dart';

/// Máximo de compañeros (igual que kMaxBattlePartners).
const int _maxCompaneros = 5;

/// Ajustes de rendición de cuentas del usuario.
@immutable
class AjustesRendicion {
  /// Compañeros que reciben avisos del Escudo.
  final Set<String> avisosEscudo;

  /// Compañeros que reciben el resumen semanal.
  final Set<String> resumenSemanal;

  /// Qué incluye el resumen semanal.
  final CompartirResumen compartir;

  const AjustesRendicion({
    this.avisosEscudo = const {},
    this.resumenSemanal = const {},
    this.compartir = const CompartirResumen(),
  });

  AjustesRendicion copyWith({
    Set<String>? avisosEscudo,
    Set<String>? resumenSemanal,
    CompartirResumen? compartir,
  }) => AjustesRendicion(
    avisosEscudo: avisosEscudo ?? this.avisosEscudo,
    resumenSemanal: resumenSemanal ?? this.resumenSemanal,
    compartir: compartir ?? this.compartir,
  );

  /// Quita a un compañero de todas las listas.
  AjustesRendicion sin(String partnerUid) => copyWith(
    avisosEscudo: {...avisosEscudo}..remove(partnerUid),
    resumenSemanal: {...resumenSemanal}..remove(partnerUid),
  );

  Map<String, dynamic> toFirestore({String? zonaHoraria}) => {
    'shieldAlertPartners': avisosEscudo.take(_maxCompaneros).toList(),
    'weeklyReportPartners': resumenSemanal.take(_maxCompaneros).toList(),
    'weeklyEnabled': resumenSemanal.isNotEmpty,
    'share': compartir.toMap(),
    if (zonaHoraria != null && zonaHoraria.isNotEmpty) 'timezone': zonaHoraria,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory AjustesRendicion.fromFirestore(Map<String, dynamic>? data) {
    Set<String> lista(String campo) =>
        (data?[campo] as List?)?.whereType<String>().toSet() ?? <String>{};
    final share = data?['share'];
    return AjustesRendicion(
      avisosEscudo: lista('shieldAlertPartners'),
      resumenSemanal: lista('weeklyReportPartners'),
      compartir: CompartirResumen.fromMap(
        share is Map ? Map<String, dynamic>.from(share) : null,
      ),
    );
  }
}

class AccountabilityService {
  AccountabilityService._();
  static final AccountabilityService I = AccountabilityService._();

  final ValueNotifier<AjustesRendicion> ajustes = ValueNotifier(
    const AjustesRendicion(),
  );

  String? _uidCargado;

  /// `true` si los ajustes del usuario actual se leyeron (o guardaron) bien.
  /// Mientras sea `false` no se debe publicar "sin avisos" al servidor.
  bool get cargadoParaUsuarioActual => _uidCargado != null && _uidCargado == _uid;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection('accountability').doc(uid);

  /// Lee los ajustes del usuario actual (una vez por sesión salvo [forzar]).
  Future<void> cargar({bool forzar = false}) async {
    final uid = _uid;
    if (uid == null) return;
    if (!forzar && _uidCargado == uid) return;
    if (_uidCargado != uid) {
      // Otra cuenta: no arrastrar los ajustes de la anterior.
      _uidCargado = null;
      ajustes.value = const AjustesRendicion();
    }
    try {
      final snap = await _ref(uid).get();
      ajustes.value = AjustesRendicion.fromFirestore(snap.data());
      _uidCargado = uid;
    } catch (e) {
      debugPrint('🛡️ [RENDICION] No se pudieron leer los ajustes: $e');
    }
  }

  /// Guarda los ajustes y actualiza lo que ven los compañeros.
  Future<bool> guardar(AjustesRendicion nuevos) async {
    final uid = _uid;
    if (uid == null) return false;
    final anterior = ajustes.value;
    ajustes.value = nuevos;
    try {
      final zona = await _zonaHoraria();
      await _ref(
        uid,
      ).set(nuevos.toFirestore(zonaHoraria: zona), SetOptions(merge: true));
      _uidCargado = uid;
    } catch (e) {
      debugPrint('🛡️ [RENDICION] No se pudieron guardar los ajustes: $e');
      ajustes.value = anterior;
      return false;
    }
    // El estado del Escudo marca si hay a quién avisar, y el vínculo de cada
    // compañero refleja si le compartes el Escudo.
    unawaited(ShieldStatusService.I.reportar());
    unawaited(BattlePartnerService.I.syncPublicProgress());
    return true;
  }

  /// Al liberar a un compañero: se quita de las listas. La Cloud Function
  /// `removeBattlePartner` también lo hace en el servidor; esto cubre el
  /// respaldo sin función.
  void quitarCompaneroLocal(String partnerUid) {
    final actuales = ajustes.value;
    if (!actuales.avisosEscudo.contains(partnerUid) &&
        !actuales.resumenSemanal.contains(partnerUid)) {
      return;
    }
    final nuevos = actuales.sin(partnerUid);
    ajustes.value = nuevos;
    final uid = _uid;
    if (uid == null) return;
    unawaited(
      _ref(uid)
          .set({
            'shieldAlertPartners': FieldValue.arrayRemove([partnerUid]),
            'weeklyReportPartners': FieldValue.arrayRemove([partnerUid]),
            'weeklyEnabled': nuevos.resumenSemanal.isNotEmpty,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .catchError((Object e) {
            debugPrint('🛡️ [RENDICION] No se pudo quitar al compañero: $e');
          }),
    );
  }

  Future<String?> _zonaHoraria() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final id = info.identifier;
      return id.length <= 64 ? id : null;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    ajustes.value = const AjustesRendicion();
    _uidCargado = null;
  }
}
