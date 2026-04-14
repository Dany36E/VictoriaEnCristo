/// ═══════════════════════════════════════════════════════════════════════════
/// GIANT FREQUENCY MODEL
/// Modelos para frecuencia de lucha por gigante
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';

/// Frecuencias de lucha disponibles
enum BattleFrequency {
  daily,           // Diario
  severalPerWeek,  // Varias veces por semana
  weekly,          // Semanal
  occasional,      // Ocasional
}

/// Extension para obtener propiedades de la frecuencia
extension BattleFrequencyExtension on BattleFrequency {
  /// ID para serialización
  String get id {
    switch (this) {
      case BattleFrequency.daily:
        return 'daily';
      case BattleFrequency.severalPerWeek:
        return 'several_per_week';
      case BattleFrequency.weekly:
        return 'weekly';
      case BattleFrequency.occasional:
        return 'occasional';
    }
  }
  
  /// Nombre legible
  String get displayName {
    switch (this) {
      case BattleFrequency.daily:
        return 'Diario';
      case BattleFrequency.severalPerWeek:
        return 'Varias veces por semana';
      case BattleFrequency.weekly:
        return 'Semanal';
      case BattleFrequency.occasional:
        return 'Ocasional';
    }
  }
  
  /// Descripción corta
  String get description {
    switch (this) {
      case BattleFrequency.daily:
        return 'Lucho con esto todos los días';
      case BattleFrequency.severalPerWeek:
        return 'Me afecta varias veces por semana';
      case BattleFrequency.weekly:
        return 'Una vez por semana aproximadamente';
      case BattleFrequency.occasional:
        return 'Aparece de vez en cuando';
    }
  }
  
  /// Emoji representativo
  String get emoji {
    switch (this) {
      case BattleFrequency.daily:
        return '🔥';
      case BattleFrequency.severalPerWeek:
        return '⚡';
      case BattleFrequency.weekly:
        return '📅';
      case BattleFrequency.occasional:
        return '🌙';
    }
  }
  
  /// Crear desde string ID
  static BattleFrequency? fromId(String? id) {
    if (id == null) return null;
    switch (id) {
      case 'daily':
        return BattleFrequency.daily;
      case 'several_per_week':
        return BattleFrequency.severalPerWeek;
      case 'weekly':
        return BattleFrequency.weekly;
      case 'occasional':
        return BattleFrequency.occasional;
      default:
        return null;
    }
  }
}

/// Datos de un gigante con su frecuencia asignada
class GiantWithFrequency {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final BattleFrequency? frequency;
  
  const GiantWithFrequency({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    this.frequency,
  });
  
  /// Crear copia con frecuencia actualizada
  GiantWithFrequency copyWith({BattleFrequency? frequency}) {
    return GiantWithFrequency(
      id: id,
      name: name,
      emoji: emoji,
      description: description,
      frequency: frequency ?? this.frequency,
    );
  }
  
  /// ¿Tiene frecuencia asignada?
  bool get hasFrequency => frequency != null;
}

/// Lista estática de todos los gigantes disponibles
class Giants {
  static const List<Map<String, String>> all = [
    {
      'id': 'digital',
      'name': 'Mundo Digital',
      'emoji': '📱',
      'description': 'Redes sociales, videojuegos, doom scrolling',
    },
    {
      'id': 'sexual',
      'name': 'Pureza Sexual',
      'emoji': '🔞',
      'description': 'Pornografía, lujuria, pensamientos impuros',
    },
    {
      'id': 'health',
      'name': 'Cuerpo & Salud',
      'emoji': '🍬',
      'description': 'Glotonería, desorden alimenticio, sedentarismo',
    },
    {
      'id': 'substances',
      'name': 'Sustancias',
      'emoji': '🥃',
      'description': 'Alcohol, tabaco, drogas, dependencias',
    },
    {
      'id': 'mental',
      'name': 'Batallas Mentales',
      'emoji': '🤯',
      'description': 'Ansiedad, depresión, pensamientos negativos',
    },
    {
      'id': 'emotions',
      'name': 'Emociones Tóxicas',
      'emoji': '💔',
      'description': 'Ira, resentimiento, falta de perdón, envidia',
    },
  ];
  
  /// Obtener datos de un gigante por ID
  static Map<String, String>? getById(String id) {
    try {
      return all.firstWhere((g) => g['id'] == id);
    } catch (e) {
      debugPrint('⚠️ [GiantData] getById($id): $e');
      return null;
    }
  }
  
  /// Crear GiantWithFrequency desde ID
  static GiantWithFrequency? fromId(String id, {BattleFrequency? frequency}) {
    final data = getById(id);
    if (data == null) return null;
    return GiantWithFrequency(
      id: data['id']!,
      name: data['name']!,
      emoji: data['emoji']!,
      description: data['description']!,
      frequency: frequency,
    );
  }
}
