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
  // PAPEL RECORTADO — Jesús sobre la escena de la racha, enmarcada como foto de papel
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPapel(BuildContext context) {
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
            child: TarjetaRachaPapel(
              streakDays: streakDays,
              completedToday: completedToday,
              victoryToday: victoryToday,
              isNewUser: isNewUser,
              isLoading: isLoading,
              checkinDone: checkinDone,
              onRegisterVictory: onRegisterVictory,
            ),
          ),
        ),
      ),
    );
  }
}

/// Contenido de la tarjeta de racha «Papel recortado», sin animación ni
/// gestos: la usa Inicio y también el widget de Android, que la dibuja a
/// imagen para que se vea igual que dentro de la app.
class TarjetaRachaPapel extends StatelessWidget {
  const TarjetaRachaPapel({
    super.key,
    required this.streakDays,
    required this.completedToday,
    required this.victoryToday,
    required this.isNewUser,
    this.isLoading = false,
    this.checkinDone = false,
    this.puedeRegistrar,
    this.mensaje,
    this.apaisada = false,
    required this.onRegisterVictory,
  });

  final int streakDays;
  final bool completedToday;
  final bool victoryToday;
  final bool isNewUser;
  final bool isLoading;
  final bool checkinDone;

  /// Si se puede registrar el día ahora. Por defecto lo decide
  /// [VictoryScoringService]; el widget lo fija para la imagen de mañana.
  final bool? puedeRegistrar;

  /// Mensaje bajo la racha. Por defecto el de [JesusWidgetService].
  final String? mensaje;

  /// Escena, racha, mensaje y botón en una fila (widget ancho de 4×2).
  final bool apaisada;
  final VoidCallback? onRegisterVictory;

  /// Texto del botón: el mismo en la app y en el widget.
  static String etiquetaBoton({
    required bool completedToday,
    required bool victoryToday,
    required bool canRegister,
    required bool isNewUser,
    required bool checkinDone,
  }) {
    if (completedToday) {
      return victoryToday ? 'Ver mi progreso' : 'Gracia registrada';
    }
    if (canRegister) return 'Registrar día';
    return JesusWidgetService.I.getBadgeText(
      completedToday: completedToday,
      victoryToday: victoryToday,
      isNewUser: isNewUser,
      checkinDone: checkinDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final message =
        mensaje ??
        JesusWidgetService.I.getMessage(
          streakDays: streakDays,
          completedToday: completedToday,
          victoryToday: victoryToday,
          isNewUser: isNewUser,
        );
    final canRegister =
        puedeRegistrar ??
        (!completedToday && VictoryScoringService.I.canLogVictoryNow());
    final label = etiquetaBoton(
      completedToday: completedToday,
      victoryToday: victoryToday,
      canRegister: canRegister,
      isNewUser: isNewUser,
      checkinDone: checkinDone,
    );
    final dias = isNewUser ? 0 : streakDays;

    final racha = isLoading
        ? const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 4),
          )
        : Row(
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
                      fontSize: apaisada ? 50 : 64,
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
                  dias == 1 ? 'día de\nvictoria' : 'días de\nvictoria',
                  style: TextStyle(
                    fontFamily: VecFuentes.titulo,
                    fontSize: apaisada ? 15 : 17,
                    height: 1.05,
                    color: VecColores.tinta,
                  ),
                ),
              ),
              if (apaisada && completedToday && !isLoading) ...[
                const SizedBox(width: 8),
                Flexible(child: _chipHoy()),
              ],
            ],
          );

    final boton = BotonVec(
      texto: label,
      expandido: true,
      iconoWidget: IconoVec(completedToday ? 'corazon' : 'escudo'),
      color: completedToday ? VecColores.azul : VecColores.terracota,
      onPressed: isLoading ? null : onRegisterVictory,
    );

    final texto = Text(
      message,
      maxLines: apaisada ? 2 : 4,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: VecFuentes.texto,
        fontSize: apaisada ? 16 : 18,
        height: apaisada ? 1.15 : 1.25,
        color: VecColores.tinta,
      ),
    );

    if (apaisada) {
      return TarjetaPapel(
        giro: 0,
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          children: [
            EscenaRachaPapel(
              streakDays: streakDays,
              completedToday: completedToday && victoryToday,
              isNewUser: isNewUser,
              ancho: 100,
              alto: 146,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  racha,
                  const SizedBox(height: 4),
                  texto,
                  const SizedBox(height: 8),
                  boton,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return TarjetaPapel(
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
                    racha,
                    if (completedToday && !isLoading) ...[
                      const SizedBox(height: 8),
                      // Junto a la escena queda poco ancho: en
                      // pantallas chicas el chip se achica.
                      _chipHoy(),
                    ],
                    const SizedBox(height: 10),
                    texto,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          boton,
        ],
      ),
    );
  }

  Widget _chipHoy() => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: ChipVec(
      texto: victoryToday ? 'Hoy ✓' : 'Con gracia',
      color: VecColores.verde,
      iconoWidget: IconoVec('palomita', color: VecColores.papel),
    ),
  );
}
