/// ═══════════════════════════════════════════════════════════════════════════
/// BATTLE PARTNER DATA - View Model para compañeros de batalla
/// Solo expone datos públicos: racha, victory hoy, inactividad
/// NUNCA: diario, gigantes, score detallado, email
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de la vinculación
enum PartnerStatus { pending, active, rejected, removed }

/// Datos visibles de un compañero
class BattlePartnerData {
  final String uid;
  final String name;
  final int streakDays;
  final bool victoryToday;
  final DateTime? lastOpenedAt;
  final DateTime addedAt;
  final PartnerStatus status;

  const BattlePartnerData({
    required this.uid,
    required this.name,
    this.streakDays = 0,
    this.victoryToday = false,
    this.lastOpenedAt,
    required this.addedAt,
    this.status = PartnerStatus.active,
  });

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

  /// Crear desde documento Firestore de battlePartners + publicProgress
  factory BattlePartnerData.fromFirestore(
    Map<String, dynamic> partnerDoc, {
    Map<String, dynamic>? progressDoc,
  }) {
    return BattlePartnerData(
      uid: partnerDoc['partnerUid'] as String? ?? '',
      name: partnerDoc['partnerName'] as String? ?? 'Compañero',
      streakDays: progressDoc?['streakDays'] as int? ?? 0,
      victoryToday: progressDoc?['victoryToday'] as bool? ?? false,
      lastOpenedAt: _toDateTime(progressDoc?['lastOpenedAt']),
      addedAt: _toDateTime(partnerDoc['addedAt']) ?? DateTime.now(),
      status: _parseStatus(partnerDoc['status'] as String?),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static PartnerStatus _parseStatus(String? value) {
    switch (value) {
      case 'pending': return PartnerStatus.pending;
      case 'active': return PartnerStatus.active;
      case 'rejected': return PartnerStatus.rejected;
      case 'removed': return PartnerStatus.removed;
      default: return PartnerStatus.pending;
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
      createdAt: BattlePartnerData._toDateTime(data['createdAt']) ?? DateTime.now(),
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

  const BattleMessageData({
    required this.id,
    required this.fromUid,
    required this.messageKey,
    required this.sentAt,
    this.read = false,
  });

  factory BattleMessageData.fromFirestore(String docId, Map<String, dynamic> data) {
    return BattleMessageData(
      id: docId,
      fromUid: data['fromUid'] as String? ?? '',
      messageKey: data['messageKey'] as String? ?? '',
      sentAt: BattlePartnerData._toDateTime(data['sentAt']) ?? DateTime.now(),
      read: data['read'] as bool? ?? false,
    );
  }
}

/// Resultado de una operación de invitación
enum InviteResultType { success, selfInvite, alreadyLinked, limitReached, notFound, error }

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
