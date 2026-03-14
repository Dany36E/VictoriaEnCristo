/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN PROGRESS SERVICE - Gestión del progreso del usuario en planes
/// Persistencia defensiva con SharedPreferences
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plan.dart';

class PlanProgressService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final PlanProgressService _instance = PlanProgressService._internal();
  factory PlanProgressService() => _instance;
  PlanProgressService._internal();
  
  static PlanProgressService get I => _instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const String _keyActivePlan = 'plan_active_id';
  static const String _keyAllProgress = 'plan_all_progress';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE
  // ═══════════════════════════════════════════════════════════════════════════
  
  SharedPreferences? _prefs;
  String? _activePlanId;
  Map<String, PlanProgress> _progressCache = {};
  bool _isInitialized = false;
  
  bool get isInitialized => _isInitialized;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      _activePlanId = _prefs?.getString(_keyActivePlan);
      await _loadAllProgress();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = true;
      // Continuar sin persistencia
    }
  }
  
  Future<void> _loadAllProgress() async {
    try {
      final json = _prefs?.getString(_keyAllProgress);
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        _progressCache = data.map((key, value) => 
            MapEntry(key, PlanProgress.fromJson(value as Map<String, dynamic>)));
      }
    } catch (e) {
      _progressCache = {};
    }
  }
  
  Future<void> _saveAllProgress() async {
    try {
      final data = _progressCache.map((key, value) => 
          MapEntry(key, value.toJson()));
      await _prefs?.setString(_keyAllProgress, jsonEncode(data));
    } catch (e) {
      // Ignorar errores de guardado
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // PLAN ACTIVO
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// ID del plan activo actual
  String? get activePlanId => _activePlanId;
  
  /// Verificar si hay un plan activo
  bool get hasActivePlan => _activePlanId != null && _activePlanId!.isNotEmpty;
  
  /// Establecer plan activo
  Future<void> setActivePlan(String planId) async {
    _activePlanId = planId;
    await _prefs?.setString(_keyActivePlan, planId);
    
    // Crear progreso inicial si no existe
    if (!_progressCache.containsKey(planId)) {
      _progressCache[planId] = PlanProgress(
        planId: planId,
        lastOpenedAt: DateTime.now(),
      );
      await _saveAllProgress();
    }
  }
  
  /// Limpiar plan activo
  Future<void> clearActivePlan() async {
    _activePlanId = null;
    await _prefs?.remove(_keyActivePlan);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // PROGRESO
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtener progreso de un plan
  PlanProgress? getProgress(String planId) {
    return _progressCache[planId];
  }
  
  /// Obtener progreso del plan activo
  PlanProgress? get activeProgress {
    if (_activePlanId == null) return null;
    return _progressCache[_activePlanId];
  }
  
  /// Verificar si un día está completado
  bool isDayCompleted(String planId, int dayIndex) {
    final progress = _progressCache[planId];
    return progress?.isDayCompleted(dayIndex) ?? false;
  }
  
  /// Marcar día como completado
  Future<void> completeDay(String planId, int dayIndex) async {
    final now = DateTime.now();
    var progress = _progressCache[planId] ?? PlanProgress(planId: planId);
    
    // Agregar día a completados
    final newCompletedDays = Set<int>.from(progress.completedDays)..add(dayIndex);
    
    // Calcular racha
    int newStreak = progress.currentStreak;
    if (progress.lastCompletedAt != null) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final wasYesterday = 
          progress.lastCompletedAt!.year == yesterday.year &&
          progress.lastCompletedAt!.month == yesterday.month &&
          progress.lastCompletedAt!.day == yesterday.day;
      final wasToday = 
          progress.lastCompletedAt!.year == now.year &&
          progress.lastCompletedAt!.month == now.month &&
          progress.lastCompletedAt!.day == now.day;
      
      if (wasYesterday) {
        newStreak++;
      } else if (!wasToday) {
        newStreak = 1; // Reiniciar racha
      }
    } else {
      newStreak = 1;
    }
    
    // Actualizar progreso
    progress = progress.copyWith(
      completedDays: newCompletedDays,
      lastCompletedAt: now,
      currentStreak: newStreak,
      currentDay: dayIndex + 1,
    );
    
    _progressCache[planId] = progress;
    await _saveAllProgress();
  }
  
  /// Actualizar última apertura
  Future<void> markOpened(String planId) async {
    var progress = _progressCache[planId] ?? PlanProgress(planId: planId);
    progress = progress.copyWith(lastOpenedAt: DateTime.now());
    _progressCache[planId] = progress;
    await _saveAllProgress();
  }
  
  /// Reiniciar progreso de un plan
  Future<void> resetProgress(String planId) async {
    _progressCache[planId] = PlanProgress(
      planId: planId,
      lastOpenedAt: DateTime.now(),
    );
    await _saveAllProgress();
  }
  
  /// "Retomar hoy" - no resetea, solo marca como abierto
  Future<void> resumeToday(String planId) async {
    var progress = _progressCache[planId] ?? PlanProgress(planId: planId);
    progress = progress.copyWith(lastOpenedAt: DateTime.now());
    _progressCache[planId] = progress;
    await _saveAllProgress();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // RECORDATORIOS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Guardar configuración de recordatorio
  Future<void> setReminder(String planId, String time, {bool enabled = true}) async {
    var progress = _progressCache[planId] ?? PlanProgress(planId: planId);
    progress = progress.copyWith(
      hasReminder: enabled,
      reminderTime: time,
    );
    _progressCache[planId] = progress;
    await _saveAllProgress();
  }
  
  /// Desactivar recordatorio
  Future<void> disableReminder(String planId) async {
    var progress = _progressCache[planId];
    if (progress != null) {
      progress = progress.copyWith(hasReminder: false);
      _progressCache[planId] = progress;
      await _saveAllProgress();
    }
  }
  
  /// Obtener hora del recordatorio
  String? getReminderTime(String planId) {
    return _progressCache[planId]?.reminderTime;
  }
  
  /// Verificar si tiene recordatorio activo
  bool hasReminder(String planId) {
    return _progressCache[planId]?.hasReminder ?? false;
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADÍSTICAS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Planes iniciados
  int get plansStarted => _progressCache.length;
  
  /// Planes completados
  int plansCompleted(Map<String, int> planDurations) {
    int count = 0;
    for (final entry in _progressCache.entries) {
      final duration = planDurations[entry.key] ?? 0;
      if (entry.value.completedDays.length >= duration && duration > 0) {
        count++;
      }
    }
    return count;
  }
  
  /// Total de días completados en todos los planes
  int get totalDaysCompleted {
    int total = 0;
    for (final progress in _progressCache.values) {
      total += progress.completedDays.length;
    }
    return total;
  }
  
  /// Racha máxima entre todos los planes
  int get maxStreak {
    int max = 0;
    for (final progress in _progressCache.values) {
      if (progress.currentStreak > max) {
        max = progress.currentStreak;
      }
    }
    return max;
  }
  
  /// Todos los progresos
  List<PlanProgress> get allProgress => _progressCache.values.toList();
  
  /// Planes en progreso (iniciados pero no completados)
  List<PlanProgress> inProgressPlans(Map<String, int> planDurations) {
    return _progressCache.values.where((p) {
      final duration = planDurations[p.planId] ?? 0;
      return p.completedDays.isNotEmpty && 
             p.completedDays.length < duration;
    }).toList();
  }
}
