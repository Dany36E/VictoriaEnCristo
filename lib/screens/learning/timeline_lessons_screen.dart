/// ═══════════════════════════════════════════════════════════════════════════
/// TimelineLessonsScreen — selección de línea del tiempo
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/timeline_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/timeline_progress_service.dart';
import '../../services/learning/timeline_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'timeline_challenge_screen.dart';

class TimelineLessonsScreen extends StatefulWidget {
  const TimelineLessonsScreen({super.key});

  @override
  State<TimelineLessonsScreen> createState() => _TimelineLessonsScreenState();
}

class _TimelineLessonsScreenState extends State<TimelineLessonsScreen> {
  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final lessons = TimelineRepository.I.all;
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Línea del Tiempo',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: ValueListenableBuilder<TimelineProgressState>(
        valueListenable: TimelineProgressService.I.stateNotifier,
        builder: (context, state, _) {
          return ListView(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            children: [
              _header(t, state, lessons.length),
              const SizedBox(height: AppDesignSystem.spacingL),
              ...lessons.asMap().entries.map((e) {
                final idx = e.key;
                final l = e.value;
                final stars = state.completed[l.id] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(
                      bottom: AppDesignSystem.spacingM),
                  child: _LessonCard(
                    lesson: l,
                    stars: stars,
                    onTap: () async {
                      FeedbackEngine.I.tap();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TimelineChallengeScreen(lesson: l),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ).animate().fadeIn(
                      duration: 300.ms, delay: (70 * idx).ms).slideY(
                      begin: 0.05, end: 0),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _header(AppThemeData t, TimelineProgressState state, int total) {
    final done = state.completed.length;
    final stars = state.completed.values.fold<int>(0, (a, b) => a + b);
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
              const Icon(Icons.timeline_rounded,
                  color: AppDesignSystem.gold, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La historia bíblica en orden',
                  style: AppDesignSystem.headlineSmall(
                    context,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            'Arrastra personajes y eventos a su era correcta.',
            style: AppDesignSystem.bodyMedium(
                context, color: t.textSecondary),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Row(
            children: [
              _chip('$done/$total completadas'),
              const SizedBox(width: 8),
              _chip('$stars ★'),
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
}

class _LessonCard extends StatelessWidget {
  final TimelineLesson lesson;
  final int stars;
  final VoidCallback onTap;

  const _LessonCard({
    required this.lesson,
    required this.stars,
    required this.onTap,
  });

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
            color: stars > 0
                ? AppDesignSystem.gold.withOpacity(0.5)
                : t.cardBorder,
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
              child: const Icon(Icons.timeline_rounded,
                  color: AppDesignSystem.gold, size: 28),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: AppDesignSystem.headlineSmall(
                      context,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lesson.subtitle,
                    style: AppDesignSystem.bodyMedium(
                      context,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(3, (i) {
                      final filled = i < stars;
                      return Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 16,
                          color: AppDesignSystem.gold,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.textSecondary),
          ],
        ),
      ),
    );
  }
}
