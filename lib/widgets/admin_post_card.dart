/// ═══════════════════════════════════════════════════════════════════════════
/// ADMIN POST CARD - Tarjeta de moderación para admin
/// Muestra: cuerpo completo, alias, gigante, fecha, abuseHash,
/// botones de aprobar/rechazar/banear.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../models/wall_post.dart';
import '../models/content_enums.dart';
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
    return _buildPapel(giant);
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


  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Mini action button
// ═══════════════════════════════════════════════════════════════════════════


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
