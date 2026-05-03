/// ═══════════════════════════════════════════════════════════════════════════
/// BibleMapsScreen — selector de mapas bíblicos (Tierras Bíblicas)
///
/// Muestra la lista de mapas disponibles con estado de bloqueo/estrellas.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/bible_map_models.dart';
import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/bible_map_repository.dart';
import '../../services/learning/bible_map_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'bible_map_challenge_screen.dart';

class BibleMapsScreen extends StatefulWidget {
  const BibleMapsScreen({super.key});

  @override
  State<BibleMapsScreen> createState() => _BibleMapsScreenState();
}

class _BibleMapsScreenState extends State<BibleMapsScreen> {
  @override
  void initState() {
    super.initState();
    AudioEngine.I.switchBgmContext(BgmContext.learningMap);
  }

  @override
  void dispose() {
    AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final maps = BibleMapRepository.I.all;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        title: Text(
          'Tierras Bíblicas',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: ValueListenableBuilder<BibleMapProgressState>(
        valueListenable: BibleMapProgressService.I.stateNotifier,
        builder: (context, progress, _) {
          return ListView(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            children: [
              // Header
              _buildHeader(t, progress),
              const SizedBox(height: AppDesignSystem.spacingL),

              // Lista de mapas
              ...maps.asMap().entries.map((entry) {
                final index = entry.key;
                final map = entry.value;
                final unlocked = BibleMapProgressService.I.isUnlocked(map.id);
                final stars = BibleMapProgressService.I.starsFor(map.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
                  child:
                      _MapCard(
                            bibleMap: map,
                            unlocked: unlocked,
                            stars: stars,
                            onTap: unlocked
                                ? () async {
                                    FeedbackEngine.I.tap();
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BibleMapChallengeScreen(bibleMap: map),
                                      ),
                                    );
                                    if (mounted) setState(() {});
                                  }
                                : null,
                          )
                          .animate()
                          .fadeIn(
                            duration: 300.ms,
                            delay: Duration(milliseconds: index * 60),
                          )
                          .slideY(begin: 0.05, end: 0),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppThemeData t, BibleMapProgressState progress) {
    final total = BibleMapRepository.I.all.length;
    final done = progress.completedMaps.length;
    final totalStars = progress.completedMaps.values.fold(0, (a, b) => a + b);
    final maxStars = total * 3;

    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1628), Color(0xFF122040)],
        ),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public_rounded, color: AppDesignSystem.gold, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Explora las tierras bíblicas',
                  style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            'Arrastra los nombres de los lugares a su posición correcta en cada mapa.',
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Row(
            children: [
              _ProgressChip(
                icon: Icons.map_rounded,
                label: '$done/$total mapas',
                color: AppDesignSystem.gold,
              ),
              const SizedBox(width: 12),
              _ProgressChip(
                icon: Icons.star_rounded,
                label: '$totalStars/$maxStars ★',
                color: AppDesignSystem.gold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// MAP CARD
// ══════════════════════════════════════════════════════════════════════════

class _MapCard extends StatelessWidget {
  final BibleMap bibleMap;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  const _MapCard({required this.bibleMap, required this.unlocked, required this.stars, this.onTap});

  IconData _iconForName(String name) {
    switch (name) {
      case 'terrain':
        return Icons.terrain_rounded;
      case 'landscape':
        return Icons.landscape_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'sailing':
        return Icons.sailing_rounded;
      case 'castle':
        return Icons.castle_rounded;
      case 'church':
        return Icons.church_rounded;
      default:
        return Icons.map_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final completed = stars > 0;

    return Opacity(
      opacity: unlocked ? 1.0 : 0.45,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
            border: Border.all(
              color: completed ? AppDesignSystem.gold.withOpacity(0.3) : t.cardBorder,
            ),
            boxShadow: t.cardShadow,
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: unlocked
                      ? (completed
                            ? AppDesignSystem.gold.withOpacity(0.15)
                            : const Color(0xFF1A2A3A))
                      : Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  unlocked ? _iconForName(bibleMap.icon) : Icons.lock_rounded,
                  color: unlocked
                      ? (completed ? AppDesignSystem.gold : const Color(0xFF5A8ABB))
                      : Colors.white.withOpacity(0.3),
                  size: 26,
                ),
              ),
              const SizedBox(width: AppDesignSystem.spacingM),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bibleMap.title,
                      style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bibleMap.subtitle,
                      style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
                    ),
                    if (completed) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(3, (i) {
                          return Icon(
                            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 16,
                            color: i < stars
                                ? AppDesignSystem.gold
                                : t.textSecondary.withOpacity(0.3),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              if (unlocked) Icon(Icons.arrow_forward_ios_rounded, size: 14, color: t.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// PROGRESS CHIP
// ══════════════════════════════════════════════════════════════════════════

class _ProgressChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ProgressChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
