/// ═══════════════════════════════════════════════════════════════════════════
/// ADMIN POST CARD - Tarjeta de moderación para admin
/// Muestra: cuerpo completo, alias, gigante, fecha, abuseHash,
/// botones de aprobar/rechazar/banear.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../models/wall_post.dart';
import '../models/content_enums.dart';
import '../theme/app_theme.dart';
import '../services/feedback_engine.dart';

class AdminPostCard extends StatelessWidget {
  final WallPost post;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onBan;
  final VoidCallback? onViewComments;

  const AdminPostCard({
    super.key,
    required this.post,
    this.onApprove,
    this.onReject,
    this.onBan,
    this.onViewComments,
  });

  @override
  Widget build(BuildContext context) {
    final giant = GiantIdExtension.fromId(post.giantId);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingS),
      decoration: BoxDecoration(
        color: AppDesignSystem.midnightLight.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Status + Giant + AbuseHash ──
            Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (giant != null)
                  Text(
                    giant.displayName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppDesignSystem.coolGray,
                    ),
                  ),
                const Spacer(),
                if (post.reportCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.struggle.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag_rounded, size: 11, color: AppDesignSystem.struggle),
                        const SizedBox(width: 3),
                        Text(
                          '${post.reportCount}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.struggle,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Alias + Hash ──
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: AppDesignSystem.gold),
                const SizedBox(width: 4),
                Text(
                  post.alias,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.gold,
                  ),
                ),
                const SizedBox(width: 8),
                if (post.abuseHash != null)
                  Expanded(
                    child: Text(
                      '#${post.abuseHash}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppDesignSystem.coolGray.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Body (completo) ──
            Text(
              post.body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppDesignSystem.pureWhite,
              ),
            ),

            // ── Rejection reason (si aplica) ──
            if (post.isRejected && post.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignSystem.struggle.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppDesignSystem.struggle),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        post.rejectionReason!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppDesignSystem.struggle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),

            // ── Date + Comment count ──
            Row(
              children: [
                Text(
                  _formatDate(post.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppDesignSystem.coolGray.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 12,
                  color: AppDesignSystem.coolGray.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 3),
                Text(
                  '${post.commentCount}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppDesignSystem.coolGray.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Action buttons ──
            Row(
              children: [
                if (post.isPending) ...[
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.check_circle_outline,
                      label: 'Aprobar',
                      color: const Color(0xFFD4AF37),
                      onTap: onApprove,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.cancel_outlined,
                      label: 'Rechazar',
                      color: AppDesignSystem.coolGray,
                      onTap: onReject,
                    ),
                  ),
                ] else if (post.isApproved) ...[
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.cancel_outlined,
                      label: 'Rechazar',
                      color: AppDesignSystem.coolGray,
                      onTap: onReject,
                    ),
                  ),
                ],
                if (post.abuseHash != null) ...[
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.block_rounded,
                    label: 'Ban',
                    color: const Color(0xFF616161),
                    onTap: onBan,
                  ),
                ],
                if (onViewComments != null && post.commentCount > 0) ...[
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.forum_outlined,
                    label: '${post.commentCount}',
                    color: AppDesignSystem.hope,
                    onTap: onViewComments,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (post.status) {
      case WallContentStatus.pending:
        return AppDesignSystem.gold;
      case WallContentStatus.approved:
        return AppDesignSystem.victory;
      case WallContentStatus.rejected:
        return AppDesignSystem.struggle;
    }
  }

  String get _statusLabel {
    switch (post.status) {
      case WallContentStatus.pending:
        return 'PENDIENTE';
      case WallContentStatus.approved:
        return 'APROBADO';
      case WallContentStatus.rejected:
        return 'RECHAZADO';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Mini action button
// ═══════════════════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FeedbackEngine.I.tap();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
