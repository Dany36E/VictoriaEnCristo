import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'daily_practice_service.dart';

/// Modelo para una entrada del diario
class JournalEntry {
  final String id;
  final DateTime date;
  final String content;
  final String mood; // 'victory', 'struggle', 'neutral', 'grateful'
  final List<String> triggers; // Situaciones que causaron tentación
  final bool hadVictory;
  final String? verseOfDay;

  JournalEntry({
    required this.id,
    required this.date,
    required this.content,
    required this.mood,
    this.triggers = const [],
    this.hadVictory = true,
    this.verseOfDay,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'content': content,
    'mood': mood,
    'triggers': triggers,
    'hadVictory': hadVictory,
    'verseOfDay': verseOfDay,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final date = json['date'];
    final content = json['content'];
    final mood = json['mood'];
    if (id is! String || date is! String || content is! String || mood is! String) {
      throw FormatException(
        'JournalEntry.fromJson: campos requeridos nulos o tipo incorrecto '
        '(id=$id, date=$date, content=${content?.runtimeType}, mood=$mood)',
      );
    }
    return JournalEntry(
      id: id,
      date: DateTime.parse(date),
      content: content,
      mood: mood,
      triggers: List<String>.from(json['triggers'] ?? []),
      hadVictory: json['hadVictory'] ?? true,
      verseOfDay: json['verseOfDay'],
    );
  }
}

/// Servicio para manejar el diario personal
class JournalService {
  static const String _entriesKey = 'journal_entries';

  // Singleton
  static final JournalService _instance = JournalService._internal();
  factory JournalService() => _instance;
  JournalService._internal();

  List<JournalEntry> _entries = [];

  List<JournalEntry> get entries => List.unmodifiable(_entries);

  /// Notificador reactivo: se incrementa con cada cambio (add/update/delete/restore).
  /// Widgets que necesiten reactividad deben escuchar este notifier.
  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  void _notifyChange() {
    changeNotifier.value++;
  }

  /// Callbacks para write-through a cloud (lo configura JournalSyncAdapter)
  /// Evita import circular: JournalService no importa el adapter.
  void Function(JournalEntry entry)? onEntryAdded;
  void Function(JournalEntry entry)? onEntryUpdated;
  void Function(String id)? onEntryDeleted;

  // Lista de triggers comunes para sugerencias
  static const List<String> commonTriggers = [
    'Soledad',
    'Aburrimiento',
    'Estrés',
    'Noche',
    'Redes sociales',
    'Cansancio',
    'Tristeza',
    'Ansiedad',
    'Enojo',
    'Insomnio',
  ];

  // Emojis para estados de ánimo
  static const Map<String, String> moodEmojis = {
    'victory': '🏆',
    'struggle': '😔',
    'neutral': '😐',
    'grateful': '🙏',
  };

  static const Map<String, String> moodLabels = {
    'victory': 'Victoria',
    'struggle': 'Lucha',
    'neutral': 'Neutral',
    'grateful': 'Agradecido',
  };

  /// Inicializar servicio
  Future<void> initialize() async {
    await _loadEntries();
  }

  /// Cargar entradas guardadas
  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString(_entriesKey);

    if (entriesJson != null) {
      final List<dynamic> decoded = jsonDecode(entriesJson);
      final List<JournalEntry> loaded = [];
      for (final e in decoded) {
        try {
          loaded.add(JournalEntry.fromJson(e));
        } catch (err) {
          debugPrint('JournalService: entrada corrupta ignorada: $err');
        }
      }
      _entries = loaded;
      _entries.sort((a, b) => b.date.compareTo(a.date)); // Más recientes primero
    }
  }

  /// Guardar entradas
  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_entriesKey, entriesJson);
  }

  /// Agregar nueva entrada
  Future<void> addEntry(JournalEntry entry) async {
    _entries.insert(0, entry); // Agregar al inicio
    await _saveEntries();
    _notifyChange();
    // Marca la práctica "diario" del día.
    try {
      DailyPracticeService.I.mark(DailyPractice.journal);
    } catch (_) {}
    // Write-through: notificar al sync adapter para subir a cloud
    onEntryAdded?.call(entry);
  }

  /// Actualizar entrada existente
  Future<void> updateEntry(JournalEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      await _saveEntries();
      _notifyChange();
      // Write-through: notificar al sync adapter para actualizar en cloud
      onEntryUpdated?.call(entry);
    }
  }

  /// Eliminar entrada
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _saveEntries();
    _notifyChange();
    // Write-through: notificar al sync adapter para eliminar de cloud
    onEntryDeleted?.call(id);
  }

  /// Obtener entrada por ID
  JournalEntry? getEntry(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Restaurar entradas desde cloud (llamado después de que JournalRepository
  /// descarga datos de Firestore). Hidrata el servicio local sin upload.
  Future<void> restoreFromCloud(List<JournalEntry> cloudEntries) async {
    _entries = List.from(cloudEntries);
    _entries.sort((a, b) => b.date.compareTo(a.date));
    await _saveEntries();
    _notifyChange();

    debugPrint('📓 [JOURNAL_SVC] restoreFromCloud: ✅ hydrated ${cloudEntries.length} entries');
  }

  /// Obtener entradas de hoy
  List<JournalEntry> getTodayEntries() {
    final today = DateTime.now();
    return _entries
        .where(
          (e) =>
              e.date.year == today.year && e.date.month == today.month && e.date.day == today.day,
        )
        .toList();
  }

  /// Obtener entradas de los últimos N días
  List<JournalEntry> getRecentEntries(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _entries.where((e) => e.date.isAfter(cutoff)).toList();
  }

  /// Obtener estadísticas de triggers
  Map<String, int> getTriggerStats() {
    final stats = <String, int>{};
    for (final entry in _entries) {
      for (final trigger in entry.triggers) {
        stats[trigger] = (stats[trigger] ?? 0) + 1;
      }
    }
    return Map.fromEntries(stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  /// Obtener estadísticas de ánimo
  Map<String, int> getMoodStats() {
    final stats = <String, int>{};
    for (final entry in _entries) {
      stats[entry.mood] = (stats[entry.mood] ?? 0) + 1;
    }
    return stats;
  }

  /// Obtener entrada para una fecha específica
  /// Retorna la primera entrada del día o null si no hay
  JournalEntry? getEntryForDate(DateTime date) {
    try {
      return _entries.firstWhere(
        (e) => e.date.year == date.year && e.date.month == date.month && e.date.day == date.day,
      );
    } catch (e) {
      return null;
    }
  }

  /// Obtener todas las entradas para una fecha específica
  List<JournalEntry> getEntriesForDate(DateTime date) {
    return _entries
        .where(
          (e) => e.date.year == date.year && e.date.month == date.month && e.date.day == date.day,
        )
        .toList();
  }

  /// Obtener porcentaje de victorias
  double getVictoryPercentage() {
    if (_entries.isEmpty) return 0;
    final victories = _entries.where((e) => e.hadVictory).length;
    return (victories / _entries.length) * 100;
  }

  /// Generar ID único
  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
