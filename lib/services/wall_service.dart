/// ═══════════════════════════════════════════════════════════════════════════
/// WALL SERVICE - Muro de Batalla
/// Servicio singleton para feed anónimo moderado.
/// Todas las escrituras pasan por Cloud Functions (anonimato total).
/// Lecturas directas a Firestore con filtros.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/wall_post.dart';
import 'auth_service.dart'; // kCloudFunctionRegion

/// Cantidad de posts por página
const int kWallPageSize = 20;

class WallService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  static final WallService _instance = WallService._internal();
  factory WallService() => _instance;
  WallService._internal();
  static WallService get I => _instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // REFS
  // ═══════════════════════════════════════════════════════════════════════════
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: kCloudFunctionRegion);

  CollectionReference get _postsRef => _db.collection('wallPosts');

  HttpsCallable _callable(String name) => _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // CREAR POST (vía Cloud Function)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Envía un nuevo post al muro. Retorna resultado con mensaje.
  /// El CF genera alias, abuseHash, y lo marca como pendiente.
  Future<WallPostResult> submitPost({
    required String giantId,
    required String body,
  }) async {
    try {
      final result = await _callable('createWallPost').call<Map<String, dynamic>>({
        'giantId': giantId,
        'body': body.trim(),
      });
      final data = result.data;
      return WallPostResult(
        success: data['success'] == true,
        message: data['message'] as String? ?? '',
        postId: data['postId'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [WALL] submitPost error: ${e.code} - ${e.message}');
      return WallPostResult(
        success: false,
        message: _mapFunctionError(e),
      );
    } catch (e) {
      debugPrint('❌ [WALL] submitPost unexpected: $e');
      return const WallPostResult(
        success: false,
        message: 'Error inesperado. Intenta de nuevo.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREAR COMENTARIO (vía Cloud Function)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Envía un comentario a un post aprobado.
  Future<WallPostResult> submitComment({
    required String postId,
    required String body,
  }) async {
    try {
      final result = await _callable('createWallComment').call<Map<String, dynamic>>({
        'postId': postId,
        'body': body.trim(),
      });
      final data = result.data;
      return WallPostResult(
        success: data['success'] == true,
        message: data['message'] as String? ?? '',
        commentId: data['commentId'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [WALL] submitComment error: ${e.code} - ${e.message}');
      return WallPostResult(
        success: false,
        message: _mapFunctionError(e),
      );
    } catch (e) {
      return const WallPostResult(
        success: false,
        message: 'Error inesperado. Intenta de nuevo.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEED - POSTS APROBADOS (lectura directa Firestore)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream del feed aprobado, opcionalmente filtrado por gigante.
  /// Paginado. Para cargar más, pasar [startAfterDoc].
  Stream<List<WallPost>> watchApprovedFeed({
    String? giantFilter,
    DocumentSnapshot? startAfterDoc,
    int limit = kWallPageSize,
  }) {
    Query query = _postsRef
        .where('status', isEqualTo: 'approved')
        .orderBy('approvedAt', descending: true);

    if (giantFilter != null && giantFilter.isNotEmpty) {
      query = query.where('giantId', isEqualTo: giantFilter);
    }

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    query = query.limit(limit);

    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => WallPost.fromFirestore(doc)).toList());
  }

  /// Fetch una sola página (para paginación manual / refresh).
  Future<List<WallPost>> fetchApprovedFeed({
    String? giantFilter,
    DocumentSnapshot? startAfterDoc,
    int limit = kWallPageSize,
  }) async {
    Query query = _postsRef
        .where('status', isEqualTo: 'approved')
        .orderBy('approvedAt', descending: true);

    if (giantFilter != null && giantFilter.isNotEmpty) {
      query = query.where('giantId', isEqualTo: giantFilter);
    }

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    query = query.limit(limit);

    final snap = await query.get();
    return snap.docs.map((doc) => WallPost.fromFirestore(doc)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMENTARIOS APROBADOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream de comentarios aprobados de un post.
  Stream<List<WallComment>> watchApprovedComments(String postId) {
    return _postsRef
        .doc(postId)
        .collection('comments')
        .where('status', isEqualTo: 'approved')
        .orderBy('approvedAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => WallComment.fromFirestore(doc)).toList());
  }

  /// Obtiene un post individual por ID.
  Future<WallPost?> getPost(String postId) async {
    final doc = await _postsRef.doc(postId).get();
    if (!doc.exists) return null;
    return WallPost.fromFirestore(doc);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REPORTAR CONTENIDO (vía Cloud Function)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Reporta un post o comentario.
  Future<WallPostResult> reportContent({
    required String contentType, // 'post' o 'comment'
    required String postId,
    String? commentId,
    required String reason,
  }) async {
    try {
      final payload = <String, dynamic>{
        'type': contentType,
        'postId': postId,
        'reason': reason,
      };
      if (commentId != null) payload['commentId'] = commentId;

      final result = await _callable('reportContent').call<Map<String, dynamic>>(payload);
      final data = result.data;
      return WallPostResult(
        success: data['success'] == true,
        message: data['message'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      return WallPostResult(success: false, message: _mapFunctionError(e));
    } catch (e) {
      debugPrint('🧱 [WALL] reportPost error: $e');
      return const WallPostResult(success: false, message: 'Error al reportar.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADMIN - MODERACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream de posts pendientes (admin).
  Stream<List<WallPost>> watchPendingPosts() {
    return _postsRef
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false) // FIFO
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => WallPost.fromFirestore(doc)).toList());
  }

  /// Stream de posts reportados (admin).
  Stream<List<WallPost>> watchReportedPosts() {
    return _postsRef
        .where('status', isEqualTo: 'approved')
        .where('reportCount', isGreaterThan: 0)
        .orderBy('reportCount', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => WallPost.fromFirestore(doc)).toList());
  }

  /// Stream de todos los posts aprobados (admin).
  Stream<List<WallPost>> watchApprovedPostsAdmin() {
    return _postsRef
        .where('status', isEqualTo: 'approved')
        .orderBy('approvedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => WallPost.fromFirestore(doc)).toList());
  }

  /// Stream de posts rechazados (admin).
  Stream<List<WallPost>> watchRejectedPosts() {
    return _postsRef
        .where('status', isEqualTo: 'rejected')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => WallPost.fromFirestore(doc)).toList());
  }

  /// Stream de comentarios pendientes de un post (admin).
  Stream<List<WallComment>> watchPendingComments(String postId) {
    return _postsRef
        .doc(postId)
        .collection('comments')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => WallComment.fromFirestore(doc)).toList());
  }

  /// Stream de todos los comentarios de un post (admin).
  Stream<List<WallComment>> watchAllComments(String postId) {
    return _postsRef
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => WallComment.fromFirestore(doc)).toList());
  }

  /// Moderar contenido (aprobar/rechazar). Solo admin.
  Future<WallPostResult> moderateContent({
    required String contentType, // 'post' o 'comment'
    required String postId,
    String? commentId,
    required String action, // 'approve' o 'reject'
    String? rejectionReason,
  }) async {
    try {
      final payload = <String, dynamic>{
        'type': contentType,
        'postId': postId,
        'action': action,
      };
      if (commentId != null) payload['commentId'] = commentId;
      if (rejectionReason != null) payload['rejectionReason'] = rejectionReason;

      final result = await _callable('moderateContent').call<Map<String, dynamic>>(payload);
      final data = result.data;
      return WallPostResult(
        success: data['success'] == true,
        message: data['message'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      return WallPostResult(success: false, message: _mapFunctionError(e));
    } catch (e) {
      debugPrint('🧱 [WALL] moderate error: $e');
      return const WallPostResult(success: false, message: 'Error al moderar.');
    }
  }

  /// Banear un abuseHash. Solo admin.
  Future<WallPostResult> banUser({
    required String abuseHash,
    String? reason,
  }) async {
    try {
      final payload = <String, dynamic>{
        'abuseHash': abuseHash,
      };
      if (reason != null) payload['reason'] = reason;

      final result = await _callable('banAbuseHash').call<Map<String, dynamic>>(payload);
      final data = result.data;
      return WallPostResult(
        success: data['success'] == true,
        message: data['message'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      return WallPostResult(success: false, message: _mapFunctionError(e));
    } catch (e) {
      debugPrint('🧱 [WALL] ban error: $e');
      return const WallPostResult(success: false, message: 'Error al banear.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _mapFunctionError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Debes iniciar sesión para continuar.';
      case 'permission-denied':
        return 'No tienes permiso para esta acción.';
      case 'resource-exhausted':
        return 'Has alcanzado el límite diario. Intenta mañana.';
      case 'invalid-argument':
        return e.message ?? 'Datos inválidos.';
      case 'not-found':
        return 'El contenido no existe o fue eliminado.';
      default:
        return e.message ?? 'Error del servidor.';
    }
  }
}
