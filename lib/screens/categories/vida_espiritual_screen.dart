import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home/category_hub_scaffold.dart';
import '../../widgets/home/glassmorphic_menu_button.dart';
import '../prayers_screen.dart';
import '../verses_screen.dart';
import '../journal_screen.dart';
import '../devotional_screen.dart';
import '../progress_screen.dart';

/// Sub-hub "Vida Espiritual": agrupa las prácticas espirituales diarias del
/// usuario. Antes vivía dentro del Home como sección "PRÁCTICA DIARIA".
///
/// Contiene: Oraciones, Mapa de Oración (antes Mi Diario), Versículos,
/// Devocional y Mi Progreso.
class VidaEspiritualScreen extends StatelessWidget {
  const VidaEspiritualScreen({super.key});

  static const Color _accent = Color(0xFFFF80AB);

  @override
  Widget build(BuildContext context) {
    return CategoryHubScaffold(
      title: 'Vida Espiritual',
      children: [
        _buildIntro(),
        const SizedBox(height: AppDesignSystem.spacingL),
        Row(
          children: [
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.favorite,
                title: 'Oraciones',
                subtitle: 'Conexión con Dios',
                accentColor: const Color(0xFFFF80AB),
                animationType: IconAnimationType.heartbeat,
                index: 0,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrayersScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.map_outlined,
                title: 'Mapa de Oración',
                subtitle: 'Guía diaria',
                accentColor: const Color(0xFFCE93D8),
                animationType: IconAnimationType.pulse,
                index: 1,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JournalScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        Row(
          children: [
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.menu_book_outlined,
                title: 'Versículos',
                subtitle: 'Armadura espiritual',
                accentColor: const Color(0xFF64B5F6),
                animationType: IconAnimationType.shimmer,
                index: 2,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VersesScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.auto_stories_rounded,
                title: 'Devocional',
                subtitle: '30 días de fe',
                accentColor: const Color(0xFFFFD180),
                animationType: IconAnimationType.shimmer,
                index: 3,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DevotionalScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        Row(
          children: [
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.show_chart,
                title: 'Mi Progreso',
                subtitle: 'Días de victoria',
                accentColor: const Color(0xFF69F0AE),
                animationType: IconAnimationType.drawUp,
                index: 4,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProgressScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildIntro() {
    return Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
            border: Border.all(color: _accent.withValues(alpha: 0.2), width: 0.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.wb_sunny_outlined, color: _accent, size: 22),
              const SizedBox(width: AppDesignSystem.spacingS),
              Expanded(
                child: Text(
                  'Tu encuentro diario con Dios: oración, palabra y reflexión.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
