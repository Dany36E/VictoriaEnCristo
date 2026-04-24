/// ═══════════════════════════════════════════════════════════════════════════
/// JOURNAL ENTRY MODEL - Modelo de entrada de diario para Cloud Sync
/// Representa un documento en /users/{uid}/journalEntries/{dateISO}
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/time_utils.dart';

class JournalEntryCloud {
  final String id;
  final String dateISO; // YYYY-MM-DD
  final DateTime timestamp;
  final String content;
  final String mood; // 'victory', 'struggle', 'neutral', 'grateful'
  final List<String> triggers;
  final bool hadVictory;
  final String? verseOfDay;
  final DateTime updatedAt;
  
  const JournalEntryCloud({
    required this.id,
    required this.dateISO,
    required this.timestamp,
    required this.content,
    required this.mood,
    this.triggers = const [],
    this.hadVictory = true,
    this.verseOfDay,
    required this.updatedAt,
  });
  
  /// Crear desde documento Firestore
  factory JournalEntryCloud.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    final timestamp = _timestampToDateTime(data['timestamp']) ?? DateTime.now();
    final dateISO = data['dateISO'] as String? ?? _dateToISO(timestamp);
    
    return JournalEntryCloud(
      id: doc.id,
      dateISO: dateISO,
      timestamp: timestamp,
      content: data['content'] as String? ?? '',
      mood: data['mood'] as String? ?? 'neutral',
      triggers: _toStringList(data['triggers']),
      hadVictory: data['hadVictory'] as bool? ?? true,
      verseOfDay: data['verseOfDay'] as String?,
      updatedAt: _timestampToDateTime(data['updatedAt']) ?? DateTime.now(),
    );
  }
  
  /// Crear desde Map local
  factory JournalEntryCloud.fromLocal(Map<String, dynamic> data) {
    final timestamp = DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now();
    
    return JournalEntryCloud(
      id: data['id'] as String? ?? '',
      dateISO: data['dateISO'] as String? ?? _dateToISO(timestamp),
      timestamp: timestamp,
      content: data['content'] as String? ?? '',
      mood: data['mood'] as String? ?? 'neutral',
      triggers: _toStringList(data['triggers']),
      hadVictory: data['hadVictory'] as bool? ?? true,
      verseOfDay: data['verseOfDay'] as String?,
      updatedAt: DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
  
  /// Crear nueva entrada
  factory JournalEntryCloud.create({
    required String content,
    required String mood,
    List<String> triggers = const [],
    bool hadVictory = true,
    String? verseOfDay,
    String? id,
  }) {
    final now = DateTime.now();
    return JournalEntryCloud(
      id: id ?? '${now.millisecondsSinceEpoch}',
      dateISO: _dateToISO(now),
      timestamp: now,
      content: content,
      mood: mood,
      triggers: triggers,
      hadVictory: hadVictory,
      verseOfDay: verseOfDay,
      updatedAt: now,
    );
  }
  
  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'dateISO': dateISO,
      'timestamp': Timestamp.fromDate(timestamp),
      'content': content,
      'mood': mood,
      'triggers': triggers,
      'hadVictory': hadVictory,
      'verseOfDay': verseOfDay,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  /// Convertir a Map para almacenamiento local
  Map<String, dynamic> toLocal() {
    return {
      'id': id,
      'dateISO': dateISO,
      'timestamp': timestamp.toIso8601String(),
      'content': content,
      'mood': mood,
      'triggers': triggers,
      'hadVictory': hadVictory,
      'verseOfDay': verseOfDay,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
  
  /// Crear copia con campos actualizados
  JournalEntryCloud copyWith({
    String? content,
    String? mood,
    List<String>? triggers,
    bool? hadVictory,
    String? verseOfDay,
  }) {
    return JournalEntryCloud(
      id: id,
      dateISO: dateISO,
      timestamp: timestamp,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      triggers: triggers ?? this.triggers,
      hadVictory: hadVictory ?? this.hadVictory,
      verseOfDay: verseOfDay ?? this.verseOfDay,
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
  
  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
  
  // Delegado a TimeUtils centralizado
  static String _dateToISO(DateTime date) => TimeUtils.dateToISO(date);
  
  @override
  String toString() => 'JournalEntryCloud($dateISO: $mood, ${content.length} chars)';
}
