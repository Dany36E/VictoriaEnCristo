import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';
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


  @override
  Widget build(BuildContext context) {
    return CategoryHubScaffold(
      title: 'Crecimiento Espiritual',
      children: [
        _buildIntro(context),
        const SizedBox(height: AppDesignSystem.spacingL),
        Row(
          children: [
            Expanded(
              child: GlassmorphicMenuButton(
                icon: Icons.school_rounded,
                title: 'Escuela del Reino',
                subtitle: 'Aprende y memoriza',
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

  Widget _buildIntro(BuildContext context) {
    return PopIn(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Sticker(
            'assets/vec/personajes/timoteo_explica.png',
            alto: 120,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Subtitulo(
              quien: 'Timoteo',
              texto:
                  'Profundiza en la Palabra y crece en tu caminar con Dios.',
              clave: 'Palabra',
              color: VecColores.azul,
            ),
          ),
        ],
      ),
    );
  }
}
