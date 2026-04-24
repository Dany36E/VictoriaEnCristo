/// ═══════════════════════════════════════════════════════════════════════════
/// STICKER PICKER SHEET - Grid de stickers espirituales predefinidos
/// Solo 8 mensajes permitidos. Sin texto libre.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/battle_messages.dart';
import '../services/battle_partner_service.dart';
import '../services/feedback_engine.dart';
import '../theme/app_theme.dart';

class StickerPickerSheet extends StatelessWidget {
  final String toUid;
  final String toName;

  const StickerPickerSheet({
    super.key,
    required this.toUid,
    required this.toName,
  });

  static Future<bool?> show(BuildContext context, {required String toUid, required String toName}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StickerPickerSheet(toUid: toUid, toName: toName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = BattlePartnerService.I.remainingMessagesToday(toUid);
    final isLimited = remaining <= 0;

    return Container(
      decoration: BoxDecoration(
        color: AppDesignSystem.midnightLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppDesignSystem.gold.withOpacity(0.3)),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Enviar ánimo a $toName',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),

          if (isLimited)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ya enviaste ánimo hoy. Vuelve mañana.',
                        style: TextStyle(fontSize: 13, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Grid 2x4
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: kBattleMessagesSelectable.length,
              itemBuilder: (context, index) {
                final msg = kBattleMessagesSelectable[index];
                return _StickerButton(
                  message: msg,
                  enabled: !isLimited,
                  onTap: () => _sendSticker(context, msg),
                );
              },
            ),
          ),

          if (!isLimited)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$remaining mensaje${remaining == 1 ? '' : 's'} restante${remaining == 1 ? '' : 's'} hoy',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _sendSticker(BuildContext context, BattleMessage msg) async {
    FeedbackEngine.I.confirm();
    // Pequeña animación de "vuelo": overlay con el icono creciendo y
    // desvaneciéndose (200ms) para dar sensación de envío.
    _showFlyingStickerOverlay(context, msg.icon);
    final sent = await BattlePartnerService.I.sendMessage(toUid, msg.key);
    if (context.mounted) {
      Navigator.pop(context, sent);
      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${msg.icon} Mensaje enviado a $toName'),
            backgroundColor: AppDesignSystem.midnightLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  /// Overlay breve con el emoji del sticker creciendo y desvaneciéndose.
  /// 100% visual, no bloquea navegación ni el envío Firestore.
  void _showFlyingStickerOverlay(BuildContext context, String icon) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FlyingStickerOverlay(
        icon: icon,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _FlyingStickerOverlay extends StatefulWidget {
  final String icon;
  final VoidCallback onDone;
  const _FlyingStickerOverlay({required this.icon, required this.onDone});
  @override
  State<_FlyingStickerOverlay> createState() => _FlyingStickerOverlayState();
}

class _FlyingStickerOverlayState extends State<_FlyingStickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward().whenComplete(widget.onDone);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = Curves.easeOutCubic.transform(_c.value);
          final size = MediaQuery.of(context).size;
          return Stack(
            children: [
              Positioned(
                left: size.width / 2 - 40,
                top: size.height * (0.55 - 0.45 * t),
                child: Opacity(
                  opacity: 1.0 - t,
                  child: Transform.scale(
                    scale: 1.0 + 0.6 * t,
                    child: Text(
                      widget.icon,
                      style: const TextStyle(fontSize: 56),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StickerButton extends StatelessWidget {
  final BattleMessage message;
  final bool enabled;
  final VoidCallback onTap;

  const _StickerButton({
    required this.message,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () { FeedbackEngine.I.select(); onTap(); } : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Text(message.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(enabled ? 0.9 : 0.5),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
