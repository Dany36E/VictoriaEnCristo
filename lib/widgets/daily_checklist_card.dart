/// ═══════════════════════════════════════════════════════════════════════════
/// DailyChecklistCard — Checklist "X/4 hoy" con las 4 prácticas espirituales
///
/// Se auto-actualiza vía [DailyPracticeService.snapshotNotifier]. Cuando todas
/// están completas muestra un estado sutilmente dorado (sin confetti — el
/// confetti se reserva para hitos de racha).
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../services/daily_practice_service.dart';
import '../services/feedback_engine.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';

class DailyChecklistCard extends StatefulWidget {
  /// Callbacks para navegar cuando el usuario toca un item no completado.
  final VoidCallback? onTapDevotional;
  final VoidCallback? onTapJournal;
  final VoidCallback? onTapVictory;
  final VoidCallback? onTapStudy;

  const DailyChecklistCard({
    super.key,
    this.onTapDevotional,
    this.onTapJournal,
    this.onTapVictory,
    this.onTapStudy,
  });

  @override
  State<DailyChecklistCard> createState() => _DailyChecklistCardState();
}

class _DailyChecklistCardState extends State<DailyChecklistCard> {
  @override
  void initState() {
    super.initState();
    DailyPracticeService.I.init();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DailyPracticeSnapshot>(
      valueListenable: DailyPracticeService.I.snapshotNotifier,
      builder: (context, snap, _) {
        return _buildPapel(snap);
      },
    );
  }

  /// Tema papel: tarjeta con las 4 prácticas como casillas redondas de la
  /// barra del kit (apagadas en crema; hechas en verde con palomita).
  Widget _buildPapel(DailyPracticeSnapshot snap) {
    final items = [
      (
        'Devocional',
        'biblia',
        snap.devotional,
        DailyPractice.devotional,
        widget.onTapDevotional,
      ),
      (
        'Oración',
        'orar',
        snap.journal,
        DailyPractice.journal,
        widget.onTapJournal,
      ),
      (
        'Victoria',
        'escudo',
        snap.victory,
        DailyPractice.victory,
        widget.onTapVictory,
      ),
      ('Aprender', 'idea', snap.study, DailyPractice.study, widget.onTapStudy),
    ];
    return Semantics(
      label:
          'Prácticas de hoy: ${snap.completedCount} de ${snap.total} completas',
      child: TarjetaPapel(
        giro: 1,
        cintaDerecha: true,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const TituloVec('Prácticas de hoy', clave: 'hoy', tamano: 22),
                const Spacer(),
                ChipVec(
                  texto: '${snap.completedCount}/${snap.total}',
                  color: snap.isComplete
                      ? VecColores.verde
                      : VecColores.mostaza,
                  giro: 2,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final (label, icono, done, practice, onTap) in items)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: done,
                      label: '$label ${done ? 'hecho' : 'pendiente'}',
                      onTap: () => _handleTap(practice, onTap, done),
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleTap(practice, onTap, done),
                        child: Column(
                          children: [
                            CirculoIcono(
                              iconoVec: done ? 'palomita' : icono,
                              color: done
                                  ? VecColores.verde
                                  : VecColores.cremaOscuro,
                              colorIcono: done
                                  ? VecColores.papel
                                  : VecColores.gris,
                              sombra: done,
                              giro: done ? -4 : 0,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: VecFuentes.titulo,
                                fontSize: 14,
                                color: done
                                    ? VecColores.verde
                                    : VecColores.gris,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(
    DailyPractice practice,
    VoidCallback? onTap,
    bool currentlyDone,
  ) {
    FeedbackEngine.I.tap();
    // Si no está hecho y hay acción de navegación asociada, navegamos.
    if (!currentlyDone && onTap != null) {
      onTap();
      return;
    }
    // De lo contrario, toggle manual: permite marcar/desmarcar con tap largo.
    // (tap simple sin onTap = toggle).
    if (currentlyDone) {
      DailyPracticeService.I.unmark(practice);
    } else {
      DailyPracticeService.I.mark(practice);
    }
  }
}

