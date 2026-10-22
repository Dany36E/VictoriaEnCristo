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
import '../theme/app_theme_data.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';

/// Ícono del kit para cada mensaje (en lugar de emojis).
const Map<String, String> _iconosMensajePapel = {
  'praying_for_you': 'orar',
  'well_done_soldier': 'escudo',
  'not_alone': 'personas',
  'keep_going': 'mano_alto',
  'god_with_you': 'cruz',
  'im_here': 'manos',
  'proud_of_you': 'corazones',
  'stand_firm': 'escudo',
  'with_you': 'personas',
  'loved_as_you_are': 'corazon',
  'rest_in_him': 'sol',
  'thinking_of_you': 'corazones',
  'sos_prayer': 'mano_alto',
};

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
    return _buildPapel(context, remaining, isLimited);
  }

  /// Hoja de papel con los mensajes como tarjetas con ícono del kit.
  Widget _buildPapel(BuildContext context, int remaining, bool isLimited) {
    return Container(
      decoration: BoxDecoration(
        color: VecColores.papel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(VecRadios.l)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: VecColores.cremaOscuro,
              borderRadius: BorderRadius.circular(VecRadios.pildora),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TituloVec(
              'Enviar ánimo a $toName',
              clave: toName,
              tamano: 22,
              alineacion: TextAlign.center,
            ),
          ),
          if (isLimited)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VecColores.mostaza.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(VecRadios.s),
                ),
                child: Row(
                  children: [
                    CirculoIcono(iconoVec: 'reloj', color: VecColores.mostaza, tamano: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ya enviaste ánimo hoy. Vuelve mañana.',
                        style: TextStyle(
                          fontFamily: VecFuentes.texto,
                          fontSize: 16,
                          color: VecColores.tinta,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
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
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '$remaining mensaje${remaining == 1 ? '' : 's'} restante${remaining == 1 ? '' : 's'} hoy',
                style: TextStyle(
                  fontFamily: VecFuentes.texto,
                  fontSize: 15,
                  color: VecColores.gris,
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
    _showFlyingStickerOverlay(
      context,
      msg.icon,
      iconoPapel: _iconosMensajePapel[msg.key] ?? 'corazon',
    );
    final sent = await BattlePartnerService.I.sendMessage(toUid, msg.key);
    if (context.mounted) {
      Navigator.pop(context, sent);
      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Mensaje enviado a $toName',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Overlay breve con el emoji del sticker creciendo y desvaneciéndose.
  /// 100% visual, no bloquea navegación ni el envío Firestore.
  void _showFlyingStickerOverlay(
    BuildContext context,
    String icon, {
    String? iconoPapel,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FlyingStickerOverlay(
        icon: icon,
        iconoPapel: iconoPapel,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _FlyingStickerOverlay extends StatefulWidget {
  final String icon;
  final String? iconoPapel; // ícono del kit
  final VoidCallback onDone;
  const _FlyingStickerOverlay({
    required this.icon,
    this.iconoPapel,
    required this.onDone,
  });
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
                    child: widget.iconoPapel != null
                        ? CirculoIcono(
                            iconoVec: widget.iconoPapel,
                            tamano: 72,
                            giro: -6,
                          )
                        : Text(
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
    return Semantics(
      button: true,
      enabled: enabled,
      label: message.text,
      onTap: enabled ? () { FeedbackEngine.I.select(); onTap(); } : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? () { FeedbackEngine.I.select(); onTap(); } : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: AppThemeData.of(context).cardDecoration,
            child: Row(
              children: [
                CirculoIcono(
                  iconoVec: _iconosMensajePapel[message.key] ?? 'corazon',
                  color: VecColores.azulClaro,
                  tamano: 36,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.textoSinEmoji,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: VecFuentes.texto,
                      fontSize: 15,
                      height: 1.1,
                      color: VecColores.tinta,
                    ),
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
