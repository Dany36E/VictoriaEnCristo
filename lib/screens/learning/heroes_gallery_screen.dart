/// ═══════════════════════════════════════════════════════════════════════════
/// HeroesGalleryScreen — Galería de Héroes de la Fe (Hebreos 11)
///
/// Muestra los 12 héroes en grid, agrupados por era. Cada tarjeta muestra
/// nombre, epíteto, gigante vencido y estado (desbloqueado o bloqueado).
/// Al tocar un héroe se abre su detalle; los no desbloqueados muestran un
/// preview con teaser antes del reto.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/hero_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/heroes_progress_service.dart';
import '../../services/learning/heroes_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'hero_detail_screen.dart';

class HeroesGalleryScreen extends StatefulWidget {
  const HeroesGalleryScreen({super.key});

  @override
  State<HeroesGalleryScreen> createState() => _HeroesGalleryScreenState();
}

class _HeroesGalleryScreenState extends State<HeroesGalleryScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await HeroesRepository.I.load();
    await HeroesProgressService.I.init();
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
          'Héroes de la Fe',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<HeroesProgressState>(
              valueListenable: HeroesProgressService.I.stateNotifier,
              builder: (context, _, _) => _buildBody(context, t),
            ),
    );
  }

  Widget _buildBody(BuildContext context, AppThemeData t) {
    final grouped = HeroesRepository.I.groupedByEra();
    if (grouped.isEmpty) {
      return Center(
        child: Text(
          'No hay héroes disponibles.',
          style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
        ),
      );
    }

    final total = HeroesRepository.I.all.length;
    final unlocked = HeroesProgressService.I.unlockedCount;

    const eraOrder = [
      HeroEra.patriarch,
      HeroEra.exodus,
      HeroEra.kingdom,
      HeroEra.prophets,
      HeroEra.gospels,
      HeroEra.earlyChurch,
    ];

    return ListView(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      children: [
        _buildHero(context, t, unlocked, total),
        const SizedBox(height: AppDesignSystem.spacingL),
        for (final era in eraOrder)
          if (grouped[era]?.isNotEmpty ?? false) ...[
            _eraHeader(context, t, era),
            const SizedBox(height: AppDesignSystem.spacingS),
            _heroesGrid(context, t, grouped[era]!),
            const SizedBox(height: AppDesignSystem.spacingM),
          ],
      ],
    );
  }

  Widget _buildHero(
      BuildContext context, AppThemeData t, int unlocked, int total) {
    final pct = total == 0 ? 0.0 : unlocked / total;
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
              const Icon(Icons.workspace_premium_rounded,
                  color: AppDesignSystem.gold, size: 28),
              const SizedBox(width: AppDesignSystem.spacingS),
              Expanded(
                child: Text(
                  'Aprende de quienes vencieron',
                  style: AppDesignSystem.headlineSmall(context,
                      color: t.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            'Hebreos 11: una nube de testigos que vencieron sus gigantes por fe.',
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: t.cardBorder,
              valueColor:
                  const AlwaysStoppedAnimation(AppDesignSystem.gold),
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingXS),
          Text(
            '$unlocked de $total héroes conocidos',
            style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _eraHeader(BuildContext context, AppThemeData t, HeroEra era) {
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
            style: AppDesignSystem.labelMedium(context, color: t.textSecondary)
                .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _heroesGrid(
      BuildContext context, AppThemeData t, List<HeroOfFaith> heroes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: heroes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppDesignSystem.spacingS,
        mainAxisSpacing: AppDesignSystem.spacingS,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, i) => _heroCard(context, t, heroes[i]),
    );
  }

  Widget _heroCard(BuildContext context, AppThemeData t, HeroOfFaith h) {
    final unlocked = HeroesProgressService.I.isUnlocked(h.id);
    final icon = _iconFor(h.icon);

    return InkWell(
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
      onTap: () async {
        FeedbackEngine.I.tap();
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => HeroDetailScreen(hero: h)),
        );
        if (mounted) setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
          border: Border.all(
            color: unlocked
                ? AppDesignSystem.gold.withOpacity(0.55)
                : t.cardBorder,
            width: unlocked ? 1.4 : 1,
          ),
          boxShadow: t.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.gold.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      color: AppDesignSystem.gold, size: 22),
                ),
                const Spacer(),
                if (unlocked)
                  const Icon(Icons.verified_rounded,
                      color: AppDesignSystem.gold, size: 20),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingS),
            Text(
              h.name,
              style: AppDesignSystem.bodyLarge(context, color: t.textPrimary)
                  .copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              h.epithet,
              style: AppDesignSystem.labelSmall(context,
                  color: AppDesignSystem.gold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: t.scaffoldBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on_rounded,
                      size: 12, color: AppDesignSystem.gold),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Vs. ${h.giantDefeated}',
                      style: AppDesignSystem.labelSmall(context,
                          color: t.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 260.ms, delay: (30 * h.order).ms)
          .slideY(begin: 0.04, end: 0),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'star':
        return Icons.star_rounded;
      case 'palette':
        return Icons.palette_rounded;
      case 'waves':
        return Icons.waves_rounded;
      case 'flag':
        return Icons.flag_rounded;
      case 'music_note':
        return Icons.music_note_rounded;
      case 'whatshot':
        return Icons.whatshot_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'anchor':
        return Icons.anchor_rounded;
      case 'auto_stories':
        return Icons.auto_stories_rounded;
      case 'visibility':
        return Icons.visibility_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}
