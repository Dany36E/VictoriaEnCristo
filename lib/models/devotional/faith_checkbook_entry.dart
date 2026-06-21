/// ═══════════════════════════════════════════════════════════════════════════
/// FaithCheckbookEntry — una lectura diaria de "La Chequera del Banco de la Fe"
/// (Charles H. Spurgeon).
///
/// Contenido reproducido verbatim desde Gospel Translations (Traducciones
/// Evangelio), traducción al español por Allan Aviles, marcado como Dominio
/// Público. Ver atribución en la pantalla de Devocional.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';

@immutable
class FaithCheckbookEntry {
  /// "cheq_06_19"
  final String id;

  /// 1..12
  final int month;

  /// 1..31
  final int day;

  /// "19 de Junio"
  final String dateLabel;

  /// Texto del versículo-promesa (Reina-Valera).
  final String verse;

  /// Referencia, p.ej. "Salmo 119:80".
  final String verseReference;

  /// Meditación de Spurgeon. Párrafos separados por "\n\n".
  final String meditation;

  const FaithCheckbookEntry({
    required this.id,
    required this.month,
    required this.day,
    required this.dateLabel,
    required this.verse,
    required this.verseReference,
    required this.meditation,
  });

  /// Párrafos de la meditación, ya divididos.
  List<String> get meditationParagraphs => meditation
      .split('\n\n')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList(growable: false);

  factory FaithCheckbookEntry.fromJson(Map<String, dynamic> j) =>
      FaithCheckbookEntry(
        id: j['id'] as String,
        month: (j['month'] as num).toInt(),
        day: (j['day'] as num).toInt(),
        dateLabel: j['dateLabel'] as String,
        verse: j['verse'] as String,
        verseReference: j['verseReference'] as String,
        meditation: j['meditation'] as String,
      );
}
