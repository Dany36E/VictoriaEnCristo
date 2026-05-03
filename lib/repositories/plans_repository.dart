/// ═══════════════════════════════════════════════════════════════════════════
/// PLANS REPOSITORY - Repositorio de progreso de planes con Cloud Sync
/// Fuente de verdad: Firestore /users/{uid}/plansProgress/{planId}
/// Cache local: SharedPreferences
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plan_progress_cloud.dart';
import '../utils/retry_utils.dart';
import '../services/user_pref_cloud_sync_service.dart';

class PlansRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════

  static final PlansRepository _instance = PlansRepository._internal();
  factory PlansRepository() => _instance;
  PlansRepository._internal();

  static PlansRepository get I => _instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _keyPlansCache = 'plans_cache_v1';
  static const String _keyActivePlan = 'active_plan_id';
  static const String _keyPendingWrites = 'plans_pending_writes';

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Cache: planId -> PlanProgressCloud
  Map<String, PlanProgressCloud> _cache = {};

  /// ID del plan activo
  String? _activePlanId;

  /// Cola de operaciones pendientes
  List<String> _pendingWrites = [];

  /// Suscripción a cambios
  StreamSubscription<QuerySnapshot>? _realtimeSubscription;

  /// Callback para hidratar servicios locales cuando Firestore trae cambios.
  VoidCallback? onCloudCacheChanged;

  /// Guard contra connectUser concurrente (race condition)
  String? _connectingUid;
  Future<void>? _connectFuture;

  /// Notificador del plan activo
  final ValueNotifier<PlanProgressCloud?> activePlanNotifier = ValueNotifier(null);

  bool get isInitialized => _isInitialized;
  String? get activePlanId => _activePlanId;
  bool get hasActivePlan => _activePlanId != null && _activePlanId!.isNotEmpty;
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadLocalCache();
      await _loadPendingWrites();
      _activePlanId = _prefs?.getString(_keyActivePlan);

      _isInitialized = true;
      _updateNotifier();

      debugPrint(
        '📚 [PLANS_REPO] Initialized with ${_cache.length} cached plans, active: $_activePlanId',
      );
    } catch (e) {
      debugPrint('📚 [PLANS_REPO] Init error: $e');
      _isInitialized = true;
    }
  }

  /// Conectar con usuario y sincronizar
  /// CLOUD-FIRST: Siempre descargar desde Firestore, nunca subir cache stale
  Future<void> connectUser(String uid) async {
    // Guard: si ya hay un connectUser en progreso para este UID, esperar
    if (_connectingUid == uid && _connectFuture != null) {
      debugPrint('📚 [PLANS_REPO] connectUser already in progress for $uid, awaiting...');
      await _connectFuture;
      return;
    }

    _connectingUid = uid;
    _connectFuture = _doConnectUser(uid);
    await _connectFuture;
  }

  Future<void> _doConnectUser(String uid) async {
    if (!_isInitialized) await init();

    try {
      debugPrint('📚 [PLANS_REPO] Connecting user: $uid');

      await _realtimeSubscription?.cancel();

      final pendingPlans = <String, PlanProgressCloud>{};
      for (final planId in _pendingWrites) {
        final progress = _cache[planId];
        if (progress != null) pendingPlans[planId] = progress;
      }

      // Mantener cache local hasta confirmar que cloud/cache SDK respondió.
      // Si el usuario arranca sin internet, la UI conserva los datos locales.
      _pendingWrites.clear();

      // OPTIMIZACIÓN: confiamos en el listener `.snapshots()` para hidratar.
      // Antes hacíamos un `_syncWithCloud` con `Source.server` que duplicaba
      // las lecturas en cada login. Plans son pocos docs (uno por plan
      // suscrito) así que el listener basta.

      await _replayPendingWrites(uid, pendingPlans);

      _startRealtimeSync(uid);
      _updateNotifier();
    } catch (e) {
      debugPrint('📚 [PLANS_REPO] Connect error: $e');
    } finally {
      _connectingUid = null;
      _connectFuture = null;
    }
  }

  /// Desconectar usuario (NO borra datos)
  Future<void> disconnectUser() async {
    debugPrint('📚 [PLANS_REPO] Disconnecting (keeping data)');
    _connectingUid = null;
    _connectFuture = null;
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  /// Limpiar cache local (usado al cambiar de cuenta)
  Future<void> clearLocalCache() async {
    debugPrint('📚 [PLANS_REPO] Clearing local cache');

    _connectingUid = null;
    _connectFuture = null;

    // Cancelar listener
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;

    // Limpiar cache en memoria
    _cache.clear();
    _pendingWrites.clear();
    _activePlanId = null;

    // Limpiar SharedPreferences
    await _prefs?.remove(_keyPlansCache);
    await _prefs?.remove(_keyActivePlan);
    await _prefs?.remove(_keyPendingWrites);

    // Reset notifier
    activePlanNotifier.value = null;

    debugPrint('📚 [PLANS_REPO] ✅ Local cache cleared');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LECTURA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener progreso de un plan
  PlanProgressCloud? getProgress(String planId) {
    return _cache[planId];
  }

  /// Obtener progreso del plan activo
  PlanProgressCloud? get activeProgress {
    if (_activePlanId == null) return null;
    return _cache[_activePlanId];
  }

  /// Obtener todos los progresos
  List<PlanProgressCloud> getAll() {
    return _cache.values.toList();
  }

  /// Verificar si un día está completado
  bool isDayCompleted(String planId, int dayIndex) {
    return _cache[planId]?.isDayCompleted(dayIndex) ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESCRITURA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Establecer plan activo
  Future<void> setActivePlan(String planId) async {
    if (!_isInitialized) await init();

    _activePlanId = planId;
    await _prefs?.setString(_keyActivePlan, planId);
    UserPrefCloudSyncService.I.markDirty();

    // Crear progreso inicial si no existe
    if (!_cache.containsKey(planId)) {
      final progress = PlanProgressCloud.create(planId);
      _cache[planId] = progress;
      await _saveLocalCache();

      final uid = _currentUid;
      if (uid != null) {
        await _saveToCloud(uid, progress);
      } else {
        _addPendingWrite(planId);
      }
    }

    _updateNotifier();
    debugPrint('📚 [PLANS_REPO] Set active plan: $planId');
  }

  /// Limpiar plan activo
  Future<void> clearActivePlan() async {
    _activePlanId = null;
    await _prefs?.remove(_keyActivePlan);
    UserPrefCloudSyncService.I.markDirty();
    _updateNotifier();
  }

  Future<void> reloadActivePlanFromPrefs() async {
    if (!_isInitialized) await init();
    _activePlanId = _prefs?.getString(_keyActivePlan);
    _updateNotifier();
  }

  /// Marcar día como completado
  Future<void> completeDay(String planId, int dayIndex, int totalDays) async {
    if (!_isInitialized) await init();

    var progress = _cache[planId] ?? PlanProgressCloud.create(planId);
    progress = progress.withDayCompleted(dayIndex, totalDays);

    _cache[planId] = progress;
    await _saveLocalCache();

    final uid = _currentUid;
    if (uid != null) {
      await _saveToCloud(uid, progress);
    } else {
      _addPendingWrite(planId);
    }

    _updateNotifier();
    debugPrint('📚 [PLANS_REPO] Completed day $dayIndex of $planId');
  }

  /// Actualizar último día leído
  Future<void> updateLastDayRead(String planId, int dayIndex) async {
    if (!_isInitialized) await init();

    var progress = _cache[planId] ?? PlanProgressCloud.create(planId);
    progress = progress.copyWith(lastDayRead: dayIndex);

    _cache[planId] = progress;
    await _saveLocalCache();

    final uid = _currentUid;
    if (uid != null) {
      await _saveToCloud(uid, progress);
    } else {
      _addPendingWrite(planId);
    }

    _updateNotifier();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLOUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  // ignore: unused_element
  Future<void> _syncWithCloud(String uid) async {
    try {
      // CLOUD-FIRST: Siempre descargar desde Firestore como fuente de verdad.
      // NUNCA subir cache local durante el sync — un cache vacío post-logout
      // NO debe sobreescribir datos existentes en la nube.
      final snapshot = await retryWithBackoff(
        () => _firestore
            .collection('users')
            .doc(uid)
            .collection('plansProgress')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 15)),
      );

      if (snapshot.docs.isNotEmpty) {
        // Nube tiene datos -> SIEMPRE usar como fuente de verdad
        debugPrint('📚 [PLANS_REPO] Loading ${snapshot.docs.length} plans from cloud');

        _cache.clear();
        for (final doc in snapshot.docs) {
          _cache[doc.id] = PlanProgressCloud.fromFirestore(doc);
        }
        await _saveLocalCache();
      } else {
        // Nube vacía -> usuario nuevo o sin datos, empezar limpio
        debugPrint('📚 [PLANS_REPO] Cloud empty, starting fresh (NOT uploading local cache)');
        _cache.clear();
        await _saveLocalCache();
      }
    } catch (e) {
      debugPrint('📚 [PLANS_REPO] Sync error (server): $e');
      // Si falla el server, intentar desde cache de Firestore SDK
      try {
        final fallback = await _firestore
            .collection('users')
            .doc(uid)
            .collection('plansProgress')
            .get(const GetOptions(source: Source.cache));
        if (fallback.docs.isNotEmpty) {
          debugPrint('📚 [PLANS_REPO] Using Firestore SDK cache as fallback');
          _cache.clear();
          for (final doc in fallback.docs) {
            _cache[doc.id] = PlanProgressCloud.fromFirestore(doc);
          }
          await _saveLocalCache();
        }
      } catch (e) {
        debugPrint('📚 [PLANS_REPO] Firestore cache fallback also failed: $e');
      }
    }
  }

  Future<void> _saveToCloud(String uid, PlanProgressCloud progress) async {
    final saved = await _trySaveToCloud(uid, progress);
    if (!saved) _addPendingWrite(progress.planId);
  }

  Future<bool> _trySaveToCloud(String uid, PlanProgressCloud progress) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('plansProgress')
          .doc(progress.planId)
          .set(progress.toFirestore());
      return true;
    } catch (e) {
      debugPrint('📚 [PLANS_REPO] Cloud save error: $e');
      return false;
    }
  }

  void _startRealtimeSync(String uid) {
    _realtimeSubscription = _firestore
        .collection('users')
        .doc(uid)
        .collection('plansProgress')
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.removed) {
                _cache.remove(change.doc.id);
              } else {
                _cache[change.doc.id] = PlanProgressCloud.fromFirestore(change.doc);
              }
            }
            _saveLocalCache();
            _updateNotifier();
            if (!snapshot.metadata.hasPendingWrites) {
              onCloudCacheChanged?.call();
            }
          },
          onError: (e) {
            debugPrint('📚 [PLANS_REPO] Realtime sync error: $e');
          },
        );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PENDING WRITES
  // ═══════════════════════════════════════════════════════════════════════════

  void _addPendingWrite(String planId) {
    if (!_pendingWrites.contains(planId)) {
      _pendingWrites.add(planId);
      _savePendingWrites();
    }
  }

  Future<void> _replayPendingWrites(String uid, Map<String, PlanProgressCloud> pendingPlans) async {
    if (pendingPlans.isEmpty) return;

    final failedWrites = <String>[];

    for (final entry in pendingPlans.entries) {
      _cache[entry.key] = entry.value;
      final saved = await _trySaveToCloud(uid, entry.value);
      if (!saved) failedWrites.add(entry.key);
    }

    _pendingWrites = failedWrites;
    await _saveLocalCache();
    await _savePendingWrites();
    debugPrint(
      '📚 [PLANS_REPO] Pending replay: ${pendingPlans.length - failedWrites.length}/${pendingPlans.length} applied',
    );
  }

  Future<void> retryPendingWrites() async {
    if (!_isInitialized) await init();
    final uid = _currentUid;
    if (uid == null || _pendingWrites.isEmpty) return;

    final pendingPlans = <String, PlanProgressCloud>{};
    for (final planId in _pendingWrites) {
      final progress = _cache[planId];
      if (progress != null) pendingPlans[planId] = progress;
    }

    if (pendingPlans.isEmpty) {
      _pendingWrites.clear();
      await _savePendingWrites();
      return;
    }

    debugPrint('📚 [PLANS_REPO] Retrying ${pendingPlans.length} pending writes');
    await _replayPendingWrites(uid, pendingPlans);
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
      final json = _prefs?.getString(_keyPlansCache);
      if (json != null && json.isNotEmpty) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        _cache = data.map(
          (planId, progressData) => MapEntry(
            planId,
            PlanProgressCloud.fromLocal(planId, progressData as Map<String, dynamic>),
          ),
        );
      }
    } catch (e) {
      debugPrint('📚 [PLANS_REPO] Local cache load error: $e');
      _cache = {};
    }
  }

  Future<void> _saveLocalCache() async {
    try {
      final data = _cache.map((planId, progress) => MapEntry(planId, progress.toLocal()));
      await _prefs?.setString(_keyPlansCache, jsonEncode(data));
    } catch (e) {
      debugPrint('📚 [PLANS_REPO] Local cache save error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICADOR
  // ═══════════════════════════════════════════════════════════════════════════

  void _updateNotifier() {
    activePlanNotifier.value = activeProgress;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MIGRACIÓN LEGACY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Migrar desde PlanProgressService legacy
  Future<void> migrateFromLegacy(SharedPreferences prefs) async {
    try {
      if (_cache.isNotEmpty) {
        debugPrint('📚 [PLANS_REPO] Already has data, skipping migration');
        return;
      }

      final legacyJson = prefs.getString('plan_all_progress');
      final legacyActivePlan = prefs.getString('plan_active_id');

      if (legacyJson == null || legacyJson.isEmpty) {
        debugPrint('📚 [PLANS_REPO] No legacy data to migrate');
        return;
      }

      final legacyData = jsonDecode(legacyJson) as Map<String, dynamic>;

      for (final entry in legacyData.entries) {
        final planId = entry.key;
        final data = entry.value as Map<String, dynamic>;

        final progress = PlanProgressCloud(
          planId: planId,
          lastDayRead: data['lastDayRead'] as int? ?? 0,
          completedDays: Set<int>.from(
            (data['completedDays'] as List?)?.map((e) => e as int) ?? [],
          ),
          currentStreak: data['currentStreak'] as int? ?? 0,
          bestStreak: data['bestStreak'] as int? ?? 0,
          completed: data['completed'] as bool? ?? false,
          startedAt: data['startedAt'] != null ? DateTime.tryParse(data['startedAt']) : null,
          completedAt: data['completedAt'] != null ? DateTime.tryParse(data['completedAt']) : null,
          lastCompletedAt: data['lastCompletedAt'] != null
              ? DateTime.tryParse(data['lastCompletedAt'])
              : null,
          updatedAt: DateTime.now(),
        );

        _cache[planId] = progress;
      }

      if (legacyActivePlan != null) {
        _activePlanId = legacyActivePlan;
        await _prefs?.setString(_keyActivePlan, legacyActivePlan);
        UserPrefCloudSyncService.I.markDirty();
      }

      await _saveLocalCache();
      _updateNotifier();

      debugPrint('📚 [PLANS_REPO] ✅ Migrated ${_cache.length} plans from legacy');
    } catch (e) {
      debugPrint('📚 [PLANS_REPO] Migration error: $e');
    }
  }
}
