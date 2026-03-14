/// ═══════════════════════════════════════════════════════════════════════════
/// WALL THREAD SCREEN - Hilo de comentarios de un post
/// Post completo + lista de comentarios aprobados + input para comentar.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
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
          content: const Text(
            'Tu comentario será revisado pronto.',
            style: TextStyle(color: AppDesignSystem.pureWhite),
          ),
          backgroundColor: AppDesignSystem.midnightLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message,
            style: const TextStyle(color: AppDesignSystem.pureWhite),
          ),
          backgroundColor: AppDesignSystem.struggle,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showReportDialog(WallComment comment) {
    FeedbackEngine.I.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDesignSystem.midnightLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CommentReportSheet(
        onReport: (reason) async {
          Navigator.pop(ctx);
          final res = await WallService.I.reportContent(
            contentType: 'comment',
            postId: widget.post.id,
            commentId: comment.id,
            reason: reason.id,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  res.success ? 'Gracias por reportar.' : res.message,
                  style: const TextStyle(color: AppDesignSystem.pureWhite),
                ),
                backgroundColor: AppDesignSystem.midnightLight,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Hilo',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppDesignSystem.pureWhite,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppDesignSystem.pureWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Post + Comments ──
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppDesignSystem.spacingM),
              children: [
                // Original post
                WallPostCard(
                  post: widget.post,
                  showFullBody: true,
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 8),

                // Comments header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 14,
                        color: AppDesignSystem.gold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Comentarios (${widget.post.commentCount})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppDesignSystem.gold,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: AppDesignSystem.gold),
                    ),
                  )
                else if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Aún no hay comentarios.\n¡Sé el primero en responder!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppDesignSystem.coolGray.withValues(alpha: 0.5),
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  ..._comments.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final comment = entry.value;
                    return _CommentTile(
                      comment: comment,
                      onLongPress: () => _showReportDialog(comment),
                    ).animate().fadeIn(
                          duration: 250.ms,
                          delay: Duration(milliseconds: idx.clamp(0, 10) * 40),
                        );
                  }),
              ],
            ),
          ),

          // ── Comment input bar ──
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: AppDesignSystem.spacingM,
        right: AppDesignSystem.spacingS,
        top: AppDesignSystem.spacingS,
        bottom: MediaQuery.of(context).padding.bottom + AppDesignSystem.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppDesignSystem.midnightLight,
        border: Border(
          top: BorderSide(
            color: AppDesignSystem.gold.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              maxLength: _kMaxCommentLength,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(
                fontSize: 14,
                color: AppDesignSystem.pureWhite,
              ),
              decoration: InputDecoration(
                hintText: 'Escribe un comentario...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppDesignSystem.coolGray.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppDesignSystem.gold.withValues(alpha: 0.15),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFD4AF37),
                    width: 1.5,
                  ),
                ),
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              cursorColor: AppDesignSystem.gold,
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
                    ? AppDesignSystem.gold.withValues(alpha: 0.2)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppDesignSystem.gold,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: _canSend
                          ? AppDesignSystem.gold
                          : AppDesignSystem.coolGray.withValues(alpha: 0.3),
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
  final VoidCallback? onLongPress;

  const _CommentTile({required this.comment, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppDesignSystem.midnightDeep.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppDesignSystem.gold.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 12, color: AppDesignSystem.gold),
                const SizedBox(width: 4),
                Text(
                  comment.alias,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.gold,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimeAgo(comment.approvedAt ?? comment.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppDesignSystem.coolGray.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Body
            Text(
              comment.body,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppDesignSystem.pureWhite,
              ),
            ),
          ],
        ),
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
  final void Function(ReportReason reason) onReport;

  const _CommentReportSheet({required this.onReport});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reportar comentario',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppDesignSystem.pureWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Selecciona la razón:',
              style: TextStyle(
                fontSize: 13,
                color: AppDesignSystem.coolGray.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            ...ReportReason.values.map(
              (reason) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.flag_outlined, size: 18, color: AppDesignSystem.struggle),
                title: Text(
                  reason.displayName,
                  style: const TextStyle(fontSize: 14, color: AppDesignSystem.pureWhite),
                ),
                onTap: () {
                  FeedbackEngine.I.select();
                  onReport(reason);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
