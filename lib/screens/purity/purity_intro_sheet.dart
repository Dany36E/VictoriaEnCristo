import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
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
