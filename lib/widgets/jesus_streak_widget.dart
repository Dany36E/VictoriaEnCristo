/// ═══════════════════════════════════════════════════════════════════════════
/// JESUS STREAK WIDGET - Widget de racha con sprite de Jesús estilo Duolingo
/// Muestra sprite animado de Jesús, fondo dinámico y sistema de racha
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../services/jesus_widget_service.dart';
import '../services/victory_scoring_service.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';
import 'escena_racha_papel.dart';

class JesusStreakWidget extends StatelessWidget {
  final int streakDays;
  final bool completedToday;
  final bool victoryToday;
  final bool isNewUser;
  final bool isLoading;
  final bool checkinDone;
  final VoidCallback onRegisterVictory;
  final VoidCallback? onTapCard;

  const JesusStreakWidget({
    super.key,
    required this.streakDays,
    required this.completedToday,
    required this.victoryToday,
    required this.isNewUser,
    this.isLoading = false,
    this.checkinDone = false,
    required this.onRegisterVictory,
    this.onTapCard,
  });

  @override
  Widget build(BuildContext context) {
    return _buildPapel(context);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEMA PAPEL — Jesús sobre la escena de la racha, enmarcada como foto de papel
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPapel(BuildContext context) {
    final message = JesusWidgetService.I.getMessage(
      streakDays: streakDays,
      completedToday: completedToday,
      victoryToday: victoryToday,
      isNewUser: isNewUser,
    );
    final canRegister =
        !completedToday && VictoryScoringService.I.canLogVictoryNow();
    final label = completedToday
        ? victoryToday
              ? 'Ver mi progreso'
              : 'Gracia registrada'
        : canRegister
        ? 'Registrar día'
        : JesusWidgetService.I.getBadgeText(
            completedToday: completedToday,
            victoryToday: victoryToday,
            isNewUser: isNewUser,
            checkinDone: checkinDone,
          );
    final dias = isNewUser ? 0 : streakDays;

    return Semantics(
      label: completedToday
          ? 'Racha actual: $streakDays días. Día de hoy ya registrado.'
          : 'Racha actual: $streakDays días.',
      child: Padding(
        padding: const EdgeInsets.only(top: 22),
        child: PopIn(
          giroFinal: -1,
          child: GestureDetector(
            onTap: onTapCard ?? onRegisterVictory,
            child: TarjetaPapel(
              giro: 0,
              padding: const EdgeInsets.fromLTRB(14, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      EscenaRachaPapel(
                        streakDays: streakDays,
                        completedToday: completedToday && victoryToday,
                        isNewUser: isNewUser,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isLoading)
                              const SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 4,
                                ),
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '$dias',
                                        style: TextStyle(
                                          fontFamily: VecFuentes.titulo,
                                          fontSize: 64,
                                          height: 1,
                                          color: VecColores.terracota,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      dias == 1
                                          ? 'día de\nvictoria'
                                          : 'días de\nvictoria',
                                      style: TextStyle(
                                        fontFamily: VecFuentes.titulo,
                                        fontSize: 17,
                                        height: 1.05,
                                        color: VecColores.tinta,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (completedToday && !isLoading) ...[
                              const SizedBox(height: 8),
                              // Junto a la escena queda poco ancho: en
                              // pantallas chicas el chip se achica.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: ChipVec(
                                  texto: victoryToday ? 'Hoy ✓' : 'Con gracia',
                                  color: VecColores.verde,
                                  iconoWidget: IconoVec(
                                    'palomita',
                                    color: VecColores.papel,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              message,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: VecFuentes.texto,
                                fontSize: 18,
                                height: 1.25,
                                color: VecColores.tinta,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BotonVec(
                    texto: label,
                    expandido: true,
                    iconoWidget: IconoVec(
                      completedToday ? 'corazon' : 'escudo',
                    ),
                    color: completedToday
                        ? VecColores.azul
                        : VecColores.terracota,
                    onPressed: isLoading ? null : onRegisterVictory,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
