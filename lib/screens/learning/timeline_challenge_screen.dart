/// ═══════════════════════════════════════════════════════════════════════════
/// TimelineChallengeScreen — reto de arrastrar personajes a su era correcta
///
/// Carril horizontal scrollable con las eras como DragTargets.
/// Banco inferior con etiquetas arrastrables.
/// Errores ≤ 2% = 3★, ≤ 20% = 2★, resto 1★.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/timeline_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/timeline_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class TimelineChallengeScreen extends StatefulWidget {
  final TimelineLesson lesson;
  const TimelineChallengeScreen({super.key, required this.lesson});

  @override
  State<TimelineChallengeScreen> createState() =>
      _TimelineChallengeScreenState();
}

class _TimelineChallengeScreenState extends State<TimelineChallengeScreen> {
  // itemId -> eraId where it was correctly placed (null if still in bank)
  final Map<String, String> _placed = {};
  int _errors = 0;
  bool _completed = false;
  int _stars = 0;
  int _xpEarned = 0;

  TimelineLesson get lesson => widget.lesson;

  List<TimelineItem> get _bankItems =>
      lesson.items.where((it) => !_placed.containsKey(it.id)).toList();

  List<TimelineItem> _itemsInEra(String eraId) =>
      lesson.items.where((it) => _placed[it.id] == eraId).toList();

  void _onDropped(TimelineItem item, String eraId) {
    if (_placed.containsKey(item.id)) return;
    if (item.eraId == eraId) {
      FeedbackEngine.I.confirm();
      setState(() => _placed[item.id] = eraId);
      _checkCompletion();
    } else {
      FeedbackEngine.I.tap();
      setState(() => _errors++);
    }
  }

  void _checkCompletion() {
    if (_placed.length >= lesson.items.length) {
      final total = lesson.items.length;
      final ratio = total == 0 ? 0 : _errors / total;
      _stars = ratio <= 0.05
          ? 3
          : ratio <= 0.25
              ? 2
              : 1;
      _complete();
    }
  }

  Future<void> _complete() async {
    final xp = await TimelineProgressService.I
        .markCompleted(lesson.id, _stars, lesson.xpReward);
    if (!mounted) return;
    setState(() {
      _completed = true;
      _xpEarned = xp;
    });
    FeedbackEngine.I.confirm();
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
          lesson.title,
          style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
        ),
        actions: [
          if (!_completed)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_placed.length}/${lesson.items.length}',
                  style: AppDesignSystem.labelMedium(
                    context,
                    color: AppDesignSystem.gold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _completed ? _buildComplete(t) : _buildBoard(t),
    );
  }

  Widget _buildBoard(AppThemeData t) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDesignSystem.spacingM,
              vertical: AppDesignSystem.spacingS),
          child: Row(
            children: [
              const Icon(Icons.touch_app_rounded,
                  color: AppDesignSystem.gold, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Arrastra cada nombre a su era correcta',
                  style: AppDesignSystem.bodyMedium(
                      context, color: t.textSecondary),
                ),
              ),
              if (_errors > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius:
                        BorderRadius.circular(AppDesignSystem.radiusFull),
                  ),
                  child: Text(
                    '$_errors err',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDesignSystem.spacingM),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < lesson.eras.length; i++) ...[
                  _buildEraColumn(lesson.eras[i], t),
                  if (i < lesson.eras.length - 1)
                    Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 30),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppDesignSystem.gold.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: Container(
            color: t.surface,
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Banco',
                  style: AppDesignSystem.labelMedium(
                      context, color: t.textSecondary),
                ),
                const SizedBox(height: AppDesignSystem.spacingS),
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _bankItems
                          .map((it) => _buildDraggable(it, t))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEraColumn(TimelineEra era, AppThemeData t) {
    final placed = _itemsInEra(era.id);
    return DragTarget<TimelineItem>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _onDropped(d.data, era.id),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return Container(
          width: 220,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: highlighted
                ? AppDesignSystem.gold.withOpacity(0.12)
                : t.cardBg,
            borderRadius:
                BorderRadius.circular(AppDesignSystem.radiusL),
            border: Border.all(
              color: highlighted
                  ? AppDesignSystem.gold
                  : t.cardBorder,
              width: highlighted ? 2 : 1,
            ),
            boxShadow: t.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 18, color: AppDesignSystem.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      era.label,
                      style: AppDesignSystem.headlineSmall(
                        context,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                era.range,
                style: AppDesignSystem.labelSmall(
                    context, color: AppDesignSystem.gold),
              ),
              if (era.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  era.description,
                  style: AppDesignSystem.bodyMedium(
                      context, color: t.textSecondary),
                ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: placed
                      .map((it) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.gold.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(
                                  AppDesignSystem.radiusM),
                              border: Border.all(
                                color: AppDesignSystem.gold.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 16, color: AppDesignSystem.gold),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    it.name,
                                    style: const TextStyle(
                                      color: AppDesignSystem.gold,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 250.ms).scale(
                              begin: const Offset(0.8, 0.8),
                              duration: 250.ms))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggable(TimelineItem it, AppThemeData t) {
    return Draggable<TimelineItem>(
      data: it,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppDesignSystem.gold,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
            boxShadow: [
              BoxShadow(
                color: AppDesignSystem.gold.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            it.name,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _pill(it.name, t, selected: false),
      ),
      child: Tooltip(
        message: it.hint,
        child: _pill(it.name, t, selected: false),
      ),
    );
  }

  Widget _pill(String label, AppThemeData t, {required bool selected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppDesignSystem.gold
            : t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        border: Border.all(
          color: selected
              ? AppDesignSystem.gold
              : AppDesignSystem.gold.withOpacity(0.4),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : t.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildComplete(AppThemeData t) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded,
                    color: AppDesignSystem.gold, size: 80)
                .animate()
                .scale(
                    begin: const Offset(0.3, 0.3),
                    duration: 500.ms,
                    curve: Curves.elasticOut),
            const SizedBox(height: AppDesignSystem.spacingL),
            Text(
              '¡Línea del tiempo armada!',
              style: AppDesignSystem.headlineMedium(context,
                  color: t.textPrimary),
            ),
            const SizedBox(height: AppDesignSystem.spacingM),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < _stars;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppDesignSystem.gold,
                    size: 48,
                  ).animate().scale(
                      delay: (200 + 120 * i).ms,
                      duration: 300.ms,
                      curve: Curves.elasticOut),
                );
              }),
            ),
            const SizedBox(height: AppDesignSystem.spacingM),
            Text(
              _errors == 0
                  ? '¡Sin errores! Memoria de maestro.'
                  : '$_errors intento${_errors == 1 ? '' : 's'} fallido${_errors == 1 ? '' : 's'}',
              style: AppDesignSystem.bodyMedium(context,
                  color: t.textSecondary),
            ),
            if (_xpEarned > 0) ...[
              const SizedBox(height: AppDesignSystem.spacingL),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppDesignSystem.gold.withOpacity(0.18),
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.radiusFull),
                  border: Border.all(
                      color: AppDesignSystem.gold.withOpacity(0.5)),
                ),
                child: Text(
                  '+$_xpEarned XP',
                  style: const TextStyle(
                    color: AppDesignSystem.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms).scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 400.ms,
                  curve: Curves.easeOut),
            ],
            const SizedBox(height: AppDesignSystem.spacingXL),
            SizedBox(
              width: double.infinity,
              child: PremiumButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Volver'),
              ),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}
