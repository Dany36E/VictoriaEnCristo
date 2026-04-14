/// ═══════════════════════════════════════════════════════════════════════════
/// WALL POST CARD - Tarjeta de post en el Muro de Batalla
/// Muestra: alias anónimo, badge de gigante, cuerpo (3 líneas preview),
/// tiempo relativo, conteo de comentarios, botón de reportar.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../models/wall_post.dart';
import '../models/content_enums.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../services/feedback_engine.dart';

class WallPostCard extends StatelessWidget {
  final WallPost post;
  final VoidCallback? onTap;
  final VoidCallback? onReport;
  final bool showFullBody;

  const WallPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onReport,
    this.showFullBody = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final giant = GiantIdExtension.fromId(post.giantId);

    return GestureDetector(
      onTap: () {
        FeedbackEngine.I.tap();
        onTap?.call();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingS),
        decoration: BoxDecoration(
          color: t.inputBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: t.accent.withValues(alpha: 0.1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Alias + Giant badge + Time ──
              Row(
                children: [
                  // Avatar anónimo
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          t.accent.withValues(alpha: 0.3),
                          t.accent.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: t.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Alias
                  Expanded(
                    child: Text(
                      post.alias,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.accent,
                      ),
                    ),
                  ),
                  // Giant badge
                  if (giant != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _giantColor(giant).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _giantColor(giant).withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        giant.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _giantColor(giant),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Body ──
              Text(
                post.body,
                maxLines: showFullBody ? null : 4,
                overflow: showFullBody ? null : TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // ── Footer: Time + Comments + Report ──
              Row(
                children: [
                  // Tiempo relativo
                  Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: t.textSecondary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeAgo(post.approvedAt ?? post.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: t.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Comentarios
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 13,
                    color: t.textSecondary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentCount}',
                    style: TextStyle(
                      fontSize: 11,
                      color: t.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  // Reportar
                  if (onReport != null)
                    GestureDetector(
                      onTap: () {
                        FeedbackEngine.I.tap();
                        onReport?.call();
                      },
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: t.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _giantColor(GiantId giant) {
    switch (giant) {
      case GiantId.digital:
        return const Color(0xFF64B5F6); // blue
      case GiantId.sexual:
        return const Color(0xFFE57373); // red
      case GiantId.health:
        return const Color(0xFF81C784); // green
      case GiantId.substances:
        return const Color(0xFFFFB74D); // orange
      case GiantId.mental:
        return const Color(0xFFBA68C8); // purple
      case GiantId.emotions:
        return const Color(0xFFFF8A65); // deep orange
    }
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    if (diff.inDays < 30) return 'Hace ${diff.inDays ~/ 7}sem';
    return 'Hace ${diff.inDays ~/ 30}mes';
  }
}
