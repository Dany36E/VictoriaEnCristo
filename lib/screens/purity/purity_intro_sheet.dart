import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';
import 'purity_guard_screen.dart';

/// Hoja de sugerencia que aparece tras elegir el gigante "Pureza Sexual".
/// Ofrece configurar el Escudo de Pureza (bloqueador de contenido adulto).
Future<void> showPuritySuggestionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PuritySuggestionSheet(),
  );
}

class _PuritySuggestionSheet extends StatelessWidget {
  const _PuritySuggestionSheet();

  void _configurar(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PurityGuardScreen()),
    );
  }

  /// Tema papel: hoja de papel con Victoria presentando el escudo.
  Widget _buildPapel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VecColores.papel,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(VecRadios.l),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: VecColores.cremaOscuro,
                borderRadius: BorderRadius.circular(VecRadios.pildora),
              ),
            ),
            const SizedBox(height: 14),
            PopIn(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Sticker('assets/vec/personajes/victoria_presenta.png', alto: 130),
                  const SizedBox(width: 8),
                  CirculoIcono(
                    iconoVec: 'escudo',
                    color: VecColores.azul,
                    tamano: 72,
                    giro: -6,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const TituloVec(
              'Un escudo para tu pureza',
              clave: 'escudo',
              tamano: 26,
              alineacion: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Elegiste luchar por tu pureza sexual. La app puede bloquear las '
              'páginas de contenido adulto y, cuando aparezca la tentación, '
              'traerte de vuelta a un lugar seguro.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: VecFuentes.texto,
                fontSize: 18,
                height: 1.3,
                color: VecColores.tinta,
              ),
            ),
            const SizedBox(height: 22),
            BotonVec(
              texto: 'Configurar protección',
              iconoWidget: const IconoVec('escudo'),
              expandido: true,
              onPressed: () => _configurar(context),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ahora no'),
            ),
            Text(
              'Puedes activarlo cuando quieras en Ajustes → Protección.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: VecFuentes.texto,
                fontSize: 15,
                color: VecColores.gris,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppThemeData.of(context).isPaper) return _buildPapel(context);
    const gold = AppDesignSystem.gold;
    return Container(
      decoration: const BoxDecoration(
        color: AppDesignSystem.midnightLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: gold.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.shield_moon_rounded,
                  color: gold, size: 34),
            ),
            const SizedBox(height: 18),
            const Text(
              'Un escudo para tu pureza',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Elegiste luchar por tu pureza sexual. La app puede bloquear las '
              'páginas de contenido adulto y, cuando aparezca la tentación, '
              'traerte de vuelta a un lugar seguro.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PurityGuardScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: AppDesignSystem.midnight,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.security, size: 20),
                label: const Text(
                  'Configurar protección',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Ahora no',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Puedes activarlo cuando quieras en Ajustes → Protección.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
