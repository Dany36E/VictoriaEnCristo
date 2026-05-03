/// ═══════════════════════════════════════════════════════════════════════════
/// JourneyMapScreen — Mapa de la Travesía bíblica
///
/// Muestra las 12 estaciones agrupadas por era. Cada estación puede estar:
///   • Completada (✓ dorado)
///   • Actual / desbloqueada (resaltada)
///   • Bloqueada (candado, apagada)
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/journey_models.dart';
import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/journey_progress_service.dart';
import '../../services/learning/journey_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'journey_station_screen.dart';

class JourneyMapScreen extends StatefulWidget {
  const JourneyMapScreen({super.key});

  @override
  State<JourneyMapScreen> createState() => _JourneyMapScreenState();
}

class _JourneyMapScreenState extends State<JourneyMapScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    AudioEngine.I.switchBgmContext(BgmContext.learningStory);
    _bootstrap();
  }

  @override
  void dispose() {
    AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await JourneyRepository.I.load();
    await JourneyProgressService.I.init();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        title: Text(
          'Travesía Bíblica',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<JourneyProgressState>(
              valueListenable: JourneyProgressService.I.stateNotifier,
              builder: (context, _, _) => _buildBody(context, t),
            ),
    );
  }

  Widget _buildBody(BuildContext context, AppThemeData t) {
    final grouped = JourneyRepository.I.groupedByEra();
    if (grouped.isEmpty) {
      return Center(
        child: Text(
          'No hay estaciones disponibles.',
          style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
        ),
      );
    }

    final total = JourneyRepository.I.all.length;
    final completed = JourneyProgressService.I.completedCount;

    final eraOrder = [JourneyEra.oldTestament, JourneyEra.gospels, JourneyEra.earlyChurch];

    return ListView(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      children: [
        _buildHero(context, t, completed, total),
        const SizedBox(height: AppDesignSystem.spacingL),
        for (final era in eraOrder)
          if (grouped[era]?.isNotEmpty ?? false) ...[
            _eraHeader(context, t, era),
            const SizedBox(height: AppDesignSystem.spacingS),
            for (final s in grouped[era]!) ...[
              _stationTile(context, t, s),
              const SizedBox(height: AppDesignSystem.spacingS),
            ],
            const SizedBox(height: AppDesignSystem.spacingM),
          ],
      ],
    );
  }

  Widget _buildHero(BuildContext context, AppThemeData t, int completed, int total) {
    final pct = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.surface, t.cardBg],
        ),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.25)),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_rounded, color: AppDesignSystem.gold, size: 28),
              const SizedBox(width: AppDesignSystem.spacingS),
              Expanded(
                child: Text(
                  'Camina la historia de Dios',
                  style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            'De la Creación a Pentecostés, un paso a la vez.',
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: t.cardBorder,
              valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingXS),
          Text(
            '$completed de $total estaciones completadas',
            style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _eraHeader(BuildContext context, AppThemeData t, JourneyEra era) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppDesignSystem.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            era.label.toUpperCase(),
            style: AppDesignSystem.labelMedium(
              context,
              color: t.textSecondary,
            ).copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _stationTile(BuildContext context, AppThemeData t, JourneyStation s) {
    final completed = JourneyProgressService.I.isCompleted(s.id);
    final unlocked = JourneyProgressService.I.isUnlocked(s);
    final isCurrent = !completed && unlocked;

    final Color accent = completed
        ? AppDesignSystem.gold
        : isCurrent
        ? AppDesignSystem.gold
        : t.textSecondary;

    final icon = _iconFor(s.icon);

    return Opacity(
      opacity: unlocked ? 1.0 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        onTap: unlocked
            ? () async {
                FeedbackEngine.I.tap();
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => JourneyStationScreen(station: s)),
                );
                if (result == true && mounted) setState(() {});
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
            border: Border.all(
              color: isCurrent ? AppDesignSystem.gold.withOpacity(0.55) : t.cardBorder,
              width: isCurrent ? 1.5 : 1,
            ),
            boxShadow: t.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: accent.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(unlocked ? icon : Icons.lock_outline_rounded, color: accent),
              ),
              const SizedBox(width: AppDesignSystem.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${s.order}. ',
                          style: AppDesignSystem.labelMedium(
                            context,
                            color: t.textSecondary,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        Expanded(
                          child: Text(
                            s.title,
                            style: AppDesignSystem.bodyLarge(
                              context,
                              color: t.textPrimary,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.subtitle,
                      style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDesignSystem.spacingS),
              if (completed)
                const Icon(Icons.check_circle_rounded, color: AppDesignSystem.gold, size: 24)
              else if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.gold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Actual',
                    style: AppDesignSystem.labelSmall(
                      context,
                      color: AppDesignSystem.midnightDeep,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                )
              else
                const Icon(Icons.lock_outline_rounded, size: 20),
            ],
          ),
        ).animate().fadeIn(duration: 280.ms, delay: (40 * s.order).ms).slideY(begin: 0.05, end: 0),
      ),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'brightness_5':
        return Icons.brightness_5;
      case 'heart_broken':
        return Icons.heart_broken;
      case 'sailing':
        return Icons.sailing;
      case 'public':
        return Icons.public;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'star':
        return Icons.star;
      case 'campaign':
        return Icons.campaign;
      case 'star_border':
        return Icons.star_border;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'add':
        return Icons.add;
      case 'brightness_high':
        return Icons.brightness_high;
      case 'local_fire_department':
        return Icons.local_fire_department;
      default:
        return Icons.place_rounded;
    }
  }
}
