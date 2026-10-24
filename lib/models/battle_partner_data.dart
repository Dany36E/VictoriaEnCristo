/// ═══════════════════════════════════════════════════════════════════════════
/// BATTLE PARTNER DATA - View Model para compañeros de batalla
/// Solo expone datos públicos: racha, victory hoy, inactividad
/// NUNCA: diario, gigantes, score detallado, email
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de la vinculación
enum PartnerStatus { pending, active, rejected, removed }

/// Cómo registró su día el compañero (solo si el dato es de SU hoy).
enum EstadoHoyCompanero { victoria, gracia, sinRegistro }

/// Clave "AAAA-MM-DD" de una fecha (solo año, mes y día).
String claveFecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Datos visibles de un compañero
class BattlePartnerData {
  final String uid;
  final String name;
  final int streakDays;
  final bool victoryToday;
  final DateTime? lastOpenedAt;
  final DateTime addedAt;
  final PartnerStatus status;

  /// 'victory' | 'grace' | 'none' publicado por el compañero para [dayKey].
  final String? dayState;

  /// Fecha local ("AAAA-MM-DD") del compañero a la que se refiere [dayState].
  final String? dayKey;

  /// Desfase UTC del compañero en minutos cuando publicó (para saber cuál es
  /// "su hoy" aunque viva en otra zona horaria).
  final int? utcOffsetMin;

  /// Última vez que el compañero publicó su progreso.
  final DateTime? progressUpdatedAt;

  /// El compañero decidió avisarte si apaga su Escudo de Pureza.
  final bool shieldShared;

  /// Estado del Escudo del compañero (solo si [shieldShared]).
  final bool? shieldOn;

  const BattlePartnerData({
    required this.uid,
    required this.name,
    this.streakDays = 0,
    this.victoryToday = false,
    this.lastOpenedAt,
    required this.addedAt,
    this.status = PartnerStatus.active,
    this.dayState,
    this.dayKey,
    this.utcOffsetMin,
    this.progressUpdatedAt,
    this.shieldShared = false,
    this.shieldOn,
  });

  /// Estado del día del compañero, válido solo para SU fecha de hoy.
  ///
  /// Un dato de ayer no se muestra como "hoy": si [dayKey] no coincide con la
  /// fecha actual del compañero, se considera sin registro. Los documentos
  /// antiguos (sin [dayKey]) solo cuentan si se publicaron hoy.
  EstadoHoyCompanero estadoHoy({DateTime? ahora}) {
    final instante = (ahora ?? DateTime.now()).toUtc();
    final key = dayKey;
    if (key != null && dayState != null) {
      final offset = utcOffsetMin ?? DateTime.now().timeZoneOffset.inMinutes;
      final hoyDelCompanero = claveFecha(
        instante.add(Duration(minutes: offset)),
      );
      if (key != hoyDelCompanero) return EstadoHoyCompanero.sinRegistro;
      switch (dayState) {
        case 'victory':
          return EstadoHoyCompanero.victoria;
        case 'grace':
          return EstadoHoyCompanero.gracia;
        default:
          return EstadoHoyCompanero.sinRegistro;
      }
    }
    // Formato anterior: solo `victoryToday`, sin fecha. Lo aceptamos si se
    // publicó hoy (hora local de quien mira).
    final publicado = progressUpdatedAt;
    if (victoryToday &&
        publicado != null &&
        claveFecha(publicado.toLocal()) == claveFecha(instante.toLocal())) {
      return EstadoHoyCompanero.victoria;
    }
    return EstadoHoyCompanero.sinRegistro;
  }

  /// ¿Inactivo? (> 48h sin abrir la app)
  bool get isInactive {
    if (lastOpenedAt == null) return true;
    return DateTime.now().difference(lastOpenedAt!).inHours > 48;
  }

  /// Días de inactividad
  int get inactiveDays {
    if (lastOpenedAt == null) return 0;
    return DateTime.now().difference(lastOpenedAt!).inDays;
  }

