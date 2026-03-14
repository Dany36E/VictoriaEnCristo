/// ═══════════════════════════════════════════════════════════════════════════
/// VICTORY DAY MODEL - Modelo de día de victoria para Cloud Sync
/// Representa un documento en /users/{uid}/victoryDays/{dateISO}
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class VictoryDay {
  final String dateISO; // YYYY-MM-DD
  final Map<String, int> giants; // {giantId: 0|1}
  final int victoriesCount;
  final int totalGiants;
  final int requiredVictories;
  final bool isVictoryDay;
  final DateTime updatedAt;
  
  const VictoryDay({
    required this.dateISO,
    required this.giants,
    required this.victoriesCount,
    required this.totalGiants,
    required this.requiredVictories,
    required this.isVictoryDay,
    required this.updatedAt,
  });
  
  /// Crear desde documento Firestore
  factory VictoryDay.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    return VictoryDay(
      dateISO: doc.id,
      giants: _toIntMap(data['giants']),
      victoriesCount: data['victoriesCount'] as int? ?? 0,
      totalGiants: data['totalGiants'] as int? ?? 0,
      requiredVictories: data['requiredVictories'] as int? ?? 1,
      isVictoryDay: data['isVictoryDay'] as bool? ?? false,
      updatedAt: _timestampToDateTime(data['updatedAt']) ?? DateTime.now(),
    );
  }
  
  /// Crear desde Map Firestore (para batch reads)
  factory VictoryDay.fromMap(String dateISO, Map<String, dynamic> data) {
    return VictoryDay(
      dateISO: dateISO,
      giants: _toIntMap(data['giants']),
      victoriesCount: data['victoriesCount'] as int? ?? 0,
      totalGiants: data['totalGiants'] as int? ?? 0,
      requiredVictories: data['requiredVictories'] as int? ?? 1,
      isVictoryDay: data['isVictoryDay'] as bool? ?? false,
      updatedAt: _timestampToDateTime(data['updatedAt']) ?? DateTime.now(),
    );
  }
  
  /// Crear desde Map local (SharedPreferences/Cache)
  factory VictoryDay.fromLocal(String dateISO, Map<String, dynamic> data) {
    return VictoryDay(
      dateISO: dateISO,
      giants: _toIntMap(data['giants']),
      victoriesCount: data['victoriesCount'] as int? ?? 0,
      totalGiants: data['totalGiants'] as int? ?? 0,
      requiredVictories: data['requiredVictories'] as int? ?? 1,
      isVictoryDay: data['isVictoryDay'] as bool? ?? false,
      updatedAt: DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
  
  /// Crear nuevo día con estados de gigantes
  factory VictoryDay.create({
    required String dateISO,
    required Map<String, int> giants,
    required double threshold,
  }) {
    final totalGiants = giants.length;
    final victoriesCount = giants.values.where((v) => v == 1).length;
    final requiredVictories = (threshold * totalGiants).ceil().clamp(1, totalGiants);
    final isVictory = victoriesCount >= requiredVictories;
    
    return VictoryDay(
      dateISO: dateISO,
      giants: giants,
      victoriesCount: victoriesCount,
      totalGiants: totalGiants,
      requiredVictories: requiredVictories,
      isVictoryDay: isVictory,
      updatedAt: DateTime.now(),
    );
  }
  
  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'giants': giants,
      'victoriesCount': victoriesCount,
      'totalGiants': totalGiants,
      'requiredVictories': requiredVictories,
      'isVictoryDay': isVictoryDay,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  /// Convertir a Map para almacenamiento local
  Map<String, dynamic> toLocal() {
    return {
      'giants': giants,
      'victoriesCount': victoriesCount,
      'totalGiants': totalGiants,
      'requiredVictories': requiredVictories,
      'isVictoryDay': isVictoryDay,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
  
  /// Crear copia con campos actualizados
  VictoryDay copyWith({
    Map<String, int>? giants,
    double? threshold,
  }) {
    final newGiants = giants ?? this.giants;
    final newTotalGiants = newGiants.length;
    final newVictoriesCount = newGiants.values.where((v) => v == 1).length;
    final t = threshold ?? (requiredVictories / totalGiants);
    final newRequiredVictories = (t * newTotalGiants).ceil().clamp(1, newTotalGiants);
    
    return VictoryDay(
      dateISO: dateISO,
      giants: newGiants,
      victoriesCount: newVictoriesCount,
      totalGiants: newTotalGiants,
      requiredVictories: newRequiredVictories,
      isVictoryDay: newVictoriesCount >= newRequiredVictories,
      updatedAt: DateTime.now(),
    );
  }
  
  /// Obtener DateTime del día
  DateTime? get date {
    try {
      final parts = dateISO.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (e) {
      return null;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  static DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
  
  static Map<String, int> _toIntMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(
        k.toString(),
        (v is int) ? v : (v is num) ? v.toInt() : 0,
      ));
    }
    return {};
  }
  
  @override
  String toString() => 'VictoryDay($dateISO: $victoriesCount/$totalGiants ${isVictoryDay ? "⭐" : "✝"})';
}
