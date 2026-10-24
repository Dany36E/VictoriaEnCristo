/// ═══════════════════════════════════════════════════════════════════════════
/// ADMIN WALL SCREEN - Panel de moderación del Muro de Batalla
/// Tabs: Pendientes | Comentarios | Reportados | Aprobados | Rechazados
/// "Comentarios" es la cola de comentarios pendientes y reportados de todas
/// las publicaciones (antes nadie los aprobaba y nunca se publicaban).
/// Solo accesible si isAdmin == true.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';
import '../../models/wall_post.dart';
import '../../services/wall_service.dart';
import '../../services/feedback_engine.dart';
import '../../theme/app_theme_data.dart';
import '../../widgets/admin_post_card.dart';

class AdminWallScreen extends StatefulWidget {
  const AdminWallScreen({super.key});

  @override
  State<AdminWallScreen> createState() => _AdminWallScreenState();
}

class _AdminWallScreenState extends State<AdminWallScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Streams
  StreamSubscription? _pendingSub;
  StreamSubscription? _reportedSub;
  StreamSubscription? _approvedSub;
  StreamSubscription? _rejectedSub;
  StreamSubscription? _pendingCommentsSub;
  StreamSubscription? _reportedCommentsSub;

  List<WallComment> _pendingComments = [];
  List<WallComment> _reportedComments = [];
  bool _loadingComments = true;
  String? _commentsError;

  List<WallPost> _pending = [];
  List<WallPost> _reported = [];
  List<WallPost> _approved = [];
  List<WallPost> _rejected = [];

  bool _loadingPending = true;
  bool _loadingReported = true;
  bool _loadingApproved = true;
  bool _loadingRejected = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _subscribeAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pendingSub?.cancel();
    _reportedSub?.cancel();
    _approvedSub?.cancel();
    _rejectedSub?.cancel();
    _pendingCommentsSub?.cancel();
    _reportedCommentsSub?.cancel();
    super.dispose();
  }

  void _subscribeAll() {
    _pendingSub = WallService.I.watchPendingPosts().listen((posts) {
      if (mounted) setState(() { _pending = posts; _loadingPending = false; });
    });
    _reportedSub = WallService.I.watchReportedPosts().listen((posts) {
      if (mounted) setState(() { _reported = posts; _loadingReported = false; });
    });
    _approvedSub = WallService.I.watchApprovedPostsAdmin().listen((posts) {
      if (mounted) setState(() { _approved = posts; _loadingApproved = false; });
    });
    _rejectedSub = WallService.I.watchRejectedPosts().listen((posts) {
      if (mounted) setState(() { _rejected = posts; _loadingRejected = false; });
    });
    void errorComentarios(Object e) {
      debugPrint('🧱 [ADMIN] Cola de comentarios: $e');
      if (mounted) {
        setState(() {
          _loadingComments = false;
          _commentsError =
              'No se pudo cargar la cola de comentarios. Si es la primera '
              'vez, falta desplegar los índices de Firestore.';
        });
      }
    }

    _pendingCommentsSub = WallService.I.watchPendingCommentsQueue().listen(
      (comments) {
        if (mounted) {
          setState(() {
            _pendingComments = comments;
            _loadingComments = false;
            _commentsError = null;
          });
        }
      },
      onError: errorComentarios,
    );
    _reportedCommentsSub = WallService.I.watchReportedComments().listen(
      (comments) {
        if (mounted) setState(() => _reportedComments = comments);
      },
      onError: errorComentarios,
    );
  }

  Future<void> _moderarComentario(WallComment c, String action) async {
    final postId = c.postId;
    if (postId == null) return;
    String? razon;
    if (action == 'reject') {
      razon = await _showRejectionDialog();
      if (razon == null || !mounted) return;
    } else {
      FeedbackEngine.I.confirm();
    }
    final res = await WallService.I.moderateContent(
      contentType: 'comment',
      postId: postId,
      commentId: c.id,
      action: action,
      rejectionReason: razon,
    );
    if (mounted) _showResult(res);
  }

  Future<void> _banearAutorComentario(WallComment c) async {
    final hash = c.abuseHash;
    if (hash == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Banear usuario'),
        content: Text(
          'Esto bloqueará permanentemente a ${c.alias} para publicar y '
          'comentar en el Muro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Banear', style: TextStyle(color: VecColores.terracota)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final res = await WallService.I.banUser(
      abuseHash: hash,
      reason: 'Admin ban from comment queue',
    );
    if (mounted) _showResult(res);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES DE MODERACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _approvePost(WallPost post) async {
    FeedbackEngine.I.confirm();
    final res = await WallService.I.moderateContent(
      contentType: 'post',
      postId: post.id,
      action: 'approve',
    );
    if (mounted) _showResult(res);
  }

  Future<void> _rejectPost(WallPost post) async {
    final reason = await _showRejectionDialog();
    if (reason == null || !mounted) return;

    final res = await WallService.I.moderateContent(
      contentType: 'post',
      postId: post.id,
      action: 'reject',
      rejectionReason: reason,
    );
    if (mounted) _showResult(res);
  }

  Future<void> _banUser(WallPost post) async {
    if (post.abuseHash == null) return;

    // El diálogo toma los colores de AppTheme.paperTheme.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Banear usuario',
        ),
        content: Text(
          'Esto bloqueará permanentemente al usuario ${post.alias} '
          '(hash: ${post.abuseHash}) y rechazará todos sus posts pendientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: VecColores.gris,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Banear',
              style: TextStyle(
                color: VecColores.terracota,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await WallService.I.banUser(
      abuseHash: post.abuseHash!,
      reason: 'Admin ban from moderation panel',
    );
    if (mounted) _showResult(res);
  }

  Future<String?> _showRejectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Razón de rechazo',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: kRejectionReasons.map((reason) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                reason,
                style: TextStyle(
                        fontFamily: VecFuentes.texto,
                        fontSize: 17,
                        color: VecColores.tinta,
                      ),
              ),
              onTap: () => Navigator.pop(ctx, reason),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: VecColores.gris,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResult(WallPostResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message,
          style: TextStyle(color: VecColores.papel),
        ),
        backgroundColor: result.success
            ? VecColores.verde
            : VecColores.terracota,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildPapel();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAPEL RECORTADO — barra, pestañas y diálogos salen de AppTheme.paperTheme;
  // las listas vacías llevan a Timoteo o Victoria como guía.
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPapel() {
    return FondoPapel(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const TituloVec('Moderación', tamano: 26),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (_) => FeedbackEngine.I.tabChange(),
            tabs: [
              Tab(text: 'Pendientes (${_pending.length})'),
              Tab(
                text:
                    'Comentarios (${_pendingComments.length + _reportedComments.length})',
              ),
              Tab(text: 'Reportados (${_reported.length})'),
              Tab(text: 'Aprobados (${_approved.length})'),
              Tab(text: 'Rechazados (${_rejected.length})'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildListPapel(_pending, _loadingPending,
                'No hay posts pendientes', 'victoria_corazon'),
            _buildComentarios(),
            _buildListPapel(_reported, _loadingReported,
                'No hay posts reportados', 'timoteo_saludo'),
            _buildListPapel(_approved, _loadingApproved,
                'No hay posts aprobados', 'victoria_piensa'),
            _buildListPapel(_rejected, _loadingRejected,
                'No hay posts rechazados', 'timoteo_piensa'),
          ],
        ),
      ),
    );
  }

  Widget _buildListPapel(
    List<WallPost> posts,
    bool loading,
    String emptyMessage,
    String personaje,
  ) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopIn(
                child: Sticker(
                  'assets/vec/personajes/$personaje.png',
                  alto: 170,
                  giro: -2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VecFuentes.texto,
                  fontSize: 20,
                  color: VecColores.lapiz,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return AdminPostCard(
          post: post,
          onApprove: post.isPending ? () => _approvePost(post) : null,
          onReject: (post.isPending || post.isApproved) ? () => _rejectPost(post) : null,
          onBan: post.abuseHash != null ? () => _banUser(post) : null,
        );
      },
    );
  }

  Widget _buildComentarios() {
    if (_loadingComments) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _commentsError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }
    if (_pendingComments.isEmpty && _reportedComments.isEmpty) {
      return Center(
        child: Text(
          'No hay comentarios por revisar',
          style: TextStyle(
            fontFamily: VecFuentes.texto,
            fontSize: 20,
            color: VecColores.lapiz,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        if (_pendingComments.isNotEmpty) ...[
          const EtiquetaSeccion('Por aprobar'),
          const SizedBox(height: 10),
          for (final c in _pendingComments)
            _AdminCommentCard(
              comment: c,
              onApprove: () => _moderarComentario(c, 'approve'),
              onReject: () => _moderarComentario(c, 'reject'),
              onBan: c.abuseHash == null ? null : () => _banearAutorComentario(c),
            ),
        ],
        if (_reportedComments.isNotEmpty) ...[
          const SizedBox(height: 12),
          const EtiquetaSeccion('Reportados'),
          const SizedBox(height: 10),
          for (final c in _reportedComments)
            _AdminCommentCard(
              comment: c,
              approveLabel: 'Mantener',
              onApprove: () => _moderarComentario(c, 'approve'),
              onReject: () => _moderarComentario(c, 'reject'),
              onBan: c.abuseHash == null ? null : () => _banearAutorComentario(c),
            ),
        ],
      ],
    );
  }
}

/// Tarjeta de un comentario en la cola de moderación.
class _AdminCommentCard extends StatelessWidget {
  const _AdminCommentCard({
    required this.comment,
    required this.onApprove,
    required this.onReject,
    this.onBan,
    this.approveLabel = 'Aprobar',
  });

  final WallComment comment;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onBan;
  final String approveLabel;

  @override
  Widget build(BuildContext context) {
    final post = comment.postId ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: AppThemeData.of(context).cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.alias,
                  style: TextStyle(
                    fontFamily: VecFuentes.titulo,
                    fontSize: 17,
                    color: VecColores.tinta,
                  ),
                ),
              ),
              if (comment.reportCount > 0)
                ChipVec(
                  texto:
                      '${comment.reportCount} reporte${comment.reportCount == 1 ? '' : 's'}',
                  color: VecColores.mostaza,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment.body,
            style: TextStyle(
              fontFamily: VecFuentes.texto,
              fontSize: 17,
              height: 1.25,
              color: VecColores.tinta,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'En la publicación ${post.length > 6 ? post.substring(0, 6) : post}…',
            style: TextStyle(
              fontFamily: VecFuentes.texto,
              fontSize: 14,
              color: VecColores.gris,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check_rounded),
                label: Text(approveLabel),
              ),
              OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Rechazar'),
              ),
              if (onBan != null)
                TextButton.icon(
                  onPressed: onBan,
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('Banear autor'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
