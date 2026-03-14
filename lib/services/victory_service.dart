/// ═══════════════════════════════════════════════════════════════════════════
/// VICTORY SERVICE - Servicio de Días de Victoria
/// Gestiona el registro de días de victoria y cálculo de rachas
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VictoryService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final VictoryService _instance = VictoryService._internal();
  factory VictoryService() => _instance;
  VictoryService._internal();
  
  static VictoryService get I => _instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const String _keyVictoryDays = 'victory_days_set';
  static const String _keyCurrentStreak = 'currentStreak';
  static const String _keyLongestStreak = 'longestStreak';
  static const String _keyTotalVictories = 'totalVictories';
  static const String _keyStreakStartDate = 'streakStartDate';
  static const String _keyWeeklyProgress = 'weeklyProgress';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE
  // ═══════════════════════════════════════════════════════════════════════════
  
  SharedPreferences? _prefs;
  Set<String> _victoryDays = {}; // Formato: yyyy-MM-dd
  bool _isInitialized = false;
  
  bool get isInitialized => _isInitialized;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICADORES (para UI reactiva)
  // ═══════════════════════════════════════════════════════════════════════════
  
  final ValueNotifier<int> currentStreakNotifier = ValueNotifier(0);
  final ValueNotifier<bool> loggedTodayNotifier = ValueNotifier(false);
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadVictoryDays();
      _updateNotifiers();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = true;
      // Continuar sin persistencia
    }
  }
  
  Future<void> _loadVictoryDays() async {
    try {
      final json = _prefs?.getString(_keyVictoryDays);
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        _victoryDays = list.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      _victoryDays = {};
    }
  }
  
  Future<void> _saveVictoryDays() async {
    try {
      await _prefs?.setString(_keyVictoryDays, jsonEncode(_victoryDays.toList()));
    } catch (e) {
      // Ignorar errores de guardado
    }
  }
  
  void _updateNotifiers() {
    currentStreakNotifier.value = getCurrentStreak();
    loggedTodayNotifier.value = isVictoryLoggedToday();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // API PÚBLICA
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Verifica si ya se registró victoria hoy
  bool isVictoryLoggedToday() {
    return isVictoryLoggedFor(DateTime.now());
  }
  
  /// Verifica si hay victoria registrada para una fecha específica
  bool isVictoryLoggedFor(DateTime date) {
    final dateStr = _dateToString(date);
    return _victoryDays.contains(dateStr);
  }
  
  /// Obtiene la racha actual de días consecutivos
  int getCurrentStreak() {
    if (_victoryDays.isEmpty) return 0;
    
    // Ordenar fechas de más reciente a más antigua
    final today = DateTime.now();
    final todayStr = _dateToString(today);
    final yesterdayStr = _dateToString(today.subtract(const Duration(days: 1)));
    
    // La racha debe empezar hoy o ayer para contar
    if (!_victoryDays.contains(todayStr) && !_victoryDays.contains(yesterdayStr)) {
      return 0;
    }
    
    // Contar días consecutivos hacia atrás
    int streak = 0;
    DateTime checkDate = _victoryDays.contains(todayStr) ? today : today.subtract(const Duration(days: 1));
    
    while (true) {
      final checkStr = _dateToString(checkDate);
      if (_victoryDays.contains(checkStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }
  
  /// Obtiene el total de días de victoria
  int getTotalVictories() {
    // Combinar con valor legacy si existe
    final legacyTotal = _prefs?.getInt(_keyTotalVictories) ?? 0;
    return _victoryDays.length > legacyTotal ? _victoryDays.length : legacyTotal;
  }
  
  /// Obtiene el total de días de victoria SOLO del año especificado
  int getTotalVictoriesForYear(int year) {
    return _victoryDays
        .where((dateStr) => dateStr.startsWith('$year-'))
        .length;
  }
  
  /// Obtiene la racha más larga registrada (RECALCULADA del historial completo)
  int getLongestStreak() {
    return getBestStreakAllTime();
  }
  
  /// Calcula la racha más larga de TODO el historial
  /// Considera cruces de año automáticamente
  int getBestStreakAllTime() {
    if (_victoryDays.isEmpty) return 0;
    
    // Convertir a List<DateTime> y ordenar
    final dates = _victoryDays
        .map((s) {
          final parts = s.split('-');
          if (parts.length != 3) return null;
          try {
            return DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          } catch (e) {
            return null;
          }
        })
        .whereType<DateTime>()
        .toList()
      ..sort((a, b) => a.compareTo(b));
    
    if (dates.isEmpty) return 0;
    if (dates.length == 1) return 1;
    
    int bestStreak = 1;
    int currentStreak = 1;
    
    for (int i = 1; i < dates.length; i++) {
      final prevDate = dates[i - 1];
      final currDate = dates[i];
      
      // Calcular diferencia en días
      final diffDays = currDate.difference(prevDate).inDays;
      
      if (diffDays == 1) {
        // Día consecutivo
        currentStreak++;
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
      } else if (diffDays > 1) {
        // Gap en la racha, reiniciar
        currentStreak = 1;
      }
      // Si diffDays == 0 (duplicado), ignorar
    }
    
    return bestStreak;
  }
  
  /// Registra victoria para hoy
  /// Retorna true si se registró exitosamente, false si ya estaba registrado
  Future<bool> logVictoryForToday() async {
    return logVictoryFor(DateTime.now());
  }
  
  /// Registra victoria para una fecha específica
  Future<bool> logVictoryFor(DateTime date) async {
    if (!_isInitialized) {
      await init();
    }
    
    final dateStr = _dateToString(date);
    
    // Evitar doble registro
    if (_victoryDays.contains(dateStr)) {
      return false;
    }
    
    // Agregar día
    _victoryDays.add(dateStr);
    await _saveVictoryDays();
    
    // Actualizar stats legacy para compatibilidad con ProgressScreen
    await _updateLegacyStats();
    
    // Actualizar notificadores
    _updateNotifiers();
    
    return true;
  }
  
  /// Elimina victoria de una fecha (opcional para edición)
  Future<bool> undoVictoryFor(DateTime date) async {
    if (!_isInitialized) {
      await init();
    }
    
    final dateStr = _dateToString(date);
    
    if (!_victoryDays.contains(dateStr)) {
      return false;
    }
    
    _victoryDays.remove(dateStr);
    await _saveVictoryDays();
    await _updateLegacyStats();
    _updateNotifiers();
    
    return true;
  }
  
  /// Reinicia todo el progreso
  Future<void> resetAll() async {
    _victoryDays.clear();
    await _saveVictoryDays();
    
    await _prefs?.setInt(_keyCurrentStreak, 0);
    await _prefs?.setInt(_keyTotalVictories, 0);
    await _prefs?.remove(_keyStreakStartDate);
    await _prefs?.setStringList(_keyWeeklyProgress, ['0', '0', '0', '0', '0', '0', '0']);
    
    _updateNotifiers();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // COMPATIBILIDAD CON PROGRESS SCREEN
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Actualiza las estadísticas legacy para mantener compatibilidad
  Future<void> _updateLegacyStats() async {
    try {
      final currentStreak = getCurrentStreak();
      final longestStreak = getLongestStreak();
      final totalVictories = getTotalVictories();
      
      await _prefs?.setInt(_keyCurrentStreak, currentStreak);
      await _prefs?.setInt(_keyTotalVictories, totalVictories);
      
      if (currentStreak > longestStreak) {
        await _prefs?.setInt(_keyLongestStreak, currentStreak);
      }
      
      // Actualizar fecha de inicio de racha si es día 1
      if (currentStreak == 1) {
        await _prefs?.setString(_keyStreakStartDate, DateTime.now().toIso8601String());
      }
      
      // Actualizar progreso semanal
      await _updateWeeklyProgress(currentStreak);
    } catch (e) {
      // Ignorar errores
    }
  }
  
  Future<void> _updateWeeklyProgress(int currentStreak) async {
    try {
      final weeklyData = _prefs?.getStringList(_keyWeeklyProgress) ?? 
          ['0', '0', '0', '0', '0', '0', '0'];
      
      // Rotar y agregar nuevo valor
      final newWeekly = [...weeklyData.sublist(1), currentStreak.toString()];
      await _prefs?.setStringList(_keyWeeklyProgress, newWeekly);
    } catch (e) {
      // Ignorar
    }
  }
  
  /// Sincroniza con datos legacy existentes de ProgressScreen
  Future<void> syncWithLegacyData() async {
    if (!_isInitialized) {
      await init();
    }
    
    try {
      // Si hay datos legacy pero no hay victory_days, migrar
      final legacyTotal = _prefs?.getInt(_keyTotalVictories) ?? 0;
      final legacyStreak = _prefs?.getInt(_keyCurrentStreak) ?? 0;
      
      if (legacyTotal > 0 && _victoryDays.isEmpty) {
        // Recrear días basándose en la racha actual
        // (aproximación: asumimos que la racha empezó hoy hacia atrás)
        final today = DateTime.now();
        for (int i = 0; i < legacyStreak; i++) {
          final date = today.subtract(Duration(days: i));
          _victoryDays.add(_dateToString(date));
        }
        await _saveVictoryDays();
      }
      
      _updateNotifiers();
    } catch (e) {
      // Ignorar errores de migración
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS PARA CALENDARIO
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtiene todos los días de victoria en un mes específico
  /// Retorna Set<String> en formato yyyy-MM-dd
  Future<Set<String>> getVictoryDaysInMonth(DateTime month) async {
    if (!_isInitialized) {
      await init();
    }
    
    try {
      final yearMonth = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      return _victoryDays.where((d) => d.startsWith(yearMonth)).toSet();
    } catch (e) {
      return {};
    }
  }
  
  /// Obtiene todos los días de victoria registrados
  Set<String> getAllVictoryDays() {
    return Set.from(_victoryDays);
  }
  
  /// Establece el estado de victoria para una fecha específica
  /// Permite editar días pasados de forma interactiva
  /// Retorna el nuevo estado isVictory
  Future<bool> setVictoryForDate(DateTime date, bool isVictory) async {
    if (!_isInitialized) {
      await init();
    }
    
    // No permitir editar días futuros
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final dateStart = DateTime(date.year, date.month, date.day);
    if (dateStart.isAfter(todayStart)) {
      return isVictoryLoggedFor(date);
    }
    
    final dateStr = _dateToString(date);
    
    if (isVictory) {
      // Agregar victoria si no existe
      if (!_victoryDays.contains(dateStr)) {
        _victoryDays.add(dateStr);
        await _saveVictoryDays();
        await _updateLegacyStats();
        _updateNotifiers();
      }
    } else {
      // Quitar victoria si existe
      if (_victoryDays.contains(dateStr)) {
        _victoryDays.remove(dateStr);
        await _saveVictoryDays();
        await _updateLegacyStats();
        _updateNotifiers();
      }
    }
    
    return isVictory;
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
