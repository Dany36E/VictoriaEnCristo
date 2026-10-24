/// Tarjeta "Día de gracia": usar el token del mes para proteger la racha.
///
/// Reglas (las aplica VictoryScoringService.diaParaGracia):
/// - 1 día de gracia por mes; se renueva el día 1 y no se acumula.
/// - Cubre ayer o anteayer, nunca hoy (hoy todavía puedes registrar).
/// - Solo si ese día rompió una racha que venía de victoria.
library;

import 'package:flutter/material.dart';

import '../services/feedback_engine.dart';
import '../services/victory_scoring_service.dart';
import '../theme/app_theme_data.dart';

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _fechaLarga(DateTime d) => '${d.day} de ${_meses[d.month - 1]}';

class DiaDeGraciaCard extends StatefulWidget {
  const DiaDeGraciaCard({super.key, this.alUsar});

  /// Se llama después de usar el día de gracia (para refrescar la pantalla).
  final VoidCallback? alUsar;

  @override
  State<DiaDeGraciaCard> createState() => _DiaDeGraciaCardState();
}

class _DiaDeGraciaCardState extends State<DiaDeGraciaCard> {
  bool _usando = false;

  Future<void> _usar(DateTime dia) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Usar tu día de gracia?'),
        content: Text(
          'Cubrirá el ${_fechaLarga(dia)} y tu racha seguirá. Tienes uno '
          'por mes; el próximo llega el día 1.\n\n'
          'La gracia no es permiso para rendirse: es una mano para '
          'levantarte y seguir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usar día de gracia'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _usando = true);
    final usado = await VictoryScoringService.I.useGraceToken(dia);
    if (!mounted) return;
    setState(() => _usando = false);
    if (usado) FeedbackEngine.I.confirm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          usado
              ? 'Tu racha sigue: ${VictoryScoringService.I.getCurrentStreak()} '
                    'días. Sigue adelante.'
              : 'No se pudo usar el día de gracia ahora.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.alUsar?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scoring = VictoryScoringService.I;
    return ValueListenableBuilder<int>(
      valueListenable: scoring.graceTokensNotifier,
      builder: (context, tokens, _) {
        final t = AppThemeData.of(context);
        final dia = scoring.diaParaGracia();
        final quedan = tokens > 0
            ? 'Te queda 1 día de gracia este mes.'
            : 'Ya usaste tu día de gracia de este mes; el próximo llega el día 1.';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: t.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.spa_rounded, color: t.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Día de gracia',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dia != null
                    ? 'El ${_fechaLarga(dia)} quedó sin victoria y rompió tu '
                          'racha. Puedes cubrirlo con tu día de gracia.'
                    : '$quedan Sirve para cubrir ayer o anteayer cuando ese '
                          'día rompería una racha de victoria.',
                style: TextStyle(color: t.textSecondary, height: 1.3),
              ),
              if (dia != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _usando ? null : () => _usar(dia),
                  icon: const Icon(Icons.favorite_rounded),
                  label: const Text('Usar mi día de gracia'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
