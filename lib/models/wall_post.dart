/// ═══════════════════════════════════════════════════════════════════════════
/// WALL POST MODEL - Muro de Batalla
/// Posts y comentarios anónimos moderados por gigante.
/// NUNCA contiene UID del autor — solo alias + abuseHash.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de moderación
enum WallContentStatus { pending, approved, rejected }

WallContentStatus _parseStatus(String? s) {
  switch (s) {
    case 'approved': return WallContentStatus.approved;
    case 'rejected': return WallContentStatus.rejected;
    default: return WallContentStatus.pending;
  }
}

DateTime? _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// Razones de reporte predefinidas
enum ReportReason { offensive, spam, toxic, offTopic, other }

extension ReportReasonX on ReportReason {
  String get id {
    switch (this) {
      case ReportReason.offensive: return 'offensive';
      case ReportReason.spam: return 'spam';
      case ReportReason.toxic: return 'toxic';
      case ReportReason.offTopic: return 'off_topic';
      case ReportReason.other: return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case ReportReason.offensive: return 'Contenido ofensivo';
      case ReportReason.spam: return 'Spam';
      case ReportReason.toxic: return 'Lenguaje tóxico';
      case ReportReason.offTopic: return 'Fuera de tema';
      case ReportReason.other: return 'Otro';
    }
  }
}

/// Razones de rechazo predefinidas (para admin)
const List<String> kRejectionReasons = [
  'Contenido negativo o dañino',
  'Spam',
  'No relacionado con el propósito',
  'Lenguaje inapropiado',
  'Otro',
];

// ═══════════════════════════════════════════════════════════════════════════
// WALL POST
// ═══════════════════════════════════════════════════════════════════════════

class WallPost {
  final String id;
  final String alias;
  final String giantId;
  final String body;
  final WallContentStatus status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final int commentCount;
  final int reportCount;
  final String? abuseHash; // Solo visible para admin queries

  const WallPost({
    required this.id,
    required this.alias,
    required this.giantId,
    required this.body,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.commentCount = 0,
    this.reportCount = 0,
    this.abuseHash,
  });

  factory WallPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WallPost(
      id: doc.id,
      alias: data['alias'] as String? ?? 'Guerrero',
      giantId: data['giantId'] as String? ?? 'general',
      body: data['body'] as String? ?? '',
      status: _parseStatus(data['status'] as String?),
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      approvedAt: _toDateTime(data['approvedAt']),
      approvedBy: data['approvedBy'] as String?,
      commentCount: data['commentCount'] as int? ?? 0,
      reportCount: data['reportCount'] as int? ?? 0,
      abuseHash: data['abuseHash'] as String?,
    );
  }

  bool get isPending => status == WallContentStatus.pending;
  bool get isApproved => status == WallContentStatus.approved;
  bool get isRejected => status == WallContentStatus.rejected;
}

// ═══════════════════════════════════════════════════════════════════════════
// WALL COMMENT
// ═══════════════════════════════════════════════════════════════════════════

class WallComment {
  final String id;
  final String alias;
  final String body;
  final WallContentStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? abuseHash;

  const WallComment({
    required this.id,
    required this.alias,
    required this.body,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.abuseHash,
  });

  factory WallComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WallComment(
      id: doc.id,
      alias: data['alias'] as String? ?? 'Guerrero',
      body: data['body'] as String? ?? '',
      status: _parseStatus(data['status'] as String?),
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      approvedAt: _toDateTime(data['approvedAt']),
      abuseHash: data['abuseHash'] as String?,
    );
  }

  bool get isPending => status == WallContentStatus.pending;
  bool get isApproved => status == WallContentStatus.approved;
}

// ═══════════════════════════════════════════════════════════════════════════
// RESULT TYPE
// ═══════════════════════════════════════════════════════════════════════════

class WallPostResult {
  final bool success;
  final String message;
  final String? postId;
  final String? commentId;

  const WallPostResult({
    required this.success,
    required this.message,
    this.postId,
    this.commentId,
  });
}
