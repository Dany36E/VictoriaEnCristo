import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/content_enums.dart';
import '../models/content_item.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// CONTENT REPOSITORY
/// Carga, cachea y proporciona acceso a todo el contenido de la app
/// Diseñado para offline-first con assets locales
/// ═══════════════════════════════════════════════════════════════════════════

class ContentRepository {
  // Singleton
  static final ContentRepository _instance = ContentRepository._internal();
  factory ContentRepository() => _instance;
  ContentRepository._internal();
  
  /// Shortcut para acceso rápido
  static ContentRepository get I => _instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE EN MEMORIA
  // ═══════════════════════════════════════════════════════════════════════════
  
  List<VerseItem>? _verses;
  List<PrayerItem>? _prayers;
  List<JournalPromptItem>? _journalPrompts;
  List<ExerciseItem>? _exercises;
  
  bool _isInitialized = false;
  
  /// Verificar si está inicializado
  bool get isInitialized => _isInitialized;

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inicializar el repositorio cargando todos los assets
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      await Future.wait([
        _loadVerses(),
        _loadPrayers(),
        _loadJournalPrompts(),
        _loadExercises(),
      ]);
      _isInitialized = true;
      debugPrint('✅ ContentRepository inicializado');
    } catch (e) {
      debugPrint('⚠️ Error inicializando ContentRepository: $e');
      // Inicializar con listas vacías para evitar crashes
      _verses ??= [];
      _prayers ??= [];
      _journalPrompts ??= [];
      _exercises ??= [];
      _isInitialized = true;
    }
  }

  /// Cargar versículos desde JSON
  Future<void> _loadVerses() async {
    try {
      final jsonString = await rootBundle.loadString('assets/content/verses.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _verses = jsonList.map((j) => VerseItem.fromJson(j as Map<String, dynamic>)).toList();
      debugPrint('📖 Cargados ${_verses!.length} versículos');
    } catch (e) {
      debugPrint('⚠️ Error cargando verses.json: $e');
      _verses = [];
    }
  }

  /// Cargar oraciones desde JSON
  Future<void> _loadPrayers() async {
    try {
      final jsonString = await rootBundle.loadString('assets/content/prayers.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _prayers = jsonList.map((j) => PrayerItem.fromJson(j as Map<String, dynamic>)).toList();
      debugPrint('🙏 Cargadas ${_prayers!.length} oraciones');
    } catch (e) {
      debugPrint('⚠️ Error cargando prayers.json: $e');
      _prayers = [];
    }
  }

  /// Cargar prompts de diario desde JSON
  Future<void> _loadJournalPrompts() async {
    try {
      final jsonString = await rootBundle.loadString('assets/content/journal_prompts.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _journalPrompts = jsonList.map((j) => JournalPromptItem.fromJson(j as Map<String, dynamic>)).toList();
      debugPrint('✍️ Cargados ${_journalPrompts!.length} prompts de diario');
    } catch (e) {
      debugPrint('⚠️ Error cargando journal_prompts.json: $e');
      _journalPrompts = [];
    }
  }

  /// Cargar ejercicios desde JSON
  Future<void> _loadExercises() async {
    try {
      final jsonString = await rootBundle.loadString('assets/content/exercises.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _exercises = jsonList.map((j) => ExerciseItem.fromJson(j as Map<String, dynamic>)).toList();
      debugPrint('💪 Cargados ${_exercises!.length} ejercicios');
    } catch (e) {
      debugPrint('⚠️ Error cargando exercises.json: $e');
      _exercises = [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS BÁSICOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Todos los versículos
  List<VerseItem> get verses => _verses ?? [];
  
  /// Todas las oraciones
  List<PrayerItem> get prayers => _prayers ?? [];
  
  /// Todos los prompts de diario
  List<JournalPromptItem> get journalPrompts => _journalPrompts ?? [];
  
  /// Todos los ejercicios
  List<ExerciseItem> get exercises => _exercises ?? [];

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTROS POR METADATA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Filtrar contenido por gigantes
  List<T> filterByGiants<T extends ContentItem>(
    List<T> items, 
    List<GiantId> giants,
  ) {
    if (giants.isEmpty) return items;
    return items.where((item) => 
      item.metadata.appliesToAnyGiant(giants)
    ).toList();
  }

  /// Filtrar contenido por etapa
  List<T> filterByStage<T extends ContentItem>(
    List<T> items, 
    ContentStage stage,
  ) {
    return items.where((item) => item.metadata.stage == stage).toList();
  }

  /// Filtrar contenido aprobado (excluir drafts)
  List<T> filterApproved<T extends ContentItem>(List<T> items) {
    return items.where((item) => 
      item.metadata.reviewLevel != ReviewLevel.draft
    ).toList();
  }

  /// Filtrar contenido por gatillos
  List<T> filterByTriggers<T extends ContentItem>(
    List<T> items,
    List<TriggerId> triggers,
  ) {
    if (triggers.isEmpty) return items;
    return items.where((item) =>
      item.metadata.triggers.any((t) => triggers.contains(t))
    ).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE CONSULTA ESPECÍFICOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener versículos para gigantes específicos
  List<VerseItem> getVersesForGiants(List<GiantId> giants) {
    return filterApproved(filterByGiants(verses, giants));
  }

  /// Obtener versículos para crisis
  List<VerseItem> getCrisisVerses() {
    return filterApproved(filterByStage(verses, ContentStage.crisis));
  }

  /// Obtener oraciones para gigantes específicos
  List<PrayerItem> getPrayersForGiants(List<GiantId> giants) {
    return filterApproved(filterByGiants(prayers, giants));
  }

  /// Obtener oraciones de emergencia
  List<PrayerItem> getEmergencyPrayers() {
    return filterApproved(filterByStage(prayers, ContentStage.crisis));
  }

  /// Obtener oraciones de restauración
  List<PrayerItem> getRestorationPrayers() {
    return filterApproved(filterByStage(prayers, ContentStage.restoration));
  }

  /// Obtener prompts de diario para un gigante
  List<JournalPromptItem> getPromptsForGiant(GiantId giant) {
    return filterApproved(filterByGiants(journalPrompts, [giant]));
  }

  /// Obtener ejercicios para crisis
  List<ExerciseItem> getCrisisExercises() {
    return filterApproved(filterByStage(exercises, ContentStage.crisis));
  }

  /// Obtener ejercicios para un gatillo específico
  List<ExerciseItem> getExercisesForTrigger(TriggerId trigger) {
    return filterApproved(filterByTriggers(exercises, [trigger]));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BÚSQUEDA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Buscar en todo el contenido
  List<ContentItem> search(String query) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    final results = <ContentItem>[];
    
    for (final verse in verses) {
      if (verse.title.toLowerCase().contains(lowerQuery) ||
          verse.reference.toLowerCase().contains(lowerQuery)) {
        results.add(verse);
      }
    }
    
    for (final prayer in prayers) {
      if (prayer.title.toLowerCase().contains(lowerQuery) ||
          prayer.body.toLowerCase().contains(lowerQuery)) {
        results.add(prayer);
      }
    }
    
    for (final prompt in journalPrompts) {
      if (prompt.title.toLowerCase().contains(lowerQuery)) {
        results.add(prompt);
      }
    }
    
    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener un item aleatorio de una lista
  T? getRandomItem<T>(List<T> items) {
    if (items.isEmpty) return null;
    items.shuffle();
    return items.first;
  }

  /// Obtener versículo aleatorio para un gigante
  VerseItem? getRandomVerseForGiant(GiantId giant) {
    final filtered = getVersesForGiants([giant]);
    return getRandomItem(filtered);
  }

  /// Obtener oración aleatoria para un gigante
  PrayerItem? getRandomPrayerForGiant(GiantId giant) {
    final filtered = getPrayersForGiants([giant]);
    return getRandomItem(filtered);
  }

  /// Limpiar cache (útil para hot reload en desarrollo)
  void clearCache() {
    _verses = null;
    _prayers = null;
    _journalPrompts = null;
    _exercises = null;
    _isInitialized = false;
  }

  /// Estadísticas del contenido cargado
  Map<String, int> get stats => {
    'verses': verses.length,
    'prayers': prayers.length,
    'journalPrompts': journalPrompts.length,
    'exercises': exercises.length,
  };
}
