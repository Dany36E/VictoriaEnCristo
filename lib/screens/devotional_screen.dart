import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../data/devotionals.dart';
import '../services/feedback_engine.dart';
import '../services/audio_engine.dart';
import '../services/daily_practice_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// DEVOTIONAL SCREEN — Mini Devocional diario (30 días)
/// ═══════════════════════════════════════════════════════════════════════════

class DevotionalScreen extends StatefulWidget {
  const DevotionalScreen({super.key});

  @override
  State<DevotionalScreen> createState() => _DevotionalScreenState();
}

class _DevotionalScreenState extends State<DevotionalScreen> {
  // Inicializar con valores síncronos seguros para evitar
  // LateInitializationError en el primer build (antes de que
  // _loadProgress complete su lectura asíncrona de SharedPreferences).
  int _currentDay = 1;
  Devotional _devotional = Devotionals.getDevotionalForDay(1);
  bool _challengeCompleted = false;
  static const _prefKeyDay = 'devotional_current_day';
  static const _prefKeyChallengePrefix = 'devotional_challenge_';

  @override
  void initState() {
    super.initState();
    _loadProgress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioEngine.I.switchBgmContext(BgmContext.prayer);
      // Marca devocional leído al entrar a la pantalla (no requiere clic en CTA)
      DailyPracticeService.I.mark(DailyPractice.devotional);
    });
  }

  @override
  void dispose() {
    AudioEngine.I.switchBgmContext(BgmContext.home);
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final day = prefs.getInt(_prefKeyDay) ?? 1;
    final clamped = day.clamp(1, Devotionals.totalDays);
    final challengeDone =
        prefs.getBool('$_prefKeyChallengePrefix$clamped') ?? false;
    if (!mounted) return;
    setState(() {
      _currentDay = clamped;
      _devotional = Devotionals.getDevotionalForDay(clamped);
      _challengeCompleted = challengeDone;
    });
  }

  Future<void> _goToDay(int day) async {
    final clamped = day.clamp(1, Devotionals.totalDays);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyDay, clamped);
    final challengeDone =
        prefs.getBool('$_prefKeyChallengePrefix$clamped') ?? false;
    setState(() {
      _currentDay = clamped;
      _devotional = Devotionals.getDevotionalForDay(clamped);
      _challengeCompleted = challengeDone;
    });
    FeedbackEngine.I.tap();
  }

  Future<void> _toggleChallenge() async {
    final newVal = !_challengeCompleted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefKeyChallengePrefix$_currentDay', newVal);
    setState(() => _challengeCompleted = newVal);
    if (newVal) {
      FeedbackEngine.I.confirm();
    } else {
      FeedbackEngine.I.tap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = AppThemeData.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: themeData.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // ─── App Bar colapsable ───
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: themeData.scaffoldBg,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: themeData.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      themeData.accent.withOpacity(0.15),
                      themeData.scaffoldBg,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(56, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Devocional',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: themeData.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Día $_currentDay de ${Devotionals.totalDays}',
                          style: TextStyle(
                            fontSize: 14,
                            color: themeData.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Navegación de días ───
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.spacingM),
                itemCount: Devotionals.totalDays,
                itemBuilder: (ctx, i) {
                  final day = i + 1;
                  final isSelected = day == _currentDay;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _goToDay(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? themeData.accent
                              : themeData.cardBg
                                  .withOpacity(isDark ? 0.5 : 0.3),
                          borderRadius:
                              BorderRadius.circular(AppDesignSystem.radiusS),
                          border: Border.all(
                            color: isSelected
                                ? themeData.accent
                                : themeData.textSecondary.withOpacity(0.15),
                          ),
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : themeData.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(
              child: SizedBox(height: AppDesignSystem.spacingL)),

          // ─── Contenido devocional ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título del día
                  Text(
                    _devotional.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: themeData.textPrimary,
                      letterSpacing: 0.2,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingL),

                  // ─── Versículo ───
                  _buildSection(
                    themeData: themeData,
                    isDark: isDark,
                    icon: Icons.menu_book_rounded,
                    label: 'VERSÍCULO',
                    accentColor: const Color(0xFF7B68EE),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _devotional.verse,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: themeData.textPrimary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '— ${_devotional.verseReference}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: themeData.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingM),

                  // ─── Reflexión ───
                  _buildSection(
                    themeData: themeData,
                    isDark: isDark,
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'REFLEXIÓN',
                    accentColor: const Color(0xFFF39C12),
                    child: SelectableText(
                      _devotional.reflection,
                      style: TextStyle(
                        fontSize: 16,
                        color: themeData.textPrimary,
                        height: 1.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingM),

                  // ─── Reto del día ───
                  _buildSection(
                    themeData: themeData,
                    isDark: isDark,
                    icon: Icons.emoji_events_rounded,
                    label: 'RETO DEL DÍA',
                    accentColor: const Color(0xFF27AE60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _devotional.challenge,
                          style: TextStyle(
                            fontSize: 15,
                            color: themeData.textPrimary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _toggleChallenge,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _challengeCompleted
                                  ? const Color(0xFF27AE60).withOpacity(0.15)
                                  : themeData.textSecondary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(
                                  AppDesignSystem.radiusS),
                              border: Border.all(
                                color: _challengeCompleted
                                    ? const Color(0xFF27AE60).withOpacity(0.4)
                                    : themeData.textSecondary.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _challengeCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 20,
                                  color: _challengeCompleted
                                      ? const Color(0xFF27AE60)
                                      : themeData.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _challengeCompleted
                                      ? '¡Reto completado!'
                                      : 'Marcar reto como completado',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _challengeCompleted
                                        ? const Color(0xFF27AE60)
                                        : themeData.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingM),

                  // ─── Oración ───
                  _buildSection(
                    themeData: themeData,
                    isDark: isDark,
                    icon: Icons.favorite_rounded,
                    label: 'ORACIÓN',
                    accentColor: const Color(0xFFE74C3C),
                    child: SelectableText(
                      _devotional.prayer,
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: themeData.textPrimary,
                        height: 1.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingL),

                  // ─── Navegación siguiente / anterior ───
                  _buildDayNavigation(themeData),

                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom +
                          AppDesignSystem.spacingXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required AppThemeData themeData,
    required bool isDark,
    required IconData icon,
    required String label,
    required Color accentColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: themeData.cardBg.withOpacity(isDark ? 0.5 : 0.85),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(
          color: accentColor.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withOpacity(0.25),
                      accentColor.withOpacity(0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDayNavigation(AppThemeData themeData) {
    return Row(
      children: [
        if (_currentDay > 1)
          Expanded(
            child: _navButton(
              themeData: themeData,
              icon: Icons.arrow_back_ios_rounded,
              label: 'Día ${_currentDay - 1}',
              onTap: () => _goToDay(_currentDay - 1),
              alignEnd: false,
            ),
          )
        else
          const Expanded(child: SizedBox()),
        const SizedBox(width: 12),
        if (_currentDay < Devotionals.totalDays)
          Expanded(
            child: _navButton(
              themeData: themeData,
              icon: Icons.arrow_forward_ios_rounded,
              label: 'Día ${_currentDay + 1}',
              onTap: () => _goToDay(_currentDay + 1),
              alignEnd: true,
            ),
          )
        else
          const Expanded(child: SizedBox()),
      ],
    );
  }

  Widget _navButton({
    required AppThemeData themeData,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool alignEnd,
  }) {
    final children = [
      Icon(icon, size: 16, color: themeData.accent),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: themeData.accent,
        ),
      ),
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: themeData.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
          border: Border.all(color: themeData.accent.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: alignEnd ? children.reversed.toList() : children,
        ),
      ),
    );
  }
}
