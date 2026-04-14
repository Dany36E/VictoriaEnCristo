/// ═══════════════════════════════════════════════════════════════════════════
/// BATTLE PARTNER CARD - Tarjeta de cada compañero de batalla
/// Muestra: nombre, racha, victoria hoy, estado inactivo, botón de ánimo
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../models/battle_partner_data.dart';
import '../services/feedback_engine.dart';
import '../theme/app_theme.dart';
import 'sticker_picker_sheet.dart';

class BattlePartnerCard extends StatelessWidget {
  final BattlePartnerData partner;
  final VoidCallback? onRemove;

  const BattlePartnerCard({
    super.key,
    required this.partner,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isInactive = partner.isInactive;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInactive
              ? Colors.orange.withOpacity(0.2)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () { FeedbackEngine.I.tap(); },
          onLongPress: onRemove,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                _buildAvatar(),
                const SizedBox(width: 12),

                // Info
                Expanded(child: _buildInfo()),

                // Botón de ánimo
                _buildEncourageButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: partner.isInactive
              ? [Colors.grey.shade700, Colors.grey.shade800]
              : [AppDesignSystem.gold.withOpacity(0.3), AppDesignSystem.goldDark.withOpacity(0.2)],
        ),
        border: Border.all(
          color: partner.isInactive
              ? Colors.grey.withOpacity(0.3)
              : AppDesignSystem.gold.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          partner.name.isNotEmpty ? partner.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: partner.isInactive ? Colors.grey : AppDesignSystem.gold,
          ),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                partner.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (partner.isInactive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${partner.inactiveDays}d inactivo',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          partner.victoryToday ? '⭐ Victoria hoy' : '✝️ Sin registrar',
          style: TextStyle(
            fontSize: 12,
            color: partner.victoryToday
                ? AppDesignSystem.victory
                : Colors.white.withOpacity(0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEncourageButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          FeedbackEngine.I.tap();
          StickerPickerSheet.show(
            context,
            toUid: partner.uid,
            toName: partner.name,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppDesignSystem.gold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppDesignSystem.gold.withOpacity(0.25)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('💬', style: TextStyle(fontSize: 16)),
              SizedBox(height: 2),
              Text(
                'Ánimo',
                style: TextStyle(
                  fontSize: 9,
                  color: AppDesignSystem.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
