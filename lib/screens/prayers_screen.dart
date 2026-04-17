import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../data/prayers.dart';
import '../services/feedback_engine.dart';
import '../services/personalization_engine.dart';
import '../services/content_repository.dart';
import '../services/audio_engine.dart';
import '../models/content_item.dart';
import '../models/content_enums.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PRAYERS SCREEN — diseño premium adaptativo
/// ═══════════════════════════════════════════════════════════════════════════
/// • 8 categorías con identidad visual propia (color + icono + glifo)
/// • Sección "Para Ti" alimentada por PersonalizationEngine
/// • Cards de vidrio con borde acentuado (consistente con HomeScreen)
/// • Totalmente adaptable a los 9 temas de AppThemeData
/// ═══════════════════════════════════════════════════════════════════════════

class _PrayerCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String glyph;
  final Color accent;
  final List<Prayer> prayers;

  const _PrayerCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.glyph,
    required this.accent,
    required this.prayers,
  });
}

class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  @override
  void initState() {
    super.initState();
    // Música tranquila de oración (assigned via music strategy)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioEngine.I.switchBgmContext(BgmContext.prayer);
    });
  }

  @override
  void dispose() {
    AudioEngine.I.switchBgmContext(BgmContext.home);
    super.dispose();
  }

  List<_PrayerCategory> _buildCategories() {
    return const [
      _PrayerCategory(
        id: 'emergency',
        title: 'Emergencia',
        subtitle: 'Cuando la tentación aprieta',
        icon: Icons.flash_on_rounded,
        glyph: '🆘',
        accent: Color(0xFFE74C3C),
        prayers: Prayers.emergencyPrayers,
      ),
      _PrayerCategory(
        id: 'morning',
        title: 'Mañana',
        subtitle: 'Consagración y armadura',
        icon: Icons.wb_sunny_rounded,
        glyph: '🌅',
        accent: Color(0xFFF39C12),
        prayers: Prayers.morningPrayers,
      ),
      _PrayerCategory(
        id: 'night',
        title: 'Noche',
        subtitle: 'Reflexión y descanso',
        icon: Icons.nightlight_round,
        glyph: '🌙',
        accent: Color(0xFF7B68EE),
        prayers: Prayers.nightPrayers,
      ),
      _PrayerCategory(
        id: 'strength',
        title: 'Fortaleza',
        subtitle: 'Cuando el alma pesa',
        icon: Icons.fitness_center_rounded,
        glyph: '💪',
        accent: Color(0xFF27AE60),
        prayers: Prayers.strengthPrayers,
      ),
      _PrayerCategory(
        id: 'gratitude',
        title: 'Gratitud',
        subtitle: 'Corazón hacia la luz',
        icon: Icons.favorite_rounded,
        glyph: '🙏',
        accent: Color(0xFFE6A95E),
        prayers: Prayers.gratitudePrayers,
      ),
      _PrayerCategory(
        id: 'forgiveness',
        title: 'Perdón',
        subtitle: 'Dejar ir y ser libre',
        icon: Icons.all_inclusive_rounded,
        glyph: '✝️',
        accent: Color(0xFF3498DB),
        prayers: Prayers.forgivenessPrayers,
      ),
      _PrayerCategory(
        id: 'warfare',
        title: 'Guerra espiritual',
        subtitle: 'Autoridad en el Nombre',
        icon: Icons.shield_rounded,
        glyph: '⚔️',
        accent: Color(0xFFD4AF37),
        prayers: Prayers.warfarePrayers,
      ),
      _PrayerCategory(
        id: 'family',
        title: 'Familia',
        subtitle: 'Por los que amas',
        icon: Icons.family_restroom_rounded,
        glyph: '👨‍👩‍👧',
        accent: Color(0xFFE91E63),
        prayers: Prayers.familyPrayers,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final engine = PersonalizationEngine.I;
    final recommendedPrayers = ContentRepository.I.isInitialized
        ? engine.getRecommendedPrayers(limit: 3)
        : <ScoredItem<PrayerItem>>[];
    final hasPersonalization = recommendedPrayers.isNotEmpty;
    final primaryGiant = engine.primaryGiant;
    final categories = _buildCategories();
    final totalPrayers = categories.fold<int>(0, (s, c) => s + c.prayers.length);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: t.scaffoldBg,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
              title: Text(
                'Oraciones',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(gradient: t.headerGradient),
                child: Stack(
                  children: [
                    Positioned(
                      right: -40,
                      top: 30,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              t.accent.withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 48,
                      child: Text(
                        '$totalPrayers oraciones para cada momento',
                        style: TextStyle(
                          fontSize: 13,
                          color: t.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppDesignSystem.spacingM,
              AppDesignSystem.spacingS,
              AppDesignSystem.spacingM,
              MediaQuery.of(context).padding.bottom + AppDesignSystem.spacingXL,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (hasPersonalization) ...[
                  _PersonalizedSection(
                    prayers: recommendedPrayers,
                    giantName: primaryGiant?.displayName,
                    themeData: t,
                  ),
                  const SizedBox(height: AppDesignSystem.spacingL),
                ],
                for (var i = 0; i < categories.length; i++) ...[
                  _CategoryBlock(
                    category: categories[i],
                    themeData: t,
                  ),
                  if (i < categories.length - 1)
                    const SizedBox(height: AppDesignSystem.spacingL),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PERSONALIZED SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _PersonalizedSection extends StatelessWidget {
  final List<ScoredItem<PrayerItem>> prayers;
  final String? giantName;
  final AppThemeData themeData;

  const _PersonalizedSection({
    required this.prayers,
    required this.giantName,
    required this.themeData,
  });

  @override
  Widget build(BuildContext context) {
    final accent = themeData.accent;
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(themeData.isDark ? 0.18 : 0.12),
            accent.withOpacity(themeData.isDark ? 0.06 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: accent.withOpacity(0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Para ti',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            giantName != null
                ? 'Enfoque: $giantName'
                : 'Recomendadas para tu batalla',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: themeData.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          for (var scored in prayers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PrayerCard(
                title: scored.item.title,
                durationMinutes: scored.item.durationMinutes ?? 3,
                accent: accent,
                themeData: themeData,
                reason: scored.reason,
                onTap: () {
                  FeedbackEngine.I.tap();
                  final legacy = Prayer(
                    title: scored.item.title,
                    content: scored.item.body,
                    category: 'personalizado',
                    durationMinutes: scored.item.durationMinutes ?? 3,
                  );
                  _openPrayer(context, legacy, accent);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CATEGORY BLOCK
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryBlock extends StatelessWidget {
  final _PrayerCategory category;
  final AppThemeData themeData;

  const _CategoryBlock({required this.category, required this.themeData});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppDesignSystem.spacingS),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      category.accent.withOpacity(0.35),
                      category.accent.withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusS + 2),
                  border: Border.all(
                    color: category.accent.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(category.icon, color: category.accent, size: 20),
              ),
              const SizedBox(width: AppDesignSystem.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: themeData.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      category.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: themeData.textSecondary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: category.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                ),
                child: Text(
                  '${category.prayers.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: category.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var prayer in category.prayers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PrayerCard(
              title: prayer.title,
              durationMinutes: prayer.durationMinutes,
              accent: category.accent,
              themeData: themeData,
              reason: null,
              onTap: () {
                FeedbackEngine.I.tap();
                _openPrayer(context, prayer, category.accent);
              },
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRAYER CARD
// ═══════════════════════════════════════════════════════════════════════════

class _PrayerCard extends StatelessWidget {
  final String title;
  final int durationMinutes;
  final Color accent;
  final AppThemeData themeData;
  final String? reason;
  final VoidCallback onTap;

  const _PrayerCard({
    required this.title,
    required this.durationMinutes,
    required this.accent,
    required this.themeData,
    required this.reason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        child: Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: themeData.cardBg,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
            border: Border.all(
              color: accent.withOpacity(themeData.isDark ? 0.22 : 0.14),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(themeData.isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusS + 2),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.menu_book_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: AppDesignSystem.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reason != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusFull,
                            ),
                          ),
                          child: Text(
                            reason!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: themeData.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 11,
                          color: themeData.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$durationMinutes min',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeData.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: accent.withOpacity(0.6),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════════════════

void _openPrayer(BuildContext context, Prayer prayer, Color accent) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PrayerDetailScreen(prayer: prayer, color: accent),
    ),
  );
}

class PrayerDetailScreen extends StatefulWidget {
  final Prayer prayer;
  final Color color;

  const PrayerDetailScreen({
    super.key,
    required this.prayer,
    required this.color,
  });

  @override
  State<PrayerDetailScreen> createState() => _PrayerDetailScreenState();
}

class _PrayerDetailScreenState extends State<PrayerDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: t.scaffoldBg,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: t.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.color.withOpacity(t.isDark ? 0.30 : 0.18),
                      t.scaffoldBg,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -60,
                      top: 40,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              widget.color.withOpacity(0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    widget.color,
                                    widget.color.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.color.withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.prayer.title,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: t.textPrimary,
                                letterSpacing: 0.2,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: t.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.prayer.durationMinutes} minutos de lectura',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: t.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              AppDesignSystem.spacingM,
              20,
              MediaQuery.of(context).padding.bottom + 100,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingL),
                  decoration: BoxDecoration(
                    color: t.cardBg,
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
                    border: Border.all(
                      color: widget.color.withOpacity(t.isDark ? 0.22 : 0.15),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: widget.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ORA CON FE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: widget.color,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDesignSystem.spacingM),
                      SelectableText(
                        widget.prayer.content,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.75,
                          color: t.textPrimary,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                FeedbackEngine.I.tap();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      '🙏 Oración completada — que Dios te bendiga',
                    ),
                    backgroundColor: widget.color,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text(
                'Terminé de orar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
