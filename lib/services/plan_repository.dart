/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN REPOSITORY - Carga y gestión de planes desde assets
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/plan.dart';
import '../models/plan_metadata.dart';
import '../models/content_enums.dart';

class PlanRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final PlanRepository _instance = PlanRepository._internal();
  factory PlanRepository() => _instance;
  PlanRepository._internal();
  
  static PlanRepository get I => _instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE
  // ═══════════════════════════════════════════════════════════════════════════
  
  List<Plan>? _plans;
  bool _isInitialized = false;
  
  bool get isInitialized => _isInitialized;
  
  /// Todos los planes publicados
  List<Plan> get plans => _plans?.where((p) => p.isPublished).toList() ?? [];
  
  /// Todos los planes (incluyendo drafts, para admin)
  List<Plan> get allPlans => _plans ?? [];
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Inicializar repositorio cargando planes desde assets
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      await _loadPlans();
      _isInitialized = true;
    } catch (e) {
      // Si falla, crear lista vacía para evitar crashes
      _plans = [];
      _isInitialized = true;
      rethrow;
    }
  }
  
  Future<void> _loadPlans() async {
    try {
      final jsonString = await rootBundle.loadString('assets/content/plans.json');
      final jsonData = json.decode(jsonString);
      
      final plansList = jsonData['plans'] as List<dynamic>? ?? [];
      final loadedPlans = <Plan>[];

      for (final raw in plansList) {
        final planJson = raw as Map<String, dynamic>;
        // Si tiene referencia externa de días y el array viene vacío, cargar desde archivo
        if ((planJson['days'] as List?)?.isEmpty != false &&
            (planJson['daysRef'] as String?) != null) {
          final ref = planJson['daysRef'] as String;
          final daysPath = 'assets/content/plan_days/$ref';
          try {
            final daysString = await rootBundle.loadString(daysPath);
            final daysJson = json.decode(daysString) as List<dynamic>;
            planJson['days'] = daysJson;
          } catch (e) {
            // fallback: lista vacía; no crashear
            planJson['days'] = <dynamic>[];
          }
        }

        final plan = Plan.fromJson(planJson);
        loadedPlans.add(plan);
      }

      _plans = loadedPlans;
      await _validateCovers();
      _printDebugSummary();
    } catch (e) {
      debugPrint('[PLANS-DBG] ERROR loading plans: $e');
      // Intentar cargar desde ubicación alternativa
      _plans = [];
    }
  }
  
  /// Valida que los covers existan y loguea los faltantes
  Future<void> _validateCovers() async {
    if (_plans == null) return;
    
    int validCount = 0;
    int missingCount = 0;
    
    for (final plan in _plans!) {
      if (plan.coverImage.isEmpty) {
        debugPrint('[PLANS-DBG] missingCover id=${plan.id} path=(empty)');
        missingCount++;
        continue;
      }
      
      try {
        // Intentar cargar el asset para verificar que existe
        await rootBundle.load(plan.coverImage);
        validCount++;
      } catch (e) {
        debugPrint('[PLANS-DBG] missingCover id=${plan.id} path=${plan.coverImage}');
        missingCount++;
      }
    }
    
    debugPrint('[PLANS-DBG] coverValidation: valid=$validCount, missing=$missingCount');
  }
  
  /// Debug: Imprime distribución de metadata
  void _printDebugSummary() {
    if (_plans == null || _plans!.isEmpty) {
      debugPrint('[PLANS-DBG] totalPlans=0 (ERROR: no plans loaded)');
      return;
    }
    
    final typeCount = <PlanType, int>{};
    final stageCount = <ContentStage, int>{};
    final giantCount = <GiantId, int>{};
    int missingCoverCount = 0;
    
    for (final plan in _plans!) {
      // Contar por planType
      typeCount[plan.metadata.planType] = 
          (typeCount[plan.metadata.planType] ?? 0) + 1;
      // Contar por stage
      stageCount[plan.metadata.stage] = 
          (stageCount[plan.metadata.stage] ?? 0) + 1;
      // Contar por giants
      for (final giant in plan.metadata.giants) {
        giantCount[giant] = (giantCount[giant] ?? 0) + 1;
      }
      // Contar covers faltantes
      if (plan.coverImage.isEmpty) {
        missingCoverCount++;
      }
    }
    
    // Log resumen con formato [PLANS-DBG]
    final typeStr = typeCount.entries
        .map((e) => '${e.key.name}=${e.value}')
        .join(', ');
    final stageStr = stageCount.entries
        .map((e) => '${e.key.name}=${e.value}')
        .join(', ');
    
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('[PLANS-DBG] totalPlans=${_plans!.length}');
    debugPrint('[PLANS-DBG] byType: $typeStr');
    debugPrint('[PLANS-DBG] byStage: $stageStr');
    debugPrint('[PLANS-DBG] missingCoverCount=$missingCoverCount');
    
    // Sample plan
    if (_plans!.isNotEmpty) {
      final sample = _plans!.first;
      debugPrint('[PLANS-DBG] samplePlan id=${sample.id} planType=${sample.metadata.planType.name} stage=${sample.metadata.stage.name} coverImage=${sample.coverImage}');
    }
    debugPrint('═══════════════════════════════════════════════════════');
  }
  
  /// Recargar planes (útil para desarrollo)
  Future<void> reload() async {
    _isInitialized = false;
    _plans = null;
    await init();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CONSULTAS BÁSICAS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtener plan por ID
  Plan? getPlan(String id) {
    return _plans?.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('Plan not found: $id'),
    );
  }
  
  /// Buscar plan por ID (null-safe)
  Plan? findPlan(String id) {
    try {
      return _plans?.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FILTROS POR DURACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Planes de crisis (3 días)
  List<Plan> get crisisPlans => 
      plans.where((p) => p.durationDays <= 3).toList();
  
  /// Planes de reinicio (7 días)
  List<Plan> get restartPlans => 
      plans.where((p) => p.durationDays > 3 && p.durationDays <= 7).toList();
  
  /// Planes de formación (14-21 días)
  List<Plan> get habitPlans => 
      plans.where((p) => p.durationDays > 7 && p.durationDays <= 21).toList();
  
  /// Planes de profundización (30+ días)
  List<Plan> get deepPlans => 
      plans.where((p) => p.durationDays > 21).toList();
  
  /// Planes por duración específica
  List<Plan> getPlansByDuration(int days) =>
      plans.where((p) => p.durationDays == days).toList();
  
  /// Planes por rango de duración
  List<Plan> getPlansByDurationRange(int minDays, int maxDays) =>
      plans.where((p) => p.durationDays >= minDays && p.durationDays <= maxDays).toList();
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FILTROS POR GIGANTE
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Planes para un gigante específico
  List<Plan> getPlansForGiant(GiantId giant) =>
      plans.where((p) => p.metadata.appliesToGiant(giant)).toList();
  
  /// Planes para cualquiera de los gigantes dados
  List<Plan> getPlansForAnyGiant(List<GiantId> giants) =>
      plans.where((p) => p.metadata.appliesToAnyGiant(giants)).toList();
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FILTROS POR TIPO Y ETAPA
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Planes por tipo
  List<Plan> getPlansByType(PlanType type) =>
      plans.where((p) => p.metadata.planType == type).toList();
  
  /// Planes por etapa
  List<Plan> getPlansByStage(ContentStage stage) =>
      plans.where((p) => p.metadata.stage == stage).toList();
  
  /// Planes por dificultad
  List<Plan> getPlansByDifficulty(PlanDifficulty difficulty) =>
      plans.where((p) => p.metadata.difficulty == difficulty).toList();
  
  /// Planes para nuevos en la fe
  List<Plan> get newBelieverPlans =>
      plans.where((p) => p.metadata.recommendedFor.newBeliever).toList();
  
  /// Planes de crisis (recomendados)
  List<Plan> get crisisRecommendedPlans =>
      plans.where((p) => p.metadata.recommendedFor.crisis).toList();
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FILTROS POR TIEMPO DIARIO
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Planes por tiempo máximo diario
  List<Plan> getPlansByMaxTime(int maxMinutes) =>
      plans.where((p) => p.minutesPerDay <= maxMinutes).toList();
  
  /// Planes por rango de tiempo diario
  List<Plan> getPlansByTimeRange(int minMinutes, int maxMinutes) =>
      plans.where((p) => 
          p.minutesPerDay >= minMinutes && 
          p.minutesPerDay <= maxMinutes
      ).toList();
  
  // ═══════════════════════════════════════════════════════════════════════════
  // BÚSQUEDA
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Buscar planes por texto
  List<Plan> search(String query) {
    if (query.isEmpty) return plans;
    
    final lowerQuery = query.toLowerCase();
    return plans.where((p) {
      // Buscar en título
      if (p.title.toLowerCase().contains(lowerQuery)) return true;
      // Buscar en subtítulo
      if (p.subtitle.toLowerCase().contains(lowerQuery)) return true;
      // Buscar en descripción
      if (p.description.toLowerCase().contains(lowerQuery)) return true;
      // Buscar en tags
      if (p.metadata.tags.any((t) => t.toLowerCase().contains(lowerQuery))) return true;
      // Buscar en nombres de gigantes
      if (p.metadata.giants.any((g) => g.displayName.toLowerCase().contains(lowerQuery))) return true;
      return false;
    }).toList();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FILTRO COMBINADO
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Filtrar planes con múltiples criterios
  List<Plan> filter({
    String? searchQuery,
    List<GiantId>? giants,
    List<int>? durations,
    List<PlanType>? types,
    List<ContentStage>? stages,
    List<PlanDifficulty>? difficulties,
    int? maxMinutesPerDay,
    bool? forNewBelievers,
    bool? forCrisis,
  }) {
    var result = plans.toList();
    
    // Búsqueda por texto
    if (searchQuery != null && searchQuery.isNotEmpty) {
      result = search(searchQuery);
    }
    
    // Filtrar por gigantes
    if (giants != null && giants.isNotEmpty) {
      result = result.where((p) => p.metadata.appliesToAnyGiant(giants)).toList();
    }
    
    // Filtrar por duración
    if (durations != null && durations.isNotEmpty) {
      result = result.where((p) => durations.contains(p.durationDays)).toList();
    }
    
    // Filtrar por tipo
    if (types != null && types.isNotEmpty) {
      result = result.where((p) => types.contains(p.metadata.planType)).toList();
    }
    
    // Filtrar por etapa
    if (stages != null && stages.isNotEmpty) {
      result = result.where((p) => stages.contains(p.metadata.stage)).toList();
    }
    
    // Filtrar por dificultad
    if (difficulties != null && difficulties.isNotEmpty) {
      result = result.where((p) => difficulties.contains(p.metadata.difficulty)).toList();
    }
    
    // Filtrar por tiempo máximo diario
    if (maxMinutesPerDay != null) {
      result = result.where((p) => p.minutesPerDay <= maxMinutesPerDay).toList();
    }
    
    // Filtrar para nuevos en la fe
    if (forNewBelievers == true) {
      result = result.where((p) => p.metadata.recommendedFor.newBeliever).toList();
    }
    
    // Filtrar para crisis
    if (forCrisis == true) {
      result = result.where((p) => p.metadata.recommendedFor.crisis).toList();
    }
    
    return result;
  }
}
