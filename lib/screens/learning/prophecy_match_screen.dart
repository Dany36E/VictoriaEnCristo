/// ═══════════════════════════════════════════════════════════════════════════
/// ProphecyMatchScreen — conectar profecías AT con su cumplimiento en NT.
///
/// UI: dos columnas.
///   Izquierda: tarjetas de profecía (fijas)
///   Derecha: fichas draggables con los cumplimientos (mezcladas)
/// El usuario arrastra cada cumplimiento hacia la profecía correspondiente.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/prophecy_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/prophecy_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class ProphecyMatchScreen extends StatefulWidget {
  final ProphecyRound round;
  const ProphecyMatchScreen({super.key, required this.round});

  @override
  State<ProphecyMatchScreen> createState() => _ProphecyMatchScreenState();
}

class _ProphecyMatchScreenState extends State<ProphecyMatchScreen> {
  // pairId -> droppedFulfillmentId
  final Map<String, String?> _placed = {};
  late List<ProphecyPair> _bank; // fichas aún en el banco
  int _errors = 0;
  bool _done = false;
  int _awardedXp = 0;
  int _stars = 0;

  ProphecyRound get r => widget.round;

  @override
  void initState() {
    super.initState();
    for (final p in r.pairs) {
      _placed[p.id] = null;
    }
    _bank = [...r.pairs]..shuffle();
  }

  void _onAccept(String pairId, ProphecyPair dragged) {
    final correct = dragged.id == pairId;
    FeedbackEngine.I.confirm();
    if (!correct) {
      setState(() => _errors++);
      // No colocar si es incorrecto; la ficha vuelve al banco
      return;
    }
    setState(() {
      _placed[pairId] = dragged.id;
      _bank.removeWhere((e) => e.id == dragged.id);
    });
    if (_bank.isEmpty) _finish();
  }

  Future<void> _finish() async {
    final totalPairs = r.pairs.length;
    // Estrellas según errores: 0 errs=3★, ≤2=2★, resto 1★
    int stars;
    if (_errors == 0) {
      stars = 3;
    } else if (_errors <= (totalPairs * 0.3).ceil()) {
      stars = 2;
    } else {
      stars = 1;
    }
    final xp = await ProphecyProgressService.I.recordRound(
      roundId: r.id,
      stars: stars,
      xpReward: r.xpReward,
    );
    if (!mounted) return;
    setState(() {
      _done = true;
      _stars = stars;
      _awardedXp = xp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          r.title,
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: _done ? _buildResult(t) : _buildGame(t),
    );
  }

  Widget _buildGame(AppThemeData t) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          color: t.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.description,
                style: AppDesignSystem.bodyMedium(context,
                    color: t.textSecondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Errores: $_errors',
                    style: AppDesignSystem.labelMedium(context,
                        color: _errors == 0
                            ? AppDesignSystem.gold
                            : const Color(0xFFE58E73)),
                  ),
                  const Spacer(),
                  Text(
                    'Colocados: ${r.pairs.length - _bank.length}/${r.pairs.length}',
                    style: AppDesignSystem.labelMedium(context,
                        color: AppDesignSystem.gold),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Columna izquierda: profecías con DragTarget
              Expanded(
                flex: 5,
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingS),
                  itemCount: r.pairs.length,
                  itemBuilder: (context, i) {
                    final p = r.pairs[i];
                    final placedId = _placed[p.id];
                    return _prophecySlot(t, p, placedId);
                  },
                ),
              ),
              Container(width: 1, color: t.cardBorder),
              // Columna derecha: banco de cumplimientos
              Expanded(
                flex: 4,
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingS),
                  itemCount: _bank.length,
                  itemBuilder: (context, i) {
                    final p = _bank[i];
                    return _fulfillmentCard(t, p);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _prophecySlot(
      AppThemeData t, ProphecyPair p, String? placedId) {
    final matched = placedId != null;
    return DragTarget<ProphecyPair>(
      onWillAcceptWithDetails: (d) => !matched,
      onAcceptWithDetails: (d) => _onAccept(p.id, d.data),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(AppDesignSystem.spacingS),
          decoration: BoxDecoration(
            color: matched
                ? const Color(0xFF1F3A1F)
                : highlight
                    ? AppDesignSystem.gold.withOpacity(0.1)
                    : t.cardBg,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
            border: Border.all(
              color: matched
                  ? const Color(0xFF4CAF50)
                  : highlight
                      ? AppDesignSystem.gold
                      : t.cardBorder,
              width: matched || highlight ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    p.topic,
                    style: AppDesignSystem.labelSmall(context,
                        color: AppDesignSystem.gold),
                  ),
                  const Spacer(),
                  if (matched)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF4CAF50), size: 16),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                p.prophecyRef,
                style: AppDesignSystem.labelSmall(context,
                    color: t.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '"${p.prophecyText}"',
                style: AppDesignSystem.bodyMedium(context,
                    color: t.textPrimary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (matched) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius:
                        BorderRadius.circular(AppDesignSystem.radiusM),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.fulfillmentRef,
                        style: AppDesignSystem.labelSmall(context,
                            color: const Color(0xFF8FD98F)),
                      ),
                      Text(
                        '"${p.fulfillmentText}"',
                        style: AppDesignSystem.bodyMedium(context,
                            color: t.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _fulfillmentCard(AppThemeData t, ProphecyPair p) {
    final body = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppDesignSystem.spacingS),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.fulfillmentRef,
            style: AppDesignSystem.labelSmall(context,
                color: AppDesignSystem.gold),
          ),
          const SizedBox(height: 4),
          Text(
            '"${p.fulfillmentText}"',
            style: AppDesignSystem.bodyMedium(context,
                color: t.textPrimary),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return LongPressDraggable<ProphecyPair>(
      data: p,
      delay: const Duration(milliseconds: 80),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.42,
          child: Opacity(opacity: 0.9, child: body),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: body),
      onDragStarted: () => FeedbackEngine.I.tap(),
      child: body,
    );
  }

  Widget _buildResult(AppThemeData t) {
    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome_rounded,
                  color: AppDesignSystem.gold, size: 80)
              .animate()
              .scale(
                  begin: const Offset(0.3, 0.3),
                  duration: 500.ms,
                  curve: Curves.elasticOut),
          const SizedBox(height: AppDesignSystem.spacingM),
          Text(
            '¡Profecías conectadas!',
            style: AppDesignSystem.headlineMedium(context,
                color: t.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = i < _stars;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 40,
                  color:
                      filled ? AppDesignSystem.gold : t.textSecondary,
                ),
              );
            }),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Text(
            'Errores: $_errors',
            style: AppDesignSystem.bodyMedium(context,
                color: t.textSecondary),
          ),
          if (_awardedXp > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+$_awardedXp XP',
                style: AppDesignSystem.headlineSmall(context,
                    color: AppDesignSystem.gold),
              ),
            ),
          const SizedBox(height: AppDesignSystem.spacingL),
          SizedBox(
            width: double.infinity,
            child: PremiumButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ),
        ],
      ),
    );
  }
}
