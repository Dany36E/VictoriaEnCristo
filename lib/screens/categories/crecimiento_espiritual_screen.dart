import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home/category_hub_scaffold.dart';
import '../../widgets/home/glassmorphic_menu_button.dart';
import '../learning/learning_home_screen.dart';
import '../bible/bible_home_screen.dart';

/// Sub-hub "Crecimiento Espiritual": antes era "CRECIMIENTO" en el Home.
///
/// Incluye la Escuela del Reino (movida desde Práctica Diaria a petición del
/// usuario) y la Biblia. La sección "Planes" está oculta temporalmente.
class CrecimientoEspiritualScreen extends StatelessWidget {
  const CrecimientoEspiritualScreen({super.key});

  static const Color _accent = Color(0xFFE8C97A);

  @override
  Widget build(BuildContext context) {
    return CategoryHubScaffold(
      title: 'Crecimiento Espiritual',
      children: [
        _buildIntro(),
        const SizedBox(height: AppDesignSystem.spacingL),
        Row(
          children: [
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.school_rounded,
                title: 'Escuela del Reino',
                subtitle: 'Aprende y memoriza',
                accentColor: AppDesignSystem.gold,
                animationType: IconAnimationType.shimmer,
                index: 0,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LearningHomeScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.menu_book,
                title: 'La Biblia',
                subtitle: 'Palabra de Dios',
                accentColor: const Color(0xFFE8C97A),
                animationType: IconAnimationType.shimmer,
                index: 1,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BibleHomeScreen()),
                ),
              ),
            ),
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
              const Icon(Icons.trending_up_rounded, color: _accent, size: 22),
              const SizedBox(width: AppDesignSystem.spacingS),
              Expanded(
                child: Text(
                  'Profundiza en la Palabra y crece en tu caminar con Dios.',
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
