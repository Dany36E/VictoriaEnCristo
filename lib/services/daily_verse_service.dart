/// ═══════════════════════════════════════════════════════════════════════════
/// DAILY VERSE SERVICE - Servicio de Versículo del Día
/// Rotación automática diaria con persistencia offline
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bible_verses.dart';
import '../utils/time_utils.dart';

class DailyVerseService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final DailyVerseService _instance = DailyVerseService._internal();
  factory DailyVerseService() => _instance;
  DailyVerseService._internal();
  
  static DailyVerseService get I => _instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const String _keyDailyVerseDate = 'daily_verse_date';
  static const String _keyDailyVerseIndex = 'daily_verse_index';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE
  // ═══════════════════════════════════════════════════════════════════════════
  
  SharedPreferences? _prefs;
  BibleVerse? _cachedVerse;
  String? _cachedDate;
  bool _isInitialized = false;
  
  bool get isInitialized => _isInitialized;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FALLBACK VERSE (si algo falla)
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const BibleVerse _fallbackVerse = BibleVerse(
    verse: "Todo lo puedo en Cristo que me fortalece.",
    reference: "Filipenses 4:13",
    category: "fortaleza",
  );
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      _cachedDate = _prefs?.getString(_keyDailyVerseDate);
      final cachedIndex = _prefs?.getInt(_keyDailyVerseIndex);
      
      // Si tenemos un índice cacheado válido, restaurar el versículo
      if (cachedIndex != null && cachedIndex >= 0) {
        final verses = BibleVerses.allVerses;
        if (cachedIndex < verses.length) {
          _cachedVerse = verses[cachedIndex];
        }
      }
      
      _isInitialized = true;
    } catch (e) {
      _isInitialized = true;
      // Continuar sin persistencia
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // OBTENER VERSÍCULO DEL DÍA
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtiene el versículo del día de forma determinística.
  /// El versículo cambia automáticamente cada día (medianoche local).
  /// 
  /// Algoritmo: index = dayOfYear % totalVerses
  /// Esto garantiza que el versículo sea el mismo todo el día,
  /// y que rote automáticamente al día siguiente.
  Future<BibleVerse> getForToday() async {
    if (!_isInitialized) {
      await init();
    }
    
    try {
      final today = _getTodayDateString();
      
      // Si ya tenemos el versículo de hoy en cache, devolverlo
      if (_cachedDate == today && _cachedVerse != null) {
        return _cachedVerse!;
      }
      
      // Calcular nuevo versículo para hoy
      final verses = BibleVerses.allVerses;
      if (verses.isEmpty) {
        return _fallbackVerse;
      }
      
      // Usar día del año para selección determinística
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final dayOfYear = now.difference(startOfYear).inDays + 1;
      
      // Agregar año para variar entre años
      final seed = dayOfYear + (now.year * 365);
      final index = seed % verses.length;
      
      final verse = verses[index];
      
      // Guardar en cache
      _cachedVerse = verse;
      _cachedDate = today;
      
      // Persistir
      await _saveToPrefs(today, index);
      
      return verse;
    } catch (e) {
      // Fallback defensivo
      return _cachedVerse ?? _fallbackVerse;
    }
  }
  
  /// Versión síncrona para uso inmediato (usa cache)
  BibleVerse getForTodaySync() {
    try {
      final today = _getTodayDateString();
      
      // Si tenemos cache válido de hoy
      if (_cachedDate == today && _cachedVerse != null) {
        return _cachedVerse!;
      }
      
      // Calcular sin persistir (se persistirá en la próxima llamada async)
      final verses = BibleVerses.allVerses;
      if (verses.isEmpty) {
        return _fallbackVerse;
      }
      
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final dayOfYear = now.difference(startOfYear).inDays + 1;
      final seed = dayOfYear + (now.year * 365);
      final index = seed % verses.length;
      
      final verse = verses[index];
      _cachedVerse = verse;
      _cachedDate = today;
      
      return verse;
    } catch (e) {
      return _cachedVerse ?? _fallbackVerse;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Llamado por el lifecycle observer al detectar cambio de día.
  /// Invalida cache y recalcula el versículo.
  void refreshToday() {
    _cachedDate = null;
    _cachedVerse = null;
    // Recalcular síncrono para que la próxima lectura tenga el versículo nuevo
    getForTodaySync();
    debugPrint('📖 [DAILY_VERSE] refreshToday() → ${_cachedVerse?.reference}');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS PRIVADOS
  // ═══════════════════════════════════════════════════════════════════════════
  
  String _getTodayDateString() => TimeUtils.todayISO();
  
  Future<void> _saveToPrefs(String date, int index) async {
    try {
      await _prefs?.setString(_keyDailyVerseDate, date);
      await _prefs?.setInt(_keyDailyVerseIndex, index);
    } catch (e) {
      // Ignorar errores de guardado
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // DEBUG
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Solo para testing: simula un cambio de día
  Future<void> debugForceNewDay() async {
    _cachedDate = null;
    _cachedVerse = null;
    await _prefs?.remove(_keyDailyVerseDate);
    await _prefs?.remove(_keyDailyVerseIndex);
  }
}
