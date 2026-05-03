/// ═══════════════════════════════════════════════════════════════════════════
/// ParablesGalleryScreen — lista de parábolas para estudiar
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/parable_models.dart';
import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/parable_progress_service.dart';
import '../../services/learning/parable_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'parable_detail_screen.dart';

class ParablesGalleryScreen extends StatefulWidget {
  const ParablesGalleryScreen({super.key});

  @override
  State<ParablesGalleryScreen> createState() => _ParablesGalleryScreenState();
}

class _ParablesGalleryScreenState extends State<ParablesGalleryScreen> {
  @override
  void initState() {
    super.initState();
    AudioEngine.I.switchBgmContext(BgmContext.learningStory);
  }

  @override
  void dispose() {
    AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final parables = ParableRepository.I.all;
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Parábolas de Jesús',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: ValueListenableBuilder<ParableProgressState>(
        valueListenable: ParableProgressService.I.stateNotifier,
        builder: (context, state, _) {
          return ListView(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            children: [
              _buildHeader(context, t, state, parables.length),
              const SizedBox(height: AppDesignSystem.spacingL),
              ...parables.asMap().entries.map((e) {
                final idx = e.key;
                final p = e.value;
                final done = state.completedIds.contains(p.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
                  child:
                      _ParableCard(
                            parable: p,
                            completed: done,
                            onTap: () async {
                              FeedbackEngine.I.tap();
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ParableDetailScreen(parable: p)),
                              );
                              if (mounted) setState(() {});
                            },
                          )
                          .animate()
                          .fadeIn(duration: 300.ms, delay: (60 * idx).ms)
                          .slideY(begin: 0.05, end: 0),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeData t, ParableProgressState state, int total) {
    final done = state.completedIds.length;
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.surface, t.cardBg],
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
              const Icon(Icons.auto_stories_rounded, color: AppDesignSystem.gold, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Narraciones del Maestro',
                  style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            'Escucha, entiende y aplica las historias con las que Jesús enseñó el Reino.',
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Row(
            children: [
              _chip(t, '$done/$total completadas'),
              const SizedBox(width: 8),
              _chip(t, '+XP al completar'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(AppThemeData t, String text) {
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
}

class _ParableCard extends StatelessWidget {
  final Parable parable;
  final bool completed;
  final VoidCallback onTap;

  const _ParableCard({required this.parable, required this.completed, required this.onTap});

  IconData _icon() {
    switch (parable.icon) {
      case 'grass':
        return Icons.grass_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'balance':
        return Icons.balance_rounded;
      case 'park':
        return Icons.park_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      case 'schedule':
        return Icons.schedule_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
          border: Border.all(
            color: completed ? AppDesignSystem.gold.withOpacity(0.55) : t.cardBorder,
          ),
          boxShadow: t.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppDesignSystem.gold.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon(), color: AppDesignSystem.gold, size: 28),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parable.title,
                    style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parable.subtitle,
                    style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    parable.reference,
                    style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold),
                  ),
                ],
              ),
            ),
            Icon(
              completed ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: completed ? AppDesignSystem.gold : t.textSecondary,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}
