/// Sección de planes recomendados: plan activo + carrusel.
library;

import 'package:flutter/material.dart';
import '../../models/plan.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../widgets/plan_card.dart';
import '../../screens/plan_library_screen.dart';

class PlansSection extends StatelessWidget {
  final Plan? activePlan;
  final PlanProgress? activeProgress;
  final List<Plan> recommendedPlans;
  final Map<String, PlanProgress> planProgressMap;
  final void Function(Plan plan) onOpenPlanDetail;

  const PlansSection({
    super.key,
    required this.activePlan,
    required this.activeProgress,
    required this.recommendedPlans,
    required this.planProgressMap,
    required this.onOpenPlanDetail,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingL),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome, color: t.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'PLANES PARA TI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: t.textPrimary.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlanLibraryScreen()),
                ),
                child: Row(
                  children: [
                    Text(
                      'Ver todos',
                      style: AppDesignSystem.labelSmall(context, color: t.accent),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12, color: t.accent),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Plan activo destacado
        if (activePlan != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingL),
            child: _ActivePlanCard(
              plan: activePlan!,
              progress: activeProgress,
              onTap: () => onOpenPlanDetail(activePlan!),
            ),
          ),

        if (activePlan != null) const SizedBox(height: 16),

        // Carousel
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingL),
            itemCount: recommendedPlans.length,
            itemBuilder: (context, index) {
              final plan = recommendedPlans[index];
              final progress = planProgressMap[plan.id];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < recommendedPlans.length - 1 ? 12 : 0,
                ),
                child: PlanCard.poster(
                  plan: plan,
                  progress: progress,
                  width: 145,
                  height: 215,
                  onTap: () => onOpenPlanDetail(plan),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActivePlanCard extends StatelessWidget {
  final Plan plan;
  final PlanProgress? progress;
  final VoidCallback onTap;

  const _ActivePlanCard({
    required this.plan,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final progressPercent = progress?.progressPercentage(plan.durationDays) ?? 0.0;
    final currentDay = progress?.currentDay ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              t.accent.withOpacity(0.2),
              t.accent.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // Progress ring
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progressPercent,
                    strokeWidth: 4,
                    backgroundColor: t.surface.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation(t.accent),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${currentDay + 1}',
                        style: AppDesignSystem.labelLarge(context, color: t.accent)
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'de ${plan.durationDays}',
                        style: TextStyle(
                          fontSize: 9,
                          color: t.textSecondary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continúa tu plan',
                    style: AppDesignSystem.labelSmall(context, color: t.accent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.title,
                    style: AppDesignSystem.labelLarge(context, color: t.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Día ${currentDay + 1}: ${plan.days.length > currentDay ? plan.days[currentDay].title : ""}',
                    style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_fill, color: t.accent, size: 32),
          ],
        ),
      ),
    );
  }
}
