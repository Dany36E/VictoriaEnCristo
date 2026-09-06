/// ═══════════════════════════════════════════════════════════════════════════
/// WALL THREAD SCREEN - Hilo de comentarios de un post
/// Post completo + lista de comentarios aprobados + input para comentar.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../models/wall_post.dart';
import '../../services/wall_service.dart';
import '../../services/feedback_engine.dart';
import '../../widgets/wall_post_card.dart';

const int _kMaxCommentLength = 300;

class WallThreadScreen extends StatefulWidget {
  final WallPost post;

  const WallThreadScreen({super.key, required this.post});

  @override
  State<WallThreadScreen> createState() => _WallThreadScreenState();
}

class _WallThreadScreenState extends State<WallThreadScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription? _commentsSub;
  List<WallComment> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _subscribeComments();
  }

  @override
  void dispose() {
    _commentsSub?.cancel();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeComments() {
    _commentsSub = WallService.I
        .watchApprovedComments(widget.post.id)
        .listen(
          (comments) {
            if (!mounted) return;
            setState(() {
              _comments = comments;
              _loading = false;
            });
          },
          onError: (e) {
            debugPrint('❌ [WALL] Comments error: $e');
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  bool get _canSend =>
      _commentController.text.trim().length >= 3 &&
      _commentController.text.trim().length <= _kMaxCommentLength &&
      !_sending;

  Future<void> _sendComment() async {
    if (!_canSend) return;
    FeedbackEngine.I.confirm();
    setState(() => _sending = true);

    final result = await WallService.I.submitComment(
      postId: widget.post.id,
      body: _commentController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (result.success) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tu comentario será revisado pronto.',
            style: TextStyle(color: AppThemeData.of(context).textPrimary),
          ),
          backgroundColor: AppThemeData.of(context).inputBg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message,
            style: TextStyle(color: AppThemeData.of(context).textPrimary),
          ),
          backgroundColor: AppDesignSystem.struggle,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showContentActions({WallComment? comment}) {
    FeedbackEngine.I.tap();
    final isComment = comment != null;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppThemeData.of(context).inputBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CommentReportSheet(
        contentLabel: isComment ? 'comentario' : 'publicación',
        onReport: (reason) async {
          Navigator.pop(ctx);
          final res = await WallService.I.reportContent(
            contentType: isComment ? 'comment' : 'post',
            postId: widget.post.id,
            commentId: comment?.id,
            reason: reason.id,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  res.success ? 'Gracias por reportar.' : res.message,
                  style: TextStyle(color: AppThemeData.of(context).textPrimary),
                ),
                backgroundColor: AppThemeData.of(context).inputBg,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onBlock: () async {
          Navigator.pop(ctx);
          final alias = comment?.alias ?? widget.post.alias;
          final confirmed = await _confirmBlock(alias);
          if (confirmed != true) return;
          final res = await WallService.I.blockAuthor(
            contentType: isComment ? 'comment' : 'post',
            postId: widget.post.id,
            commentId: comment?.id,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message),
              backgroundColor: AppThemeData.of(context).inputBg,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (res.success && !isComment) Navigator.pop(context);
        },
      ),
    );
  }

  Future<bool?> _confirmBlock(String alias) {
    final t = AppThemeData.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.cardBg,
        icon: Icon(Icons.person_off_outlined, color: t.accent),
        title: Text('¿Bloquear a $alias?'),
        content: const Text(
          'Dejarás de ver sus publicaciones y comentarios en el Muro de Batalla.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Hilo',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Post + Comments ──
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppDesignSystem.spacingM),
              itemCount:
                  3 +
                  (_loading
                      ? 1
                      : _comments.isEmpty
                      ? 1
                      : _comments.length),
              itemBuilder: (context, index) {
                // 0: Original post
                if (index == 0) {
                  return WallPostCard(
                    post: widget.post,
                    showFullBody: true,
                    onReport: () => _showContentActions(),
                  ).animate().fadeIn(duration: 300.ms);
                }
                // 1: Spacer
                if (index == 1) return const SizedBox(height: 8);
                // 2: Comments header
                if (index == 2) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 14,
                          color: t.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Comentarios (${widget.post.commentCount})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.accent,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // 3+: Loading / Empty / Comments
                if (_loading) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: t.accent),
                    ),
                  );
                }
                if (_comments.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Aún no hay comentarios.\n¡Sé el primero en responder!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.textSecondary.withValues(alpha: 0.5),
                        height: 1.5,
                      ),
                    ),
                  );
                }
                final commentIdx = index - 3;
                final comment = _comments[commentIdx];
                return _CommentTile(
                  comment: comment,
                  onActions: () => _showContentActions(comment: comment),
                ).animate().fadeIn(
                  duration: 250.ms,
                  delay: Duration(milliseconds: commentIdx.clamp(0, 10) * 40),
                );
              },
            ),
          ),

          // ── Comment input bar ──
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    final t = AppThemeData.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: AppDesignSystem.spacingM,
        right: AppDesignSystem.spacingS,
        top: AppDesignSystem.spacingS,
        bottom:
            MediaQuery.of(context).padding.bottom + AppDesignSystem.spacingS,
      ),
      decoration: BoxDecoration(
        color: t.inputBg,
        border: Border(top: BorderSide(color: t.accent.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              maxLength: _kMaxCommentLength,
              maxLines: 3,
              minLines: 1,
              style: TextStyle(fontSize: 14, color: t.textPrimary),
              decoration: InputDecoration(
                hintText: 'Escribe un comentario...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: t.textSecondary.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: t.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: t.accent.withValues(alpha: 0.15),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.accent, width: 1.5),
                ),
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              cursorColor: t.accent,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _canSend ? _sendComment : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _canSend
                    ? t.accent.withValues(alpha: 0.2)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: _canSend
                          ? t.accent
                          : t.textSecondary.withValues(alpha: 0.3),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COMMENT TILE
// ═══════════════════════════════════════════════════════════════════════════

class _CommentTile extends StatelessWidget {
  final WallComment comment;
  final VoidCallback? onActions;

  const _CommentTile({required this.comment, this.onActions});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.scaffoldBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 12, color: t.accent),
              const SizedBox(width: 4),
              Text(
                comment.alias,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: t.accent,
                ),
              ),
              const Spacer(),
              Text(
                _formatTimeAgo(comment.approvedAt ?? comment.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: t.textSecondary.withValues(alpha: 0.5),
                ),
              ),
              if (onActions != null) ...[
                const SizedBox(width: 4),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    tooltip: 'Opciones del comentario',
                    padding: EdgeInsets.zero,
                    onPressed: onActions,
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: t.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Body
          Text(
            comment.body,
            style: TextStyle(fontSize: 13, height: 1.4, color: t.textPrimary),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COMMENT REPORT SHEET (reuse of report pattern)
// ═══════════════════════════════════════════════════════════════════════════

class _CommentReportSheet extends StatelessWidget {
  final String contentLabel;
  final void Function(ReportReason reason) onReport;
  final VoidCallback onBlock;

  const _CommentReportSheet({
    required this.contentLabel,
    required this.onReport,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cuidar este espacio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Reporta este $contentLabel o deja de ver a su autor.',
              style: TextStyle(
                fontSize: 13,
                color: t.textSecondary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            ...ReportReason.values.map(
              (reason) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: AppDesignSystem.struggle,
                ),
                title: Text(
                  reason.displayName,
                  style: TextStyle(fontSize: 14, color: t.textPrimary),
                ),
                onTap: () {
                  FeedbackEngine.I.select();
                  onReport(reason);
                },
              ),
            ),
            Divider(color: t.divider),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.person_off_outlined,
                size: 20,
                color: t.textSecondary,
              ),
              title: Text(
                'Bloquear a este usuario',
                style: TextStyle(color: t.textPrimary),
              ),
              subtitle: Text(
                'Oculta sus publicaciones y comentarios para ti.',
                style: TextStyle(color: t.textSecondary, fontSize: 12),
              ),
              onTap: onBlock,
            ),
          ],
        ),
      ),
    );
  }
}
