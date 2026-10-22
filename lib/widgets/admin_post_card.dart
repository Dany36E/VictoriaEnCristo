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
import '../theme/app_theme_data.dart';
import '../services/feedback_engine.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';

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
    if (AppThemeData.of(context).isPaper) return _buildPapel(giant);

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

  // ═══════════════════════════════════════════════════════════════════════
  // TEMA PAPEL
  // ═══════════════════════════════════════════════════════════════════════

  static TextStyle get _textoPapel => TextStyle(
    fontFamily: VecFuentes.texto,
    fontSize: 15,
    color: VecColores.gris,
  );

  Widget _buildPapel(GiantId? giant) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: TarjetaPapel(
        giro: 0,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Estado + gigante + reportes ──
            Row(
              children: [
                ChipVec(texto: _statusLabelPapel, color: _statusColorPapel),
                const SizedBox(width: 10),
                if (giant != null)
                  Expanded(
                    child: Text(
                      giant.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: _textoPapel.copyWith(fontSize: 16),
                    ),
                  )
                else
                  const Spacer(),
                if (post.reportCount > 0)
                  ChipVec(
                    texto: '${post.reportCount}',
                    icono: Icons.flag_rounded,
                    color: VecColores.terracota,
                    giro: 1.5,
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Alias + hash ──
            Row(
              children: [
                IconoVec('escudo', color: VecColores.azul, tamano: 20),
                const SizedBox(width: 6),
                Text(
                  post.alias,
                  style: TextStyle(
                    fontFamily: VecFuentes.titulo,
                    fontSize: 17,
                    color: VecColores.azul,
                  ),
                ),
                const SizedBox(width: 8),
                if (post.abuseHash != null)
                  Expanded(
                    child: Text(
                      '#${post.abuseHash}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: VecColores.gris,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Cuerpo completo ──
            Text(
              post.body,
              style: TextStyle(
                fontFamily: VecFuentes.texto,
                fontSize: 19,
                height: 1.3,
                color: VecColores.tinta,
              ),
            ),

            // ── Razón de rechazo ──
            if (post.isRejected && post.rejectionReason != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                decoration: BoxDecoration(
                  color: VecColores.cremaOscuro,
                  borderRadius: BorderRadius.circular(VecRadios.s),
                  border: Border.all(color: VecColores.terracota, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      size: 18,
                      color: VecColores.terracota,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.rejectionReason!,
                        style: _textoPapel.copyWith(
                          fontSize: 16,
                          color: VecColores.tinta,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),

            // ── Fecha + comentarios ──
            Row(
              children: [
                Text(_formatDate(post.createdAt), style: _textoPapel),
                const SizedBox(width: 12),
                Icon(
                  Icons.chat_bubble_rounded,
                  size: 15,
                  color: VecColores.gris,
                ),
                const SizedBox(width: 4),
                Text('${post.commentCount}', style: _textoPapel),
              ],
            ),
            const SizedBox(height: 16),

            // ── Acciones (Wrap: no se desbordan con texto grande) ──
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                if (post.isPending)
                  _AccionPapel(
                    icon: Icons.check_circle_rounded,
                    label: 'Aprobar',
                    color: VecColores.verde,
                    onTap: onApprove,
                  ),
                if (post.isPending || post.isApproved)
                  _AccionPapel(
                    icon: Icons.cancel_rounded,
                    label: 'Rechazar',
                    color: VecColores.terracota,
                    onTap: onReject,
                  ),
                if (post.abuseHash != null)
                  _AccionPapel(
                    icon: Icons.block_rounded,
                    label: 'Ban',
                    color: VecColores.lapiz,
                    onTap: onBan,
                  ),
                if (onViewComments != null && post.commentCount > 0)
                  _AccionPapel(
                    icon: Icons.forum_rounded,
                    label: '${post.commentCount}',
                    color: VecColores.azul,
                    onTap: onViewComments,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _statusColorPapel {
    switch (post.status) {
      case WallContentStatus.pending:
        return VecColores.azul;
      case WallContentStatus.approved:
        return VecColores.verde;
      case WallContentStatus.rejected:
        return VecColores.terracota;
    }
  }

  String get _statusLabelPapel {
    switch (post.status) {
      case WallContentStatus.pending:
        return 'Pendiente';
      case WallContentStatus.approved:
        return 'Aprobado';
      case WallContentStatus.rejected:
        return 'Rechazado';
    }
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

/// Píldora de acción del tema papel (como ChipVec, pero se puede tocar).
class _AccionPapel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AccionPapel({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  void _tocar() {
    FeedbackEngine.I.tap();
    onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap == null ? null : _tocar,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _tocar,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 7),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(VecRadios.pildora),
            boxShadow: VecSombras.chip,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: VecColores.papel),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: VecFuentes.titulo,
                  fontSize: 16,
                  color: VecColores.papel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
