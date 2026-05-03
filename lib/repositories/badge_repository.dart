/// ═══════════════════════════════════════════════════════════════════════════
/// BADGE REPOSITORY - Repositorio de insignias con Cloud Sync
/// Fuente de verdad: Firestore /users/{uid}/userSettings/badges
/// OPTIMIZADO: Un solo documento con mapa de niveles (minimiza ops)
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/retry_utils.dart';

class BadgeRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════

  static final BadgeRepository _instance = BadgeRepository._internal();
  factory BadgeRepository() => _instance;
  BadgeRepository._internal();

  static BadgeRepository get I => _instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _keyCacheV1 = 'badge_levels_cache_v1';
  static const String _keyPendingCloudSave = 'badge_pending_cloud_save_v1';

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Cache local: {categoryName: levelIndex}
  Map<String, int> _cache = {};
  bool _pendingCloudSave = false;

  /// Guard contra connectUser concurrente
  String? _connectingUid;
  Future<void>? _connectFuture;

  /// Suscripción realtime al documento único de insignias.
  StreamSubscription<DocumentSnapshot>? _realtimeSubscription;

  /// Callback para hidratar servicios locales cuando Firestore trae cambios.
  VoidCallback? onCloudCacheChanged;

  bool get isInitialized => _isInitialized;
  Map<String, int> get cachedLevels => Map.unmodifiable(_cache);
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadLocalCache();
      _pendingCloudSave = _prefs?.getBool(_keyPendingCloudSave) ?? false;
      _isInitialized = true;

      debugPrint('🏅 [BADGE_REPO] Initialized with ${_cache.length} cached levels');
    } catch (e) {
      debugPrint('🏅 [BADGE_REPO] Init error: $e');
      _isInitialized = true;
    }
  }

  /// Conectar con usuario y sincronizar (CLOUD-FIRST con merge)
  Future<void> connectUser(String uid) async {
    if (_connectingUid == uid && _connectFuture != null) {
      debugPrint('🏅 [BADGE_REPO] connectUser already in progress for $uid, awaiting...');
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
      debugPrint('🏅 [BADGE_REPO] Connecting user: $uid');
      await _realtimeSubscription?.cancel();
      await _syncFromCloud(uid);
      _startRealtimeSync(uid);
      debugPrint('🏅 [BADGE_REPO] ✅ Connected with ${_cache.length} badge levels');
    } catch (e) {
      debugPrint('🏅 [BADGE_REPO] Connect error: $e');
    } finally {
      _connectingUid = null;
      _connectFuture = null;
    }
  }

  /// Desconectar usuario (NO borra datos)
  Future<void> disconnectUser() async {
    debugPrint('🏅 [BADGE_REPO] Disconnecting (keeping data)');
    _connectingUid = null;
    _connectFuture = null;
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  /// Limpiar cache local
  Future<void> clearLocalCache() async {
    debugPrint('🏅 [BADGE_REPO] Clearing local cache');
    _connectingUid = null;
    _connectFuture = null;
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _cache.clear();
    await _prefs?.remove(_keyCacheV1);
    await _prefs?.remove(_keyPendingCloudSave);
    _pendingCloudSave = false;
    debugPrint('🏅 [BADGE_REPO] ✅ Local cache cleared');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLOUD OPERATIONS (OPTIMIZADO: un solo documento)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Referencia al documento único de badges
  DocumentReference _badgesDoc(String uid) =>
      _firestore.collection('users').doc(uid).collection('userSettings').doc('badges');

  /// Descargar badges desde cloud — MERGE: siempre tomar nivel más alto
  Future<void> _syncFromCloud(String uid) async {
    try {
      final localHadPendingSave = _pendingCloudSave;
      final doc = await retryWithBackoff(
        () => _badgesDoc(
          uid,
        ).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 15)),
      );

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final cloudLevels =
            (data['levels'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {};

        // Merge: tomar el nivel más alto entre local y cloud
        var changedByLocal = false;
        for (final entry in cloudLevels.entries) {
          final localLevel = _cache[entry.key] ?? -1;
          if (entry.value > localLevel) {
            _cache[entry.key] = entry.value;
          } else if (localLevel > entry.value) {
            changedByLocal = true;
          }
        }
        for (final localEntry in _cache.entries) {
          if (!cloudLevels.containsKey(localEntry.key)) {
            changedByLocal = true;
          }
        }
        await _saveLocalCache();

        if (localHadPendingSave || changedByLocal) {
          await saveAllToCloud(_cache);
        }

        debugPrint('🏅 [BADGE_REPO] Merged ${cloudLevels.length} badge levels from cloud');
      } else {
        debugPrint('🏅 [BADGE_REPO] Cloud empty, keeping local cache');
        // Si hay datos locales, subirlos a cloud para inicializar
        if (_cache.isNotEmpty) {
          await saveAllToCloud(_cache);
        }
      }
    } catch (e) {
      debugPrint('🏅 [BADGE_REPO] Cloud sync error: $e');
      // Mantener cache local si falla
    }
  }

  /// Guardar todos los niveles a cloud (un solo write)
  Future<void> saveAllToCloud(Map<String, int> levels) async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      _cache = Map.from(levels);
      await _saveLocalCache();

      await _badgesDoc(uid).set({
        'levels': levels,
        'totalUnlocked': levels.values.fold<int>(0, (acc, lvl) => acc + lvl + 1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _pendingCloudSave = false;
      await _prefs?.setBool(_keyPendingCloudSave, false);

      debugPrint('☁️ [BADGE_REPO] Saved ${levels.length} badge levels to cloud');
    } catch (e) {
      _pendingCloudSave = true;
      await _prefs?.setBool(_keyPendingCloudSave, true);
      debugPrint('❌ [BADGE_REPO] Cloud save error: $e');
    }
  }

  Future<void> retryPendingCloudSave() async {
    if (!_isInitialized) await init();
    if (!_pendingCloudSave) return;

    debugPrint('🏅 [BADGE_REPO] Retrying pending cloud save');
    await saveAllToCloud(_cache);
  }

  void _startRealtimeSync(String uid) {
    _realtimeSubscription = _badgesDoc(uid).snapshots().listen(
      (doc) {
        if (doc.metadata.hasPendingWrites || _pendingCloudSave) return;
        if (!doc.exists) return;

        final data = doc.data() as Map<String, dynamic>? ?? {};
        final cloudLevels =
            (data['levels'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {};

        var changedByCloud = false;
        var changedByLocal = false;
        for (final entry in cloudLevels.entries) {
          final localLevel = _cache[entry.key] ?? -1;
          if (entry.value > localLevel) {
            _cache[entry.key] = entry.value;
            changedByCloud = true;
          } else if (localLevel > entry.value) {
            changedByLocal = true;
          }
        }
        for (final localEntry in _cache.entries) {
          if (!cloudLevels.containsKey(localEntry.key)) {
            changedByLocal = true;
          }
        }

        if (changedByCloud) {
          _saveLocalCache();
          onCloudCacheChanged?.call();
          debugPrint('🏅 [BADGE_REPO] Realtime update: ${_cache.length} badge levels');
        }
        if (changedByLocal) {
          unawaited(saveAllToCloud(_cache));
        }
      },
      onError: (e) {
        debugPrint('🏅 [BADGE_REPO] Realtime sync error: $e');
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOCAL CACHE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadLocalCache() async {
    try {
      final jsonStr = _prefs?.getString(_keyCacheV1);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(jsonStr);
        _cache = decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (e) {
      debugPrint('🏅 [BADGE_REPO] Local cache load error: $e');
      _cache = {};
    }
  }

  Future<void> _saveLocalCache() async {
    try {
      await _prefs?.setString(_keyCacheV1, json.encode(_cache));
    } catch (e) {
      debugPrint('🏅 [BADGE_REPO] Local cache save error: $e');
    }
  }
}
