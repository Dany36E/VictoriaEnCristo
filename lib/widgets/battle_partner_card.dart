/// ═══════════════════════════════════════════════════════════════════════════
/// BATTLE PARTNER CARD - Tarjeta de cada compañero de batalla
/// Muestra: nombre, racha, victoria hoy, estado inactivo, botón de ánimo
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../models/battle_partner_data.dart';
import '../services/feedback_engine.dart';
import '../theme/app_theme_data.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';
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
    return _buildPapel(context);
  }


  /// Tema papel: tarjeta de papel con inicial en círculo, racha en terracota
  /// y botón de ánimo en píldora.
  Widget _buildPapel(BuildContext context) {
    final inactivo = partner.isInactive;
    return Semantics(
      label: '${partner.name}. '
          '${partner.victoryToday ? 'Victoria hoy' : 'Sin registrar hoy'}',
      child: GestureDetector(
        onTap: FeedbackEngine.I.tap,
        onLongPress: onRemove,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: AppThemeData.of(context).cardDecoration,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: inactivo ? VecColores.gris : VecColores.azul,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x402B2622), offset: Offset(0, 5)),
                  ],
                ),
                child: Text(
                  partner.name.isNotEmpty ? partner.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontFamily: VecFuentes.titulo,
                    fontSize: 22,
                    color: VecColores.papel,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: VecFuentes.titulo,
                        fontSize: 19,
                        color: VecColores.tinta,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inactivo
                          ? '${partner.inactiveDays} días sin entrar'
                          : partner.victoryToday
                          ? 'Victoria hoy · ${partner.streakDays} días'
                          : 'Sin registrar hoy',
                      style: TextStyle(
                        fontFamily: VecFuentes.texto,
                        fontSize: 16,
                        color: inactivo
                            ? VecColores.mostaza
                            : partner.victoryToday
                            ? VecColores.verde
                            : VecColores.gris,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Enviar ánimo a ${partner.name}',
                child: GestureDetector(
                  onTap: () {
                    FeedbackEngine.I.tap();
                    StickerPickerSheet.show(
                      context,
                      toUid: partner.uid,
                      toName: partner.name,
                    );
                  },
                  child: ChipVec(
                    texto: 'Ánimo',
                    color: VecColores.terracota,
                    iconoWidget: IconoVec('mensaje', color: VecColores.papel),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
