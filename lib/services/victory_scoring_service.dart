/// ═══════════════════════════════════════════════════════════════════════════
/// VICTORY SCORING SERVICE - Sistema de Victoria Compuesta
/// Gestiona estados por gigante, cálculo de scores y umbral de victoria
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_service.dart';
import 'victory_service.dart';
import '../utils/time_utils.dart';

class VictoryScoringService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final VictoryScoringService _instance = VictoryScoringService._internal();
  factory VictoryScoringService() => _instance;
  VictoryScoringService._internal();
  
  static VictoryScoringService get I => _instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const String _keyVictoryByGiant = 'victory_by_giant_v1';
  static const String _keyMigrated = 'migrated_victory_to_by_giant';
  static const String _keyThreshold = 'victory_threshold';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Umbral de victoria: 60% (3/5 gigantes = 0.6)
  static const double defaultThreshold = 0.60;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════
  
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  
  /// Cache: dateISO -> {giantId: 0/1}
  Map<String, Map<String, int>> _victoryByGiant = {};
  
  /// Gigantes seleccionados del usuario
  List<String> _selectedGiants = [];
  
  /// Umbral configurable
  double _threshold = defaultThreshold;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICADORES
  // ═══════════════════════════════════════════════════════════════════════════
  
  final ValueNotifier<int> currentStreakNotifier = ValueNotifier(0);
  final ValueNotifier<bool> loggedTodayNotifier = ValueNotifier(false);
  final ValueNotifier<int> totalYearNotifier = ValueNotifier(0);
  final ValueNotifier<int> bestStreakNotifier = ValueNotifier(0);
  
  /// Callback para write-through a cloud (lo configura ProgressSyncAdapter)
  /// Evita import circular: VictoryScoringService no importa el adapter.
  void Function(DateTime date)? onDayChanged;
  
  bool get isInitialized => _isInitialized;
  double get threshold => _threshold;
  List<String> get selectedGiants => List.from(_selectedGiants);
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> init() async {
    if (_isInitialized) {
      // Si ya estaba inicializado, solo refrescar datos
      await _loadVictoryByGiant();
      _updateAllNotifiers();
      return;
    }
    
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Cargar gigantes seleccionados
      final onboarding = OnboardingService();
      await onboarding.init();
      _selectedGiants = onboarding.selectedGiants;
      
      // Si no hay gigantes, usar uno por defecto para evitar división por 0
      if (_selectedGiants.isEmpty) {
        _selectedGiants = ['general'];
      }
      
      // Cargar umbral
      _threshold = _prefs?.getDouble(_keyThreshold) ?? defaultThreshold;
      
      // Cargar datos (SIEMPRE recargar de disco)
      await _loadVictoryByGiant();
      
      // Migración desde sistema antiguo
      await _migrateFromLegacy();
      
      _isInitialized = true;
      _updateAllNotifiers();
      
      debugPrint('📊 [SCORING] Initialized: ${_selectedGiants.length} gigantes, ${_victoryByGiant.length} días, umbral=$_threshold');
    } catch (e) {
      debugPrint('📊 [SCORING] Init error: $e');
      _isInitialized = true;
    }
  }
  
  Future<void> _loadVictoryByGiant() async {
    try {
      final json = _prefs?.getString(_keyVictoryByGiant);
      if (json != null && json.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(json);
        _victoryByGiant = decoded.map((dateISO, giantMap) {
          if (giantMap is Map) {
            return MapEntry(
              dateISO, 
              Map<String, int>.from(
                giantMap.map((k, v) => MapEntry(k.toString(), (v is int) ? v : 0))
              )
            );
          }
          return MapEntry(dateISO, <String, int>{});
        });
        debugPrint('📊 [SCORING] Loaded ${_victoryByGiant.length} days from storage');
      } else {
        _victoryByGiant = {};
        debugPrint('📊 [SCORING] No stored data, starting fresh');
      }
    } catch (e) {
      debugPrint('📊 [SCORING] Load error: $e');
      _victoryByGiant = {};
    }
  }
  
  Future<bool> _saveVictoryByGiant() async {
    try {
      final json = jsonEncode(_victoryByGiant);
      final success = await _prefs?.setString(_keyVictoryByGiant, json) ?? false;
      if (success) {
        debugPrint('📊 [SCORING] Saved ${_victoryByGiant.length} days to storage');
      }
      return success;
    } catch (e) {
      debugPrint('📊 [SCORING] Save error: $e');
      return false;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MIGRACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _migrateFromLegacy() async {
    final migrated = _prefs?.getBool(_keyMigrated) ?? false;
    if (migrated) return;
    
    try {
      // Obtener días de victoria del sistema antiguo
      final oldService = VictoryService.I;
      await oldService.init();
      final oldDays = oldService.getAllVictoryDays();
      
      if (oldDays.isNotEmpty && _victoryByGiant.isEmpty) {
        debugPrint('📊 [SCORING] Migrando ${oldDays.length} días del sistema antiguo');
        
        for (final dateISO in oldDays) {
          // Marcar victoria en TODOS los gigantes (conservador hacia el usuario)
          _victoryByGiant[dateISO] = {
            for (final giant in _selectedGiants) giant: 1
          };
        }
        
        await _saveVictoryByGiant();
      }
      
      await _prefs?.setBool(_keyMigrated, true);
      debugPrint('📊 [SCORING] Migración completada');
    } catch (e) {
      debugPrint('📊 [SCORING] Migration error: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // API PÚBLICA - LECTURA
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtiene estados de todos los gigantes para un día
  /// Retorna {giantId: 0/1} para TODOS los gigantes seleccionados
  Map<String, int> getDayGiantStates(DateTime date) {
    final dateISO = _dateToISO(date);
    final stored = _victoryByGiant[dateISO] ?? {};
    
    // Asegurar que todos los gigantes seleccionados tienen un valor
    return {
      for (final giant in _selectedGiants)
        giant: stored[giant] ?? 0 // Default: gracia (0)
    };
  }
  
  /// Cuenta victorias del día
  int getDayVictoriesCount(DateTime date) {
    final states = getDayGiantStates(date);
    return states.values.where((v) => v == 1).length;
  }
  
  /// Total de gigantes seleccionados
  int getTotalGiantsCount() => _selectedGiants.length;
  
  /// Score del día [0.0 - 1.0]
  double getDayScore(DateTime date) {
    final total = getTotalGiantsCount();
    if (total == 0) return 0.0;
    return getDayVictoriesCount(date) / total;
  }
  
  /// ¿Es día de victoria? (score >= threshold)
  bool isVictoryDay(DateTime date) {
    final dateISO = _dateToISO(date);
    final hasEntry = _victoryByGiant.containsKey(dateISO);
    
    // Si no hay entrada para este día, NO es victoria
    if (!hasEntry) {
      return false;
    }
    
    final victories = getDayVictoriesCount(date);
    final required = getRequiredVictories();
    final result = victories >= required;
    
    return result;
  }
  
  /// Victorias mínimas requeridas para ⭐
  int getRequiredVictories() {
    final total = getTotalGiantsCount();
    if (total == 0) return 1;
    return ((_threshold * total).ceil()).clamp(1, total);
  }
  
  /// ¿Hay algún registro para hoy?
  bool isLoggedToday() {
    final dateISO = _dateToISO(DateTime.now());
    return _victoryByGiant.containsKey(dateISO);
  }
  
  /// ¿Hoy es día de victoria?
  bool isTodayVictory() => isVictoryDay(DateTime.now());
  
  // ═══════════════════════════════════════════════════════════════════════════
  // API PÚBLICA - ESCRITURA
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Establece estado de un gigante para un día
  Future<void> setDayGiantState(DateTime date, String giantId, int value) async {
    if (!_isInitialized) await init();
    
    // No permitir editar días futuros
    if (_isFuture(date)) return;
    
    final dateISO = _dateToISO(date);
    
    // Obtener o crear mapa del día
    _victoryByGiant[dateISO] ??= {};
    _victoryByGiant[dateISO]![giantId] = value.clamp(0, 1);
    
    await _saveVictoryByGiant();
    _updateAllNotifiers();
    
    debugPrint('📊 [SCORING] $dateISO.$giantId = $value');
    
    // Write-through: notificar al sync adapter para subir a cloud
    onDayChanged?.call(date);
  }
  
  /// Marca todos los gigantes con el mismo valor para un día
  Future<void> setDayAllGiants(DateTime date, int value) async {
    if (!_isInitialized) await init();
    
    // No permitir editar días futuros
    if (_isFuture(date)) return;
    
    final dateISO = _dateToISO(date);
    
    _victoryByGiant[dateISO] = {
      for (final giant in _selectedGiants) giant: value.clamp(0, 1)
    };
    
    await _saveVictoryByGiant();
    _updateAllNotifiers();
    
    debugPrint('📊 [SCORING] $dateISO.ALL = $value');
    
    // Write-through: notificar al sync adapter para subir a cloud
    onDayChanged?.call(date);
  }
  
  /// Registra victoria completa para hoy (todos gigantes = 1)
  /// Retorna true siempre (ya no bloquea si ya existe)
  Future<bool> logVictoryForToday() async {
    await setDayAllGiants(DateTime.now(), 1);
    return true;
  }
  
  /// Verifica si hay datos guardados para hoy (puede ser victoria o gracia)
  bool hasDataForToday() {
    final dateISO = _dateToISO(DateTime.now());
    return _victoryByGiant.containsKey(dateISO);
  }

  /// Verifica si hay datos guardados para una fecha arbitraria
  bool isDateLogged(DateTime date) {
    final dateISO = _dateToISO(date);
    return _victoryByGiant.containsKey(dateISO);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADÍSTICAS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Días de victoria en un mes (score >= threshold)
  Set<String> getVictoryDaysInMonth(DateTime month) {
    final yearMonth = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    
    return _victoryByGiant.keys
        .where((dateISO) => dateISO.startsWith(yearMonth))
        .where((dateISO) {
          final date = _isoToDate(dateISO);
          return date != null && isVictoryDay(date);
        })
        .toSet();
  }
  
  /// Total de días de victoria en un año
  int getTotalVictoriesForYear(int year) {
    return _victoryByGiant.keys
        .where((dateISO) => dateISO.startsWith('$year-'))
        .where((dateISO) {
          final date = _isoToDate(dateISO);
          return date != null && isVictoryDay(date);
        })
        .length;
  }
  
  /// Racha actual (consecutivos hasta hoy con score >= threshold)
  /// Si hoy no es victoria, busca desde ayer
  int getCurrentStreak() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    // Debug: verificar estado de hoy
    final todayISO = _dateToISO(todayStart);
    final todayHasData = _victoryByGiant.containsKey(todayISO);
    final todayIsVictory = isVictoryDay(todayStart);
    
    debugPrint('📊 [STREAK] Calculando racha...');
    debugPrint('📊 [STREAK] Hoy: $todayISO, hasData=$todayHasData, isVictory=$todayIsVictory');
    debugPrint('📊 [STREAK] Días en mapa: ${_victoryByGiant.keys.toList()}');
    
    // Empezar desde hoy
    DateTime checkDate = todayStart;
    
    // Si hoy NO es victoria, empezar desde ayer
    if (!isVictoryDay(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
      // Si ayer tampoco es victoria, racha = 0
      if (!isVictoryDay(checkDate)) {
        debugPrint('📊 [STREAK] Ni hoy ni ayer son victoria -> 0');
        return 0;
      }
    }
    
    int streak = 0;
    while (isVictoryDay(checkDate)) {
      streak++;
      debugPrint('📊 [STREAK] ${_dateToISO(checkDate)} es victoria, streak=$streak');
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    debugPrint('📊 [STREAK] Racha final: $streak');
    return streak;
  }
  
  /// Mejor racha histórica (cruza años)
  int getBestStreakAllTime() {
    // Obtener todos los días de victoria
    final victoryDates = _victoryByGiant.keys
        .map((iso) => _isoToDate(iso))
        .whereType<DateTime>()
        .where((d) => isVictoryDay(d))
        .toList()
      ..sort((a, b) => a.compareTo(b));
    
    if (victoryDates.isEmpty) return 0;
    if (victoryDates.length == 1) return 1;
    
    int bestStreak = 1;
    int currentStreak = 1;
    
    for (int i = 1; i < victoryDates.length; i++) {
      final diff = victoryDates[i].difference(victoryDates[i - 1]).inDays;
      
      if (diff == 1) {
        currentStreak++;
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
      } else if (diff > 1) {
        currentStreak = 1;
      }
    }
    
    return bestStreak;
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICADORES
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _updateAllNotifiers() {
    currentStreakNotifier.value = getCurrentStreak();
    loggedTodayNotifier.value = isLoggedToday();
    totalYearNotifier.value = getTotalVictoriesForYear(DateTime.now().year);
    bestStreakNotifier.value = getBestStreakAllTime();
  }
  
  /// Forzar refresh de notificadores (útil para UI)
  void refreshNotifiers() => _updateAllNotifiers();

  /// Llamado por el lifecycle observer cuando se detecta cambio de día.
  /// Re-evalúa streak y loggedToday con la fecha nueva.
  void refreshAfterDayChange() {
    debugPrint('📊 [SCORING] refreshAfterDayChange()');
    _updateAllNotifiers();
  }
  
  /// Restaurar datos desde cloud (llamado después de que ProgressRepository
  /// descarga datos de Firestore). Esto hidrata el servicio local con los
  /// datos de la nube sin hacer ningún upload.
  Future<void> restoreFromCloud(Map<String, Map<String, int>> cloudData) async {
    if (!_isInitialized) await init();
    
    if (cloudData.isEmpty) {
      debugPrint('📊 [SCORING] restoreFromCloud: no cloud data to restore');
      return;
    }
    
    debugPrint('📊 [SCORING] restoreFromCloud: hydrating ${cloudData.length} days from cloud');
    
    // Reemplazar datos locales con los de cloud (cloud es fuente de verdad)
    _victoryByGiant = Map.from(cloudData.map(
      (dateISO, giants) => MapEntry(dateISO, Map<String, int>.from(giants)),
    ));
    
    await _saveVictoryByGiant();
    _updateAllNotifiers();
    
    debugPrint('📊 [SCORING] restoreFromCloud: ✅ hydrated, streak=${getCurrentStreak()}');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WEEKLY STATUS (para mini-calendario semanal)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Retorna el estado de cada día de la semana actual (lunes→domingo)
  /// Cada elemento: {'date': DateTime, 'completed': bool, 'isToday': bool}
  List<Map<String, dynamic>> getWeeklyStatus() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Calcular lunes de esta semana
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final isToday = day.year == today.year &&
          day.month == today.month &&
          day.day == today.day;
      final isFutureDay = day.isAfter(today);
      result.add({
        'date': day,
        'completed': isFutureDay ? false : isVictoryDay(day),
        'isToday': isToday,
      });
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  // Delegados a TimeUtils centralizado
  String _dateToISO(DateTime date) => TimeUtils.dateToISO(date);
  DateTime? _isoToDate(String iso) => TimeUtils.parseISO(iso);
  bool _isFuture(DateTime date) => TimeUtils.isFuture(date);
  
  // ═══════════════════════════════════════════════════════════════════════════
  // DEBUG
  // ═══════════════════════════════════════════════════════════════════════════
  
  String debugDayStatus(DateTime date) {
    final states = getDayGiantStates(date);
    final victories = getDayVictoriesCount(date);
    final total = getTotalGiantsCount();
    final isVictory = isVictoryDay(date);
    return '$victories/$total ${isVictory ? '⭐' : '✝︎'} $states';
  }
}
