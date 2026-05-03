/// ═══════════════════════════════════════════════════════════════════════════
/// FAVORITES REPOSITORY - Repositorio de favoritos con Cloud Sync
/// Fuente de verdad: Firestore /users/{uid}/userSettings/favorites
/// OPTIMIZADO: Un solo documento con lista de versículos (minimiza ops)
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bible_verses.dart';
import '../utils/retry_utils.dart';

class FavoritesRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════

  static final FavoritesRepository _instance = FavoritesRepository._internal();
  factory FavoritesRepository() => _instance;
  FavoritesRepository._internal();

  static FavoritesRepository get I => _instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _keyCacheV1 = 'favorites_cache_v1';
  static const String _keyPendingCloudSave = 'favorites_pending_cloud_save_v1';

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Cache local de versículos favoritos
  List<BibleVerse> _cache = [];
  bool _pendingCloudSave = false;

  /// Guard contra connectUser concurrente
  String? _connectingUid;
  Future<void>? _connectFuture;

  /// Suscripción realtime al documento único de favoritos.
  StreamSubscription<DocumentSnapshot>? _realtimeSubscription;

  /// Callback para hidratar servicios locales cuando Firestore trae cambios.
  VoidCallback? onCloudCacheChanged;

  bool get isInitialized => _isInitialized;
  List<BibleVerse> get cachedFavorites => List.unmodifiable(_cache);
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

      debugPrint('⭐ [FAV_REPO] Initialized with ${_cache.length} cached favorites');
    } catch (e) {
      debugPrint('⭐ [FAV_REPO] Init error: $e');
      _isInitialized = true;
    }
  }

  /// Conectar con usuario y sincronizar (CLOUD-FIRST)
  Future<void> connectUser(String uid) async {
    if (_connectingUid == uid && _connectFuture != null) {
      debugPrint('⭐ [FAV_REPO] connectUser already in progress for $uid, awaiting...');
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
      debugPrint('⭐ [FAV_REPO] Connecting user: $uid');

      // CLOUD-FIRST: descargar desde Firestore
      await _realtimeSubscription?.cancel();
      await _syncFromCloud(uid);
      _startRealtimeSync(uid);

      debugPrint('⭐ [FAV_REPO] ✅ Connected with ${_cache.length} favorites');
    } catch (e) {
      debugPrint('⭐ [FAV_REPO] Connect error: $e');
    } finally {
      _connectingUid = null;
      _connectFuture = null;
    }
  }

  /// Desconectar usuario (NO borra datos)
  Future<void> disconnectUser() async {
    debugPrint('⭐ [FAV_REPO] Disconnecting (keeping data)');
    _connectingUid = null;
    _connectFuture = null;
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  /// Limpiar cache local
  Future<void> clearLocalCache() async {
    debugPrint('⭐ [FAV_REPO] Clearing local cache');
    _connectingUid = null;
    _connectFuture = null;
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _cache.clear();
    await _prefs?.remove(_keyCacheV1);
    await _prefs?.remove(_keyPendingCloudSave);
    _pendingCloudSave = false;
    debugPrint('⭐ [FAV_REPO] ✅ Local cache cleared');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLOUD OPERATIONS (OPTIMIZADO: un solo documento)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Referencia al documento único de favoritos
  DocumentReference _favoritesDoc(String uid) =>
      _firestore.collection('users').doc(uid).collection('userSettings').doc('favorites');

  /// Descargar favoritos desde cloud
  Future<void> _syncFromCloud(String uid) async {
    try {
      final hadPendingLocalSave = _pendingCloudSave;
      final localFavorites = List<BibleVerse>.from(_cache);
      final doc = await retryWithBackoff(
        () => _favoritesDoc(
          uid,
        ).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 15)),
      );

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final versesList = data['verses'] as List<dynamic>? ?? [];

        final cloudFavorites = versesList
            .map((v) => BibleVerse.fromJson(v as Map<String, dynamic>))
            .toList();
        _cache = hadPendingLocalSave ? localFavorites : cloudFavorites;
        await _saveLocalCache();

        if (hadPendingLocalSave) {
          await saveAllToCloud(_cache);
        }

        debugPrint('⭐ [FAV_REPO] Loaded ${_cache.length} favorites from cloud');
      } else {
        if (hadPendingLocalSave) {
          _cache = localFavorites;
          await _saveLocalCache();
          await saveAllToCloud(_cache);
          debugPrint('⭐ [FAV_REPO] Cloud empty, uploaded pending local favorites');
        } else {
          debugPrint('⭐ [FAV_REPO] Cloud empty, starting fresh');
          _cache.clear();
          await _saveLocalCache();
        }
      }
    } catch (e) {
      debugPrint('⭐ [FAV_REPO] Cloud sync error: $e');
      // Mantener cache local si falla
    }
  }

  Future<void> retryPendingCloudSave() async {
    if (!_isInitialized) await init();
    if (!_pendingCloudSave) return;

    debugPrint('⭐ [FAV_REPO] Retrying pending cloud save');
    await saveAllToCloud(_cache);
  }

  void _startRealtimeSync(String uid) {
    _realtimeSubscription = _favoritesDoc(uid).snapshots().listen(
      (doc) {
        if (doc.metadata.hasPendingWrites || _pendingCloudSave) return;

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final versesList = data['verses'] as List<dynamic>? ?? [];
          _cache = versesList.map((v) => BibleVerse.fromJson(v as Map<String, dynamic>)).toList();
        } else {
          _cache.clear();
        }

        _saveLocalCache();
        onCloudCacheChanged?.call();
        debugPrint('⭐ [FAV_REPO] Realtime update: ${_cache.length} favorites');
      },
      onError: (e) {
        debugPrint('⭐ [FAV_REPO] Realtime sync error: $e');
      },
    );
  }

  /// Guardar todos los favoritos a cloud (un solo write)
  Future<void> saveAllToCloud(List<BibleVerse> favorites) async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      _cache = List.from(favorites);
      await _saveLocalCache();

      await _favoritesDoc(uid).set({
        'verses': favorites.map((v) => v.toJson()).toList(),
        'count': favorites.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _pendingCloudSave = false;
      await _prefs?.setBool(_keyPendingCloudSave, false);

      debugPrint('☁️ [FAV_REPO] Saved ${favorites.length} favorites to cloud');
    } catch (e) {
      _pendingCloudSave = true;
      await _prefs?.setBool(_keyPendingCloudSave, true);
      debugPrint('❌ [FAV_REPO] Cloud save error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOCAL CACHE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadLocalCache() async {
    try {
      final jsonStr = _prefs?.getString(_keyCacheV1);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonStr);
        _cache = jsonList.map((v) => BibleVerse.fromJson(v as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('⭐ [FAV_REPO] Local cache load error: $e');
      _cache = [];
    }
  }

  Future<void> _saveLocalCache() async {
    try {
      final jsonList = _cache.map((v) => v.toJson()).toList();
      await _prefs?.setString(_keyCacheV1, json.encode(jsonList));
    } catch (e) {
      debugPrint('⭐ [FAV_REPO] Local cache save error: $e');
    }
  }
}