  /// Crear desde documento Firestore de battlePartners.
  ///
  /// Los campos de progreso están denormalizados en el documento del vínculo
  /// para evitar leer /publicProgress/latest por cada compañero en cada sesión.
  factory BattlePartnerData.fromFirestore(
    Map<String, dynamic> partnerDoc, {
    Map<String, dynamic>? progressDoc,
  }) {
    return BattlePartnerData(
      uid: partnerDoc['partnerUid'] as String? ?? '',
      name: partnerDoc['partnerName'] as String? ?? 'Compañero',
      streakDays:
          partnerDoc['streakDays'] as int? ??
          progressDoc?['streakDays'] as int? ??
          0,
      victoryToday:
          partnerDoc['victoryToday'] as bool? ??
          progressDoc?['victoryToday'] as bool? ??
          false,
      lastOpenedAt: _toDateTime(
        partnerDoc['lastOpenedAt'] ?? progressDoc?['lastOpenedAt'],
      ),
      addedAt: _toDateTime(partnerDoc['addedAt']) ?? DateTime.now(),
      status: _parseStatus(partnerDoc['status'] as String?),
      dayState: partnerDoc['dayState'] as String?,
      dayKey: partnerDoc['dayKey'] as String?,
      utcOffsetMin: (partnerDoc['utcOffsetMin'] as num?)?.toInt(),
      progressUpdatedAt: _toDateTime(partnerDoc['progressUpdatedAt']),
      shieldShared: partnerDoc['shieldShared'] as bool? ?? false,
      shieldOn: partnerDoc['shieldOn'] as bool?,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static PartnerStatus _parseStatus(String? value) {
    switch (value) {
      case 'pending':
        return PartnerStatus.pending;
      case 'active':
        return PartnerStatus.active;
      case 'rejected':
        return PartnerStatus.rejected;
      case 'removed':
        return PartnerStatus.removed;
      default:
        return PartnerStatus.pending;
    }
  }
}

/// Invitación entrante de un compañero
class PartnerInvite {
  final String inviteId;
  final String fromUid;
  final String fromName;
  final String inviteCode;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;

  const PartnerInvite({
    required this.inviteId,
    required this.fromUid,
    required this.fromName,
    required this.inviteCode,
    this.status = 'pending',
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  factory PartnerInvite.fromFirestore(String docId, Map<String, dynamic> data) {
    return PartnerInvite(
      inviteId: docId,
      fromUid: data['fromUid'] as String? ?? '',
      fromName: data['fromName'] as String? ?? 'Desconocido',
      inviteCode: data['inviteCode'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt:
          BattlePartnerData._toDateTime(data['createdAt']) ?? DateTime.now(),
    );
  }
}

/// Mensaje recibido de un compañero
class BattleMessageData {
  final String id;
  final String fromUid;
  final String messageKey;
  final DateTime sentAt;
  final bool read;

  /// Texto que guardó el servidor (avisos del Escudo, resumen semanal…).
  final String? text;

  /// Nombre público de quien envía (o del compañero del aviso).
  final String? fromName;

  const BattleMessageData({
    required this.id,
    required this.fromUid,
    required this.messageKey,
    required this.sentAt,
    this.read = false,
    this.text,
    this.fromName,
  });

  factory BattleMessageData.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return BattleMessageData(
      id: docId,
      fromUid: data['fromUid'] as String? ?? '',
      messageKey: data['messageKey'] as String? ?? '',
      sentAt: BattlePartnerData._toDateTime(data['sentAt']) ?? DateTime.now(),
      read: data['read'] as bool? ?? false,
      text: data['text'] as String?,
      fromName: data['fromName'] as String?,
    );
  }
}

/// Resultado de una operación de invitación
enum InviteResultType {
  success,
  selfInvite,
  alreadyLinked,
  limitReached,
  notFound,
  targetPaused,
  error,
}

class InviteResult {
  final InviteResultType type;
  final String? targetName;
  final String? targetUid;
  final String? errorMessage;

  const InviteResult({
    required this.type,
    this.targetName,
    this.targetUid,
    this.errorMessage,
  });

  bool get isSuccess => type == InviteResultType.success;
}
