/// ═══════════════════════════════════════════════════════════════════════════
/// PROGRESS REPOSITORY - Repositorio de victorias con Cloud Sync
/// Fuente de verdad: Firestore /users/{uid}/victoryDays/{dateISO}
/// Cache local: SharedPreferences
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/victory_day.dart';
import '../utils/time_utils.dart';

class ProgressRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final ProgressRepository _instance = ProgressRepository._internal();
  factory ProgressRepository() => _instance;
  ProgressRepository._internal();
  
  static ProgressRepository get I => _instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const String _keyVictoryDaysCache = 'victory_days_cache_v1';
  static const String _keyPendingWrites = 'victory_days_pending_writes';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  
  /// Cache: dateISO -> VictoryDay
  Map<String, VictoryDay> _cache = {};
  
  /// Acceso de solo lectura al cache (para hidratar VictoryScoringService)
  Map<String, VictoryDay> get cachedDays => Map.unmodifiable(_cache);
  
  /// Cola de escrituras pendientes (offline)
  List<String> _pendingWrites = [];
  
  /// Suscripción a cambios en tiempo real
  StreamSubscription<QuerySnapshot>? _realtimeSubscription;

  /// Guard contra connectUser concurrente (race condition)
  String? _connectingUid;
  Future<void>? _connectFuture;
  
  /// Notificadores
  final ValueNotifier<int> currentStreakNotifier = ValueNotifier(0);
  final ValueNotifier<bool> loggedTodayNotifier = ValueNotifier(false);
  final ValueNotifier<int> totalYearNotifier = ValueNotifier(0);
  final ValueNotifier<int> bestStreakNotifier = ValueNotifier(0);
  
  bool get isInitialized => _isInitialized;
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Cargar cache local primero (UX instantánea)
      await _loadLocalCache();
      
      // Cargar escrituras pendientes
      await _loadPendingWrites();
      
      _isInitialized = true;
      _updateAllNotifiers();
      
      debugPrint('📊 [PROGRESS_REPO] Initialized with ${_cache.length} cached days');
    } catch (e) {
      debugPrint('📊 [PROGRESS_REPO] Init error: $e');
      _isInitialized = true;
    }
  }
  
  /// Conectar con usuario y sincronizar datos
  /// CLOUD-FIRST: Siempre descargar desde Firestore, nunca subir cache stale
  Future<void> connectUser(String uid, {
    required List<String> selectedGiants,
    required double threshold,
  }) async {
    // Guard: si ya hay un connectUser en progreso para este UID, esperar
    if (_connectingUid == uid && _connectFuture != null) {
      debugPrint('📊 [PROGRESS_REPO] connectUser already in progress for $uid, awaiting...');
      await _connectFuture;
      return;
    }
    
    _connectingUid = uid;
    _connectFuture = _doConnectUser(uid, selectedGiants, threshold);
    await _connectFuture;
  }
  
  Future<void> _doConnectUser(String uid, List<String> selectedGiants, double threshold) async {
    if (!_isInitialized) await init();
    
    try {
      debugPrint('📊 [PROGRESS_REPO] Connecting user: $uid');
      
      // Cancelar suscripción anterior
      await _realtimeSubscription?.cancel();
      
      // CRÍTICO: Limpiar cache local antes de descargar de cloud.
      _cache.clear();
      _pendingWrites.clear();
      
      // Sincronizar con nube (PULL-ONLY)
      await _syncWithCloud(uid, selectedGiants, threshold);
      
      // Iniciar sync en tiempo real
      _startRealtimeSync(uid);
      
      _updateAllNotifiers();
    } catch (e) {
      debugPrint('📊 [PROGRESS_REPO] Connect error: $e');
    } finally {
      _connectingUid = null;
      _connectFuture = null;
    }
  }
  
  /// Desconectar usuario (NO borra datos)
  Future<void> disconnectUser() async {
    debugPrint('📊 [PROGRESS_REPO] Disconnecting (keeping data)');
    
    _connectingUid = null;
    _connectFuture = null;
    
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    
    // NO borrar cache - mantener datos para offline/re-login
  }
  
  /// Limpiar cache local (usado al cambiar de cuenta)
  Future<void> clearLocalCache() async {
    debugPrint('📊 [PROGRESS_REPO] Clearing local cache');
    
    _connectingUid = null;
    _connectFuture = null;
    
    // Cancelar listener
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    
    // Limpiar cache en memoria
    _cache.clear();
    _pendingWrites.clear();
    
    // Limpiar SharedPreferences
    await _prefs?.remove(_keyVictoryDaysCache);
    await _prefs?.remove(_keyPendingWrites);
    
    // Reset notifiers
    currentStreakNotifier.value = 0;
    loggedTodayNotifier.value = false;
    totalYearNotifier.value = 0;
    bestStreakNotifier.value = 0;
    
    debugPrint('📊 [PROGRESS_REPO] ✅ Local cache cleared');
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LECTURA
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtener VictoryDay para una fecha
  VictoryDay? getDay(DateTime date) {
    final dateISO = _dateToISO(date);
    return _cache[dateISO];
  }
  
  /// Obtener estados de gigantes para una fecha
  Map<String, int> getDayGiantStates(DateTime date, List<String> selectedGiants) {
    final day = getDay(date);
    if (day != null) {
      // Asegurar que todos los gigantes tienen valor
      return {
        for (final giant in selectedGiants)
          giant: day.giants[giant] ?? 0
      };
    }
    
    // Sin datos -> todos en gracia (0)
    return {
      for (final giant in selectedGiants) giant: 0
    };
  }
  
  /// Verificar si es día de victoria
  bool isVictoryDay(DateTime date) {
    final day = getDay(date);
    return day?.isVictoryDay ?? false;
  }
  
  /// Verificar si hay registro para hoy
  bool isLoggedToday() {
    final today = _dateToISO(DateTime.now());
    return _cache.containsKey(today);
  }
  
  /// Obtener días de victoria en un mes
  Set<String> getVictoryDaysInMonth(DateTime month) {
    final yearMonth = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    
    return _cache.entries
        .where((e) => e.key.startsWith(yearMonth))
        .where((e) => e.value.isVictoryDay)
        .map((e) => e.key)
        .toSet();
  }
  
  /// Total de victorias en un año
  int getTotalVictoriesForYear(int year) {
    return _cache.entries
        .where((e) => e.key.startsWith('$year-'))
        .where((e) => e.value.isVictoryDay)
        .length;
  }
  
  /// Racha actual
  int getCurrentStreak() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    DateTime checkDate = todayStart;
    
    // Si hoy NO es victoria, empezar desde ayer
    if (!isVictoryDay(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (!isVictoryDay(checkDate)) {
        return 0;
      }
    }
    
    int streak = 0;
    while (isVictoryDay(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }
  
  /// Mejor racha histórica
  int getBestStreakAllTime() {
    final victoryDates = _cache.entries
        .where((e) => e.value.isVictoryDay)
        .map((e) => e.value.date)
        .whereType<DateTime>()
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
  // ESCRITURA
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Establecer estado de un gigante para un día
  Future<void> setDayGiantState(
    DateTime date,
    String giantId,
    int value, {
    required List<String> selectedGiants,
    required double threshold,
  }) async {
    if (!_isInitialized) await init();
    if (_isFuture(date)) return;
    
    final dateISO = _dateToISO(date);
    
    // Obtener o crear day
    final existingGiants = getDayGiantStates(date, selectedGiants);
    existingGiants[giantId] = value.clamp(0, 1);
    
    // Crear/actualizar VictoryDay
    final victoryDay = VictoryDay.create(
      dateISO: dateISO,
      giants: existingGiants,
      threshold: threshold,
    );
    
    // Actualizar cache
    _cache[dateISO] = victoryDay;
    await _saveLocalCache();
    
    // Sincronizar con nube
    final uid = _currentUid;
    if (uid != null) {
      await _saveToCloud(uid, victoryDay);
    } else {
      // Sin conexión o sin usuario -> encolar
      _addPendingWrite(dateISO);
    }
    
    _updateAllNotifiers();
    
    debugPrint('📊 [PROGRESS_REPO] $dateISO.$giantId = $value');
  }
  
  /// Establecer todos los gigantes para un día
  Future<void> setDayAllGiants(
    DateTime date,
    int value, {
    required List<String> selectedGiants,
    required double threshold,
  }) async {
    if (!_isInitialized) await init();
    if (_isFuture(date)) return;
    
    final dateISO = _dateToISO(date);
    
    final giants = {
      for (final giant in selectedGiants) giant: value.clamp(0, 1)
    };
    
    final victoryDay = VictoryDay.create(
      dateISO: dateISO,
      giants: giants,
      threshold: threshold,
    );
    
    _cache[dateISO] = victoryDay;
    await _saveLocalCache();
    
    final uid = _currentUid;
    if (uid != null) {
      await _saveToCloud(uid, victoryDay);
    } else {
      _addPendingWrite(dateISO);
    }
    
    _updateAllNotifiers();
    
    debugPrint('📊 [PROGRESS_REPO] $dateISO.ALL = $value');
  }
  
  /// Registrar victoria completa para hoy
  Future<bool> logVictoryForToday({
    required List<String> selectedGiants,
    required double threshold,
  }) async {
    await setDayAllGiants(
      DateTime.now(),
      1,
      selectedGiants: selectedGiants,
      threshold: threshold,
    );
    return true;
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CLOUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _syncWithCloud(
    String uid,
    List<String> selectedGiants,
    double threshold,
  ) async {
    try {
      // CLOUD-FIRST: Siempre descargar desde Firestore como fuente de verdad.
      // NUNCA subir cache local durante el sync — un cache vacío post-logout
      // NO debe sobreescribir datos existentes en la nube.
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('victoryDays')
          .get(const GetOptions(source: Source.server));
      
      if (snapshot.docs.isNotEmpty) {
        // Nube tiene datos -> SIEMPRE usar como fuente de verdad
        debugPrint('📊 [PROGRESS_REPO] Loading ${snapshot.docs.length} days from cloud');
        
        _cache.clear();
        for (final doc in snapshot.docs) {
          _cache[doc.id] = VictoryDay.fromFirestore(doc);
        }
        await _saveLocalCache();
      } else {
        // Nube vacía -> usuario nuevo o sin datos, empezar limpio
        debugPrint('📊 [PROGRESS_REPO] Cloud empty, starting fresh (NOT uploading local cache)');
        _cache.clear();
        await _saveLocalCache();
      }
    } catch (e) {
      debugPrint('📊 [PROGRESS_REPO] Sync error (server): $e');
      // Si falla el server, intentar desde cache de Firestore SDK
      try {
        final fallback = await _firestore
            .collection('users')
            .doc(uid)
            .collection('victoryDays')
            .get(const GetOptions(source: Source.cache));
        if (fallback.docs.isNotEmpty) {
          debugPrint('📊 [PROGRESS_REPO] Using Firestore SDK cache as fallback');
          _cache.clear();
          for (final doc in fallback.docs) {
            _cache[doc.id] = VictoryDay.fromFirestore(doc);
          }
          await _saveLocalCache();
        }
      } catch (_) {
        debugPrint('📊 [PROGRESS_REPO] Firestore cache fallback also failed');
      }
    }
  }
  
  Future<void> _saveToCloud(String uid, VictoryDay day) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('victoryDays')
          .doc(day.dateISO)
          .set(day.toFirestore());
    } catch (e) {
      debugPrint('📊 [PROGRESS_REPO] Cloud save error: $e');
      _addPendingWrite(day.dateISO);
    }
  }
  
  void _startRealtimeSync(String uid) {
    _realtimeSubscription = _firestore
        .collection('users')
        .doc(uid)
        .collection('victoryDays')
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.removed) {
            _cache.remove(change.doc.id);
          } else {
            _cache[change.doc.id] = VictoryDay.fromFirestore(change.doc);
          }
        }
        _saveLocalCache();
        _updateAllNotifiers();
        debugPrint('📊 [PROGRESS_REPO] Realtime update: ${snapshot.docChanges.length} changes');
      },
      onError: (e) {
        debugPrint('📊 [PROGRESS_REPO] Realtime sync error: $e');
      },
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // PENDING WRITES (OFFLINE SUPPORT)
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _addPendingWrite(String dateISO) {
    if (!_pendingWrites.contains(dateISO)) {
      _pendingWrites.add(dateISO);
      _savePendingWrites();
    }
  }
  
  Future<void> _loadPendingWrites() async {
    final json = _prefs?.getString(_keyPendingWrites);
    if (json != null) {
      _pendingWrites = List<String>.from(jsonDecode(json));
    }
  }
  
  Future<void> _savePendingWrites() async {
    await _prefs?.setString(_keyPendingWrites, jsonEncode(_pendingWrites));
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LOCAL CACHE
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _loadLocalCache() async {
    try {
      final json = _prefs?.getString(_keyVictoryDaysCache);
      if (json != null && json.isNotEmpty) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        _cache = data.map((dateISO, dayData) => MapEntry(
          dateISO,
          VictoryDay.fromLocal(dateISO, dayData as Map<String, dynamic>),
        ));
        debugPrint('📊 [PROGRESS_REPO] Loaded ${_cache.length} days from local cache');
      }
    } catch (e) {
      debugPrint('📊 [PROGRESS_REPO] Local cache load error: $e');
      _cache = {};
    }
  }
  
  Future<void> _saveLocalCache() async {
    try {
      final data = _cache.map((dateISO, day) => MapEntry(dateISO, day.toLocal()));
      await _prefs?.setString(_keyVictoryDaysCache, jsonEncode(data));
    } catch (e) {
      debugPrint('📊 [PROGRESS_REPO] Local cache save error: $e');
    }
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
  
  void refreshNotifiers() => _updateAllNotifiers();
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  // Delegados a TimeUtils centralizado
  String _dateToISO(DateTime date) => TimeUtils.dateToISO(date);
  bool _isFuture(DateTime date) => TimeUtils.isFuture(date);
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MIGRACIÓN LEGACY
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Migrar desde VictoryScoringService legacy
  Future<void> migrateFromLegacy(
    SharedPreferences prefs,
    List<String> selectedGiants,
    double threshold,
  ) async {
    try {
      // Verificar si ya migramos
      if (_cache.isNotEmpty) {
        debugPrint('📊 [PROGRESS_REPO] Already has data, skipping migration');
        return;
      }
      
      // Leer datos legacy
      final legacyJson = prefs.getString('victory_by_giant_v1');
      if (legacyJson == null || legacyJson.isEmpty) {
        debugPrint('📊 [PROGRESS_REPO] No legacy data to migrate');
        return;
      }
      
      final legacyData = jsonDecode(legacyJson) as Map<String, dynamic>;
      
      for (final entry in legacyData.entries) {
        final dateISO = entry.key;
        final giants = (entry.value as Map).map(
          (k, v) => MapEntry(k.toString(), (v is int) ? v : 0),
        );
        
        final victoryDay = VictoryDay.create(
          dateISO: dateISO,
          giants: giants,
          threshold: threshold,
        );
        
        _cache[dateISO] = victoryDay;
      }
      
      await _saveLocalCache();
      _updateAllNotifiers();
      
      debugPrint('📊 [PROGRESS_REPO] ✅ Migrated ${_cache.length} days from legacy');
    } catch (e) {
      debugPrint('📊 [PROGRESS_REPO] Migration error: $e');
    }
  }
}
