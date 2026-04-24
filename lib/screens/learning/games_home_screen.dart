/// ═══════════════════════════════════════════════════════════════════════════
/// GamesHomeScreen — Juegos Bíblicos (hub)
///
/// Punto de entrada a los juegos 1 vs 1 locales.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/feedback_engine.dart';
import '../../services/learning/question_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'game_headbanz_screen.dart';
import 'game_lightning_screen.dart';
import 'game_race_screen.dart';

class GamesHomeScreen extends StatefulWidget {
  const GamesHomeScreen({super.key});

  @override
  State<GamesHomeScreen> createState() => _GamesHomeScreenState();
}

class _GamesHomeScreenState extends State<GamesHomeScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await QuestionRepository.I.load();
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
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Juegos Bíblicos',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppDesignSystem.spacingM),
              children: [
                _header(t),
                const SizedBox(height: AppDesignSystem.spacingL),
                _gameCard(
                  t,
                  icon: Icons.directions_run_rounded,
                  color: const Color(0xFF6BC5A0),
                  title: 'Carrera de la Fe',
                  subtitle: 'Turnos · ~2 min · El primero en llegar gana',
                  badge: '1 vs 1',
                  onTap: () => _open(const GameRaceScreen()),
                  delay: 100,
                ),
                const SizedBox(height: AppDesignSystem.spacingM),
                _gameCard(
                  t,
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFFE89E5C),
                  title: 'Duelo Relámpago',
                  subtitle: '60s cada uno · Más aciertos gana',
                  badge: '1 vs 1',
                  onTap: () => _open(const GameLightningScreen()),
                  delay: 160,
                ),
                const SizedBox(height: AppDesignSystem.spacingM),
                _gameCard(
                  t,
                  icon: Icons.theater_comedy_rounded,
                  color: const Color(0xFFB68EE8),
                  title: '¿Quién soy?',
                  subtitle: 'Personajes bíblicos · Modo fiesta · Sin ganador',
                  badge: 'GRUPO',
                  onTap: () => _open(const GameHeadbanzScreen()),
                  delay: 220,
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
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppDesignSystem.gold.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sports_esports_rounded,
                color: AppDesignSystem.gold, size: 30),
          ),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reta a alguien',
                  style: AppDesignSystem.headlineSmall(context,
                      color: t.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pasen el celular y aprendan jugando. Partidas rápidas de 1-2 minutos.',
                  style: AppDesignSystem.bodyMedium(context,
                      color: t.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameCard(
    AppThemeData t, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
    required int delay,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
          boxShadow: t.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppDesignSystem.headlineSmall(context,
                              color: t.textPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusFull),
                          border: Border.all(
                              color: AppDesignSystem.gold.withOpacity(0.5)),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: AppDesignSystem.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppDesignSystem.bodyMedium(context,
                        color: t.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: t.textSecondary),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: delay.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Future<void> _open(Widget screen) async {
    FeedbackEngine.I.tap();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) setState(() {});
  }
}
