/// Sección de versículo diario con tarjeta glassmorphic.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/bible_verses.dart';
import '../../vec/vec_widgets.dart';

class DailyVerseSection extends StatelessWidget {
  final BibleVerse dailyVerse;
  final void Function(String reference) onTapVerse;

  const DailyVerseSection({
    super.key,
    required this.dailyVerse,
    required this.onTapVerse,
  });

  @override
  Widget build(BuildContext context) {
    return _buildPapel();
  }

  /// Tarjeta de versículo del kit (referencia en terracota y
  /// texto en Patrick Hand).
  Widget _buildPapel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EtiquetaSeccion('Versículo del día'),
        // Aire para la cinta de la tarjeta (sobresale 12 px hacia arriba).
        const SizedBox(height: 24),
        Semantics(
          button: true,
          label:
              'Versículo del día: ${dailyVerse.reference}. Toca para leer en contexto',
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onTapVerse(dailyVerse.reference);
            },
            child: PopIn(
              retraso: const Duration(milliseconds: 120),
              child: TarjetaVersiculo(
                referencia: dailyVerse.reference,
                texto: dailyVerse.verse,
                version: '',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

