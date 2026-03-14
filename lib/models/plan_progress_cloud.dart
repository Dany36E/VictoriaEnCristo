/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN PROGRESS MODEL - Modelo de progreso de plan para Cloud Sync
/// Representa un documento en /users/{uid}/plansProgress/{planId}
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class PlanProgressCloud {
  final String planId;
  final int lastDayRead;
  final Set<int> completedDays;
  final int currentStreak;
  final int bestStreak;
  final bool completed;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? lastCompletedAt;
  final DateTime updatedAt;
  
  const PlanProgressCloud({
    required this.planId,
    this.lastDayRead = 0,
    this.completedDays = const {},
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.completed = false,
    this.startedAt,
    this.completedAt,
    this.lastCompletedAt,
    required this.updatedAt,
  });
  
  /// Crear desde documento Firestore
  factory PlanProgressCloud.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    return PlanProgressCloud(
      planId: doc.id,
      lastDayRead: data['lastDayRead'] as int? ?? 0,
      completedDays: _toIntSet(data['completedDays']),
      currentStreak: data['currentStreak'] as int? ?? 0,
      bestStreak: data['bestStreak'] as int? ?? 0,
      completed: data['completed'] as bool? ?? false,
      startedAt: _timestampToDateTime(data['startedAt']),
      completedAt: _timestampToDateTime(data['completedAt']),
      lastCompletedAt: _timestampToDateTime(data['lastCompletedAt']),
      updatedAt: _timestampToDateTime(data['updatedAt']) ?? DateTime.now(),
    );
  }
  
  /// Crear desde Map local
  factory PlanProgressCloud.fromLocal(String planId, Map<String, dynamic> data) {
    return PlanProgressCloud(
      planId: planId,
      lastDayRead: data['lastDayRead'] as int? ?? 0,
      completedDays: _toIntSet(data['completedDays']),
      currentStreak: data['currentStreak'] as int? ?? 0,
      bestStreak: data['bestStreak'] as int? ?? 0,
      completed: data['completed'] as bool? ?? false,
      startedAt: DateTime.tryParse(data['startedAt'] ?? ''),
      completedAt: DateTime.tryParse(data['completedAt'] ?? ''),
      lastCompletedAt: DateTime.tryParse(data['lastCompletedAt'] ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
  
  /// Crear progreso nuevo para un plan
  factory PlanProgressCloud.create(String planId) {
    return PlanProgressCloud(
      planId: planId,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'lastDayRead': lastDayRead,
      'completedDays': completedDays.toList(),
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'completed': completed,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'lastCompletedAt': lastCompletedAt != null ? Timestamp.fromDate(lastCompletedAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  /// Convertir a Map para almacenamiento local
  Map<String, dynamic> toLocal() {
    return {
      'planId': planId,
      'lastDayRead': lastDayRead,
      'completedDays': completedDays.toList(),
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'completed': completed,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
  
  /// Crear copia con campos actualizados
  PlanProgressCloud copyWith({
    int? lastDayRead,
    Set<int>? completedDays,
    int? currentStreak,
    int? bestStreak,
    bool? completed,
    DateTime? completedAt,
    DateTime? lastCompletedAt,
  }) {
    return PlanProgressCloud(
      planId: planId,
      lastDayRead: lastDayRead ?? this.lastDayRead,
      completedDays: completedDays ?? this.completedDays,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      completed: completed ?? this.completed,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      updatedAt: DateTime.now(),
    );
  }
  
  /// Marcar día como completado
  PlanProgressCloud withDayCompleted(int dayIndex, int totalDays) {
    final newCompletedDays = Set<int>.from(completedDays)..add(dayIndex);
    final now = DateTime.now();
    
    // Calcular racha
    int newStreak = currentStreak;
    if (lastCompletedAt != null) {
      final yesterday = now.subtract(const Duration(days: 1));
      final wasYesterday = 
          lastCompletedAt!.year == yesterday.year &&
          lastCompletedAt!.month == yesterday.month &&
          lastCompletedAt!.day == yesterday.day;
      final wasToday = 
          lastCompletedAt!.year == now.year &&
          lastCompletedAt!.month == now.month &&
          lastCompletedAt!.day == now.day;
      
      if (wasYesterday) {
        newStreak = currentStreak + 1;
      } else if (!wasToday) {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }
    
    final newBestStreak = newStreak > bestStreak ? newStreak : bestStreak;
    final isCompleted = newCompletedDays.length >= totalDays;
    
    return copyWith(
      lastDayRead: dayIndex > lastDayRead ? dayIndex : lastDayRead,
      completedDays: newCompletedDays,
      currentStreak: newStreak,
      bestStreak: newBestStreak,
      completed: isCompleted,
      completedAt: isCompleted ? now : null,
      lastCompletedAt: now,
    );
  }
  
  /// Verificar si un día está completado
  bool isDayCompleted(int dayIndex) => completedDays.contains(dayIndex);
  
  /// Porcentaje de progreso
  double progressPercent(int totalDays) {
    if (totalDays == 0) return 0.0;
    return completedDays.length / totalDays;
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
  
  static Set<int> _toIntSet(dynamic value) {
    if (value is List) {
      return value.map((e) => (e is int) ? e : (e is num) ? e.toInt() : 0).toSet();
    }
    return {};
  }
  
  @override
  String toString() => 'PlanProgressCloud($planId: ${completedDays.length} days, streak: $currentStreak)';
}
