/// ═══════════════════════════════════════════════════════════════════════════
/// PropheciesHomeScreen — lista de rondas de Profecías Mesiánicas.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/prophecy_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/prophecy_progress_service.dart';
import '../../services/learning/prophecy_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'prophecy_match_screen.dart';

class PropheciesHomeScreen extends StatefulWidget {
  const PropheciesHomeScreen({super.key});

  @override
  State<PropheciesHomeScreen> createState() => _PropheciesHomeScreenState();
}

class _PropheciesHomeScreenState extends State<PropheciesHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final rounds = ProphecyRepository.I.all;
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Profecías Mesiánicas',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: ValueListenableBuilder<ProphecyProgressState>(
        valueListenable: ProphecyProgressService.I.stateNotifier,
        builder: (context, state, _) {
          return ListView(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            children: [
              _intro(t),
              const SizedBox(height: AppDesignSystem.spacingM),
              ...rounds.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                final stars = state.bestStars[r.id] ?? 0;
                return _roundCard(t, r, stars).animate().fadeIn(
                    duration: 300.ms,
                    delay: (100 * i).ms).slideY(begin: 0.05, end: 0);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _intro(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.surface, t.cardBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded,
                  color: AppDesignSystem.gold, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El AT anuncia a Cristo',
                  style: AppDesignSystem.headlineSmall(context,
                      color: t.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Conecta cada profecía del Antiguo Testamento con su cumplimiento en el Nuevo. Toda la Escritura habla de Él.',
            style: AppDesignSystem.bodyMedium(context,
                color: t.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '"Estas son las que dan testimonio de mí" — Juan 5:39',
            style: AppDesignSystem.scripture(context,
                color: AppDesignSystem.gold),
          ),
        ],
      ),
    );
  }

  Widget _roundCard(AppThemeData t, ProphecyRound r, int stars) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        onTap: () async {
          FeedbackEngine.I.tap();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProphecyMatchScreen(round: r),
            ),
          );
          if (mounted) setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
            border: Border.all(
              color: stars > 0
                  ? AppDesignSystem.gold.withOpacity(0.6)
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
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppDesignSystem.gold, size: 26),
              ),
              const SizedBox(width: AppDesignSystem.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: AppDesignSystem.headlineSmall(context,
                          color: t.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.pairs.length} pares  ·  hasta ${r.xpReward} XP',
                      style: AppDesignSystem.labelSmall(context,
                          color: t.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(3, (i) {
                        final filled = i < stars;
                        return Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 18,
                          color: filled
                              ? AppDesignSystem.gold
                              : t.textSecondary,
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
      ),
    );
  }
}
