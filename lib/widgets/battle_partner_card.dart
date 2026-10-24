/// ═══════════════════════════════════════════════════════════════════════════
/// BATTLE PARTNER CARD - Tarjeta de cada compañero de batalla
/// Muestra: nombre, racha, victoria o gracia de HOY (del compañero), estado
/// inactivo, Escudo (si lo comparte), botón de ánimo y menú de opciones.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../models/battle_partner_data.dart';
import '../services/feedback_engine.dart';
import '../theme/app_theme_data.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';
import 'sticker_picker_sheet.dart';

/// Texto del estado de hoy del compañero (también para lectores de pantalla).
String textoEstadoCompanero(BattlePartnerData partner, {DateTime? ahora}) {
  if (partner.isInactive) {
    final dias = partner.inactiveDays;
    return dias <= 0
        ? 'Hace tiempo que no entra'
        : '$dias ${dias == 1 ? 'día' : 'días'} sin entrar';
  }
  switch (partner.estadoHoy(ahora: ahora)) {
    case EstadoHoyCompanero.victoria:
      return 'Victoria hoy · ${partner.streakDays} '
          '${partner.streakDays == 1 ? 'día' : 'días'}';
    case EstadoHoyCompanero.gracia:
      return 'Hoy registró gracia';
    case EstadoHoyCompanero.sinRegistro:
      return 'Sin registrar hoy';
  }
}

class BattlePartnerCard extends StatelessWidget {
  final BattlePartnerData partner;

  /// Liberar al compañero (menú "⋮" y pulsación larga).
  final VoidCallback? onRemove;

  /// Avisos del Escudo y resumen semanal para este compañero.
  final VoidCallback? onAjustes;

  /// Solo para pruebas: "ahora" fijo.
  final DateTime? ahora;

  const BattlePartnerCard({
    super.key,
    required this.partner,
    this.onRemove,
    this.onAjustes,
    this.ahora,
  });

  @override
  Widget build(BuildContext context) {
    return _buildPapel(context);
  }


  /// Tarjeta de papel con inicial en círculo, racha en terracota
  /// y botón de ánimo en píldora.
  Widget _buildPapel(BuildContext context) {
    final inactivo = partner.isInactive;
    final estado = partner.estadoHoy(ahora: ahora);
    final textoEstado = textoEstadoCompanero(partner, ahora: ahora);
    final escudo = partner.shieldShared && partner.shieldOn != null
        ? (partner.shieldOn! ? 'Escudo activo' : 'Escudo apagado')
        : null;
    return Semantics(
      label: '${partner.name}. $textoEstado'
          '${escudo == null ? '' : '. $escudo'}',
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
                      textoEstado,
                      style: TextStyle(
                        fontFamily: VecFuentes.texto,
                        fontSize: 16,
                        color: inactivo
                            ? VecColores.mostaza
                            : estado == EstadoHoyCompanero.victoria
                            ? VecColores.verde
                            : VecColores.gris,
                      ),
                    ),
                    if (escudo != null)
                      Text(
                        escudo,
                        style: TextStyle(
                          fontFamily: VecFuentes.texto,
                          fontSize: 15,
                          color: partner.shieldOn!
                              ? VecColores.azul
                              : VecColores.terracota,
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
              if (onRemove != null || onAjustes != null)
                PopupMenuButton<_OpcionCompanero>(
                  tooltip: 'Opciones para ${partner.name}',
                  icon: Icon(Icons.more_vert_rounded, color: VecColores.tinta),
                  onSelected: (opcion) {
                    switch (opcion) {
                      case _OpcionCompanero.ajustes:
                        onAjustes?.call();
                      case _OpcionCompanero.liberar:
                        onRemove?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    if (onAjustes != null)
                      const PopupMenuItem(
                        value: _OpcionCompanero.ajustes,
                        child: ListTile(
                          leading: Icon(Icons.tune_rounded),
                          title: Text('Avisos y resumen semanal'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (onRemove != null)
                      const PopupMenuItem(
                        value: _OpcionCompanero.liberar,
                        child: ListTile(
                          leading: Icon(Icons.link_off_rounded),
                          title: Text('Liberar compañero'),
                          contentPadding: EdgeInsets.zero,
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
}

enum _OpcionCompanero { ajustes, liberar }
