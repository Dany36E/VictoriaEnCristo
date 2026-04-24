/// ═══════════════════════════════════════════════════════════════════════════
/// RelapseRecoveryScreen — Pantalla de gracia tras ruptura de racha significativa
///
/// Principios psicológicos:
/// - Reframe: "No empiezas de cero, empiezas hacia adelante."
/// - Mostrar % libertad acumulada desde el inicio del camino.
/// - Mostrar racha más larga (que nunca se resetea).
/// - Normalización: "Formar un hábito toma 21+ intentos. Estás aprendiendo."
/// - 3 acciones suaves: orar, escribir, volver a empezar (no una sola CTA agresiva).
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/feedback_engine.dart';
import '../services/victory_scoring_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

class RelapseRecoveryScreen extends StatelessWidget {
  final int brokenStreak;

  const RelapseRecoveryScreen({super.key, required this.brokenStreak});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final scoring = VictoryScoringService.I;
    final freedom = (scoring.getFreedomPercentage() * 100).round();
    final journeyDays = scoring.getJourneyDayCount();
    final bestEver = scoring.getBestStreakAllTime();

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesignSystem.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDesignSystem.spacingL),

              // Ícono suave (no cruz/cadena agresiva). Sol naciente.
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppDesignSystem.gold.withOpacity(0.28),
                        AppDesignSystem.goldLight.withOpacity(0.10),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.wb_twilight_rounded,
                    size: 52,
                    color: AppDesignSystem.gold,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
              ),

              const SizedBox(height: AppDesignSystem.spacingL),

              // Mensaje principal: reframe con gracia
              Text(
                'No estás empezando de cero.',
                textAlign: TextAlign.center,
                style: AppDesignSystem.displaySmall(
                  context,
                  color: t.textPrimary,
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: AppDesignSystem.spacingS),

              Text(
                'Estás empezando hacia adelante.',
                textAlign: TextAlign.center,
                style: AppDesignSystem.bodyLarge(
                  context,
                  color: AppDesignSystem.gold,
                ),
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: AppDesignSystem.spacingL),

              // Reconocimiento + normalización
              _GraceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lo que pasó',
                      style: AppDesignSystem.labelLarge(
                        context,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingS),
                    Text(
                      'Tu racha de $brokenStreak días se rompió. Eso duele — y también significa que tu corazón sigue luchando por lo correcto. La recaída no te define; tu respuesta sí.',
                      style: AppDesignSystem.bodyMedium(
                        context,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingM),
                    const Divider(height: 1),
                    const SizedBox(height: AppDesignSystem.spacingM),
                    Text(
                      'Formar un hábito nuevo toma 21+ intentos en promedio. No estás fallando — estás aprendiendo.',
                      style: AppDesignSystem.bodyMedium(
                        context,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),

              const SizedBox(height: AppDesignSystem.spacingM),

              // Métricas que no se resetean
              _GraceCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _StatBlock(
                        label: 'Tu mejor racha',
                        value: '$bestEver',
                        suffix: 'días',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      color: t.textSecondary.withOpacity(0.15),
                    ),
                    Expanded(
                      child: _StatBlock(
                        label: 'Días libres',
                        value: '$freedom%',
                        suffix: 'de $journeyDays d.',
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),

              const SizedBox(height: AppDesignSystem.spacingL),

              // Versículo de restauración (no de condena)
              Container(
                padding:
                    const EdgeInsets.all(AppDesignSystem.spacingM),
                decoration: BoxDecoration(
                  color: AppDesignSystem.goldSubtle,
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.radiusM),
                  border: Border.all(
                    color: AppDesignSystem.gold.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '"Porque siete veces cae el justo, y vuelve a levantarse."',
                      textAlign: TextAlign.center,
                      style: AppDesignSystem.scripture(
                        context,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingXS),
                    Text(
                      'Proverbios 24:16',
                      style:
                          AppDesignSystem.scriptureReference(context),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 1000.ms),

              const SizedBox(height: AppDesignSystem.spacingL),

              // 3 acciones suaves
              Text(
                '¿Cómo quieres continuar?',
                style: AppDesignSystem.labelLarge(
                  context,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: AppDesignSystem.spacingS),

              _ChoiceTile(
                icon: Icons.menu_book_rounded,
                title: 'Escribir en mi diario',
                subtitle: '¿Qué pasó hoy? El papel ordena el corazón.',
                onTap: () => _dismiss(context, pushRoute: '/journal-new'),
              ).animate().fadeIn(delay: 1100.ms).slideX(begin: -0.08),
              const SizedBox(height: AppDesignSystem.spacingS),
              _ChoiceTile(
                icon: Icons.self_improvement_rounded,
                title: 'Orar un momento',
                subtitle: 'Una oración breve para retomar aliento.',
                onTap: () => _dismiss(context, pushRoute: '/prayers'),
              ).animate().fadeIn(delay: 1200.ms).slideX(begin: -0.08),
              const SizedBox(height: AppDesignSystem.spacingS),
              _ChoiceTile(
                icon: Icons.trending_up_rounded,
                title: 'Volver al Home',
                subtitle: 'Hoy es un buen día para empezar de nuevo.',
                onTap: () => _dismiss(context),
                emphasized: true,
              ).animate().fadeIn(delay: 1300.ms).slideX(begin: -0.08),

              const SizedBox(height: AppDesignSystem.spacingL),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dismiss(BuildContext context, {String? pushRoute}) async {
    FeedbackEngine.I.confirm();
    await VictoryScoringService.I.acknowledgeRelapse();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (pushRoute != null) {
      // Deferir a ruta opcional — si no existe, simplemente se ignora.
      final nav = Navigator.of(context);
      if (nav.canPop() || true) {
        try {
          nav.pushNamed(pushRoute);
        } catch (_) {}
      }
    }
  }
}

class _GraceCard extends StatelessWidget {
  final Widget child;
  const _GraceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(
          color: AppDesignSystem.gold.withOpacity(0.12),
        ),
      ),
      child: child,
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  const _StatBlock({
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Column(
      children: [
        Text(
          label,
          style: AppDesignSystem.labelMedium(context, color: t.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppDesignSystem.displaySmall(
            context,
            color: AppDesignSystem.gold,
          ),
        ),
        Text(
          suffix,
          style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Semantics(
      button: true,
      label: title,
      hint: subtitle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            decoration: BoxDecoration(
              color: emphasized
                  ? AppDesignSystem.gold.withOpacity(0.10)
                  : t.surface,
              borderRadius:
                  BorderRadius.circular(AppDesignSystem.radiusM),
              border: Border.all(
                color: emphasized
                    ? AppDesignSystem.gold.withOpacity(0.45)
                    : t.textSecondary.withOpacity(0.10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: emphasized
                      ? AppDesignSystem.gold
                      : t.textPrimary,
                  size: 28,
                ),
                const SizedBox(width: AppDesignSystem.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppDesignSystem.bodyLarge(
                          context,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppDesignSystem.bodyMedium(
                          context,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: t.textSecondary.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
