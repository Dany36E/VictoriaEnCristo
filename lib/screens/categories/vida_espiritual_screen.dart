import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';
import '../../widgets/home/category_hub_scaffold.dart';
import '../../widgets/home/glassmorphic_menu_button.dart';
import '../verses_screen.dart';
import '../journal_screen.dart';
import '../devotional_screen.dart';
import '../progress_screen.dart';

/// Sub-hub "Vida Espiritual": agrupa las prácticas espirituales diarias del
/// usuario. Antes vivía dentro del Home como sección "PRÁCTICA DIARIA".
///
/// Contiene: Mapa de Oración (antes Mi Diario), Versículos, Devocional y
/// Mi Progreso.
class VidaEspiritualScreen extends StatelessWidget {
  const VidaEspiritualScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return CategoryHubScaffold(
      title: 'Vida Espiritual',
      children: [
        _buildIntro(context),
        const SizedBox(height: AppDesignSystem.spacingL),
        Row(
          children: [
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.map_outlined,
                title: 'Mapa de Oración',
                subtitle: 'Guía diaria',
                accentColor: const Color(0xFFCE93D8),
                animationType: IconAnimationType.pulse,
                index: 0,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JournalScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.menu_book_outlined,
                title: 'Versículos',
                subtitle: 'Armadura espiritual',
                accentColor: const Color(0xFF64B5F6),
                animationType: IconAnimationType.shimmer,
                index: 1,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VersesScreen()),
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
                icon: Icons.auto_stories_rounded,
                title: 'Devocional',
                subtitle: '30 días de fe',
                accentColor: const Color(0xFFFFD180),
                animationType: IconAnimationType.shimmer,
                index: 2,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DevotionalScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.show_chart,
                title: 'Mi Progreso',
                subtitle: 'Días de victoria',
                accentColor: const Color(0xFF69F0AE),
                animationType: IconAnimationType.drawUp,
                index: 3,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProgressScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntro(BuildContext context) {
    return PopIn(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Sticker('assets/vec/personajes/victoria_ora.png', alto: 120),
            const SizedBox(width: 8),
            Expanded(
              child: Subtitulo(
                quien: 'Victoria',
                texto:
                    'Tu encuentro diario con Dios: oración, palabra y reflexión.',
                clave: 'Dios',
                color: VecColores.terracota,
              ),
            ),
          ],
        ),
      );
  }
}
