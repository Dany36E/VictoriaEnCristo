/// ═══════════════════════════════════════════════════════════════════════════
/// FruitGardenScreen — corona de los 9 frutos
/// Muestra un grid 3x3 con cada fruto. Los completados brillan y se cierra
/// la "corona" cuando están los 9.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/fruit_models.dart';
import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/fruit_progress_service.dart';
import '../../services/learning/fruit_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'fruit_week_screen.dart';

class FruitGardenScreen extends StatefulWidget {
  const FruitGardenScreen({super.key});

  @override
  State<FruitGardenScreen> createState() => _FruitGardenScreenState();
}

class _FruitGardenScreenState extends State<FruitGardenScreen> {
  @override
  void initState() {
    super.initState();
    AudioEngine.I.switchBgmContext(BgmContext.learningQuiz);
  }

  @override
  void dispose() {
    AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
    super.dispose();
  }

  Color _parseHex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'favorite':
        return Icons.favorite_rounded;
      case 'wb_sunny':
        return Icons.wb_sunny_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'hourglass_empty':
        return Icons.hourglass_empty_rounded;
      case 'volunteer_activism':
        return Icons.volunteer_activism_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      case 'verified':
        return Icons.verified_rounded;
      case 'cruelty_free':
        return Icons.cruelty_free_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      default:
        return Icons.eco_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final fruits = FruitRepository.I.all;
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Fruto del Espíritu',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: ValueListenableBuilder<FruitProgressState>(
        valueListenable: FruitProgressService.I.stateNotifier,
        builder: (context, state, _) {
          final earned = state.badges.length;
          final crownComplete = earned >= fruits.length && fruits.isNotEmpty;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(t, earned, fruits.length, crownComplete),
                const SizedBox(height: AppDesignSystem.spacingL),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: fruits.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, i) {
                    final f = fruits[i];
                    final earned = state.badges.contains(f.id);
                    final inProgress = (state.byFruit[f.id]?.doneActions.isNotEmpty ?? false);
                    return _FruitTile(
                          fruit: f,
                          earned: earned,
                          inProgress: inProgress,
                          color: _parseHex(f.colorHex),
                          icon: _iconFor(f.icon),
                          onTap: () async {
                            FeedbackEngine.I.tap();
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => FruitWeekScreen(fruit: f)),
                            );
                            if (mounted) setState(() {});
                          },
                        )
                        .animate()
                        .fadeIn(duration: 300.ms, delay: (60 * i).ms)
                        .scale(begin: const Offset(0.9, 0.9), duration: 300.ms);
                  },
                ),
                if (crownComplete) ...[
                  const SizedBox(height: AppDesignSystem.spacingL),
                  _buildCrown(t),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppThemeData t, int earned, int total, bool crown) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.surface, t.cardBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.2)),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: AppDesignSystem.gold, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gálatas 5:22-23',
                  style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            'Nueve frutos. Nueve semanas. El Espíritu los hace crecer; tú riegas con obediencia pequeña.',
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Row(
            children: [
              _chip('$earned/$total insignias'),
              const SizedBox(width: 8),
              if (crown) _chip('👑 Corona completa'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppDesignSystem.gold.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppDesignSystem.gold,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCrown(AppThemeData t) {
    return Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingL),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppDesignSystem.gold, Color(0xFFF0CC7A)]),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
            boxShadow: [BoxShadow(color: AppDesignSystem.gold.withOpacity(0.5), blurRadius: 20)],
          ),
          child: Column(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.black, size: 48),
              const SizedBox(height: AppDesignSystem.spacingM),
              Text(
                'Corona de los 9 frutos',
                style: AppDesignSystem.headlineSmall(context, color: Colors.black),
              ),
              const SizedBox(height: 6),
              Text(
                '"El fruto del Espíritu es amor, gozo, paz, paciencia,\nbenignidad, bondad, fe, mansedumbre, templanza".',
                textAlign: TextAlign.center,
                style: AppDesignSystem.bodyMedium(context, color: Colors.black87),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(begin: const Offset(0.9, 0.9), duration: 600.ms, curve: Curves.elasticOut);
  }
}

class _FruitTile extends StatelessWidget {
  final SpiritFruit fruit;
  final bool earned;
  final bool inProgress;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _FruitTile({
    required this.fruit,
    required this.earned,
    required this.inProgress,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: earned
              ? LinearGradient(colors: [color.withOpacity(0.35), color.withOpacity(0.15)])
              : null,
          color: earned ? null : t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
          border: Border.all(
            color: earned
                ? color
                : inProgress
                ? color.withOpacity(0.5)
                : t.cardBorder,
            width: earned ? 2 : 1,
          ),
          boxShadow: earned
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12)]
              : t.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 28),
                ),
                if (earned)
                  const Positioned(
                    right: -4,
                    bottom: -4,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: AppDesignSystem.gold,
                      child: Icon(Icons.check_rounded, color: Colors.black, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fruit.name,
              textAlign: TextAlign.center,
              style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              fruit.greek,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
