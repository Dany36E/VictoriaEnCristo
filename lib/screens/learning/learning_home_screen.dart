/// ═══════════════════════════════════════════════════════════════════════════
/// LearningHomeScreen — Escuela del Reino (versión simple)
///
/// Hub directo y sin complicaciones. Tres entradas:
///   • Juegos             — retos bíblicos para jugar en grupo o 1 vs 1.
///   • Preguntas          — quiz de práctica para repasar.
///   • Orden de la Biblia — aprende y practica el orden de los 66 libros.
///
/// Nota: los módulos antiguos (Ruta/misiones/XP/rachas, héroes, parábolas,
/// mapas, profecías, línea de tiempo, fruto, biblioteca, Mi Reino) siguen en
/// el repo pero ya no están enlazados desde aquí. Se pueden reactivar después.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/learning_registry.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../utils/platform_capabilities.dart';
import 'bible_order_screen.dart';
import 'games_home_screen.dart';
import 'mana_session_screen.dart';

class LearningHomeScreen extends StatefulWidget {
  const LearningHomeScreen({super.key});

  @override
  State<LearningHomeScreen> createState() => _LearningHomeScreenState();
}

class _LearningHomeScreenState extends State<LearningHomeScreen> {
  @override
  void initState() {
    super.initState();
    LearningRegistry.I.initAll();
    AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
    _logEvent('learning_home_open_simple');
  }

  @override
  void dispose() {
    AudioEngine.I.switchBgmContext(BgmContext.home);
    super.dispose();
  }

  void _logEvent(String name, {Map<String, Object>? params}) {
    if (!PlatformCapabilities.supportsFirebaseAnalytics) return;
    try {
      FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  Future<void> _open(
    String moduleKey,
    Widget screen,
    BgmContext bgmContext,
  ) async {
    FeedbackEngine.I.tap();
    _logEvent('learning_module_open', params: {'module': moduleKey});
    AudioEngine.I.switchBgmContext(bgmContext);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Escuela del Reino',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        children: [
          _header(t),
          const SizedBox(height: AppDesignSystem.spacingL),
          _ModuleCard(
            icon: Icons.sports_esports_rounded,
            color: const Color(0xFFB68EE8),
            title: 'Juegos',
            subtitle: 'Carrera de la Fe, Duelo Relámpago y ¿Quién soy?',
            delay: 100,
            onTap: () => _open(
              'games',
              const GamesHomeScreen(),
              BgmContext.learningHeadbanz,
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          _ModuleCard(
            icon: Icons.quiz_rounded,
            color: const Color(0xFFE89E5C),
            title: 'Preguntas',
            subtitle: 'Pon a prueba lo que sabes con un quiz rápido',
            delay: 160,
            onTap: () => _open(
              'mana',
              const ManaSessionScreen(),
              BgmContext.learningQuiz,
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          _ModuleCard(
            icon: Icons.menu_book_rounded,
            color: const Color(0xFF6BC5A0),
            title: 'Orden de la Biblia',
            subtitle: 'Aprende y practica el orden de los 66 libros',
            delay: 220,
            onTap: () => _open(
              'bible_order',
              const BibleOrderScreen(),
              BgmContext.learningBibleOrder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.surface, t.cardBg],
        ),
        border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppDesignSystem.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: AppDesignSystem.gold,
              size: 30,
            ),
          ),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aprende jugando',
                  style: AppDesignSystem.headlineSmall(
                    context,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Juegos, preguntas y el orden de la Biblia. Simple y a tu ritmo.',
                  style: AppDesignSystem.bodyMedium(
                    context,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int delay;

  const _ModuleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.delay,
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
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          boxShadow: t.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppDesignSystem.headlineSmall(
                      context,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: t.textSecondary,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: delay.ms).slideY(
          begin: 0.05,
          end: 0,
        );
  }
}
