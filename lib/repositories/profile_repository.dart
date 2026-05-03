/// ═══════════════════════════════════════════════════════════════════════════
/// PROFILE REPOSITORY - Repositorio de perfil con Cloud Sync
/// Fuente de verdad: Firestore /users/{uid}
/// Cache local: SharedPreferences
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../utils/retry_utils.dart';

class ProfileRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════

  static final ProfileRepository _instance = ProfileRepository._internal();
  factory ProfileRepository() => _instance;
  ProfileRepository._internal();

  static ProfileRepository get I => _instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _keyProfileCache = 'profile_cache_v1';
  static const String _keyLastSync = 'profile_last_sync';

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  UserProfile? _cachedProfile;
  StreamSubscription<DocumentSnapshot>? _profileSubscription;
  bool _lastCloudReadFailed = false;

  /// Guard contra connectUser concurrente (race condition)
  String? _connectingUid;
  Future<UserProfile?>? _connectFuture;

  /// Notificador de cambios de perfil
  final ValueNotifier<UserProfile?> profileNotifier = ValueNotifier(null);

  bool get isInitialized => _isInitialized;
  UserProfile? get currentProfile => _cachedProfile;
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  bool get hasUser => currentUid != null;

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();

      // Cargar cache local primero (UX instantánea)
      await _loadLocalCache();

      _isInitialized = true;
      debugPrint('👤 [PROFILE_REPO] Initialized');
    } catch (e) {
      debugPrint('👤 [PROFILE_REPO] Init error: $e');
      _isInitialized = true;
    }
  }

  /// Conectar con el usuario autenticado y sincronizar
  /// CLOUD-FIRST: Siempre descargar desde Firestore, nunca subir cache stale
  Future<UserProfile?> connectUser(String uid) async {
    // Guard: si ya hay un connectUser en progreso para este UID, esperar
    if (_connectingUid == uid && _connectFuture != null) {
      debugPrint('👤 [PROFILE_REPO] connectUser already in progress for $uid, awaiting...');
      return _connectFuture;
    }

    _connectingUid = uid;
    _connectFuture = _doConnectUser(uid);
    return _connectFuture;
  }

  Future<UserProfile?> _doConnectUser(String uid) async {
    if (!_isInitialized) await init();

    try {
      debugPrint('👤 [PROFILE_REPO] Connecting user: $uid');

      // Cancelar suscripción anterior si existe
      await _profileSubscription?.cancel();

      // Mantener cache local del mismo usuario para modo offline. Solo se
      // descarta si pertenece a otra cuenta.
      if (_cachedProfile != null && _cachedProfile!.uid != uid) {
        debugPrint('👤 [PROFILE_REPO] Cache is from different user, discarding');
        _cachedProfile = null;
      }

      // Intentar cargar desde Firestore (FUENTE DE VERDAD)
      final cloudProfile = await _loadFromCloud(uid);

      if (cloudProfile != null) {
        _cachedProfile = cloudProfile;
        await _saveLocalCache();
        profileNotifier.value = _cachedProfile;
        debugPrint('👤 [PROFILE_REPO] Loaded from cloud: ${cloudProfile.displayName}');
        debugPrint('👤 [PROFILE_REPO]   onboardingCompleted: ${cloudProfile.onboardingCompleted}');
        debugPrint('👤 [PROFILE_REPO]   selectedGiants: ${cloudProfile.selectedGiants}');
      } else {
        if (_cachedProfile != null && _cachedProfile!.uid == uid) {
          debugPrint('👤 [PROFILE_REPO] Offline fallback: using local profile cache');
          profileNotifier.value = _cachedProfile;
          _startRealtimeSync(uid);
          return _cachedProfile;
        }

        if (_lastCloudReadFailed) {
          debugPrint('👤 [PROFILE_REPO] No profile available while offline; waiting for cloud');
          _startRealtimeSync(uid);
          return null;
        }

        final user = FirebaseAuth.instance.currentUser;
        final newProfile = UserProfile.empty(
          uid,
          email: user?.email,
          displayName: user?.displayName ?? 'Usuario',
        );

        debugPrint('👤 [PROFILE_REPO] Creating new profile with onboardingCompleted=false');

        await _saveToCloud(uid, newProfile);
        _cachedProfile = newProfile;
        await _saveLocalCache();
        profileNotifier.value = _cachedProfile;
        debugPrint('👤 [PROFILE_REPO] Created new profile in cloud');
      }

      // Escuchar cambios en tiempo real
      _startRealtimeSync(uid);

      return _cachedProfile;
    } catch (e) {
      debugPrint('👤 [PROFILE_REPO] Connect error: $e');
      return null;
    } finally {
      _connectingUid = null;
      _connectFuture = null;
    }
  }

  /// Desconectar usuario (NO borra datos)
  Future<void> disconnectUser() async {
    debugPrint('👤 [PROFILE_REPO] Disconnecting user (keeping data)');

    _connectingUid = null;
    _connectFuture = null;

    // Cancelar suscripción de tiempo real
    await _profileSubscription?.cancel();
    _profileSubscription = null;

    // IMPORTANTE: NO borrar _cachedProfile ni cache local
    // Los datos se mantienen para mejor UX si el usuario vuelve a iniciar sesión

    profileNotifier.value = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LECTURA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener perfil actual (cache -> cloud)
  Future<UserProfile?> getProfile() async {
    if (!_isInitialized) await init();

    // Retornar cache primero
    if (_cachedProfile != null) {
      return _cachedProfile;
    }

    // Intentar cargar desde nube si hay usuario
    final uid = currentUid;
    if (uid != null) {
      return connectUser(uid);
    }

    return null;
  }

  /// Verificar si onboarding está completado
  Future<bool> isOnboardingCompleted() async {
    final profile = await getProfile();
    return profile?.onboardingCompleted ?? false;
  }

  /// Obtener gigantes seleccionados
  Future<List<String>> getSelectedGiants() async {
    final profile = await getProfile();
    return profile?.selectedGiants ?? [];
  }

  /// Fetch perfil directamente desde servidor (para ProfileGate).
  /// Retorna null si no existe. Si falla el server, intenta cache solo
  /// si el UID coincide con la sesión actual.
  Future<UserProfile?> fetchProfileFromServer(String uid) async {
    final cloudProfile = await _loadFromCloud(uid);
    if (cloudProfile != null) {
      _cachedProfile = cloudProfile;
      profileNotifier.value = cloudProfile;
    }
    return cloudProfile;
  }

  /// Crear/merge perfil minimal para un usuario nuevo (para ProfileGate).
  Future<void> createMinimalProfile({
    required String uid,
    String? email,
    String? displayName,
    String? photoURL,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': displayName ?? 'Usuario',
      'photoURL': photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      'onboardingCompleted': false,
      'selectedGiants': [],
    }, SetOptions(merge: true));
    debugPrint('👤 [PROFILE_REPO] Created/merged minimal profile');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESCRITURA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Actualizar perfil
  Future<bool> updateProfile(UserProfile Function(UserProfile) updater) async {
    if (!_isInitialized) await init();

    final uid = currentUid;
    if (uid == null) {
      debugPrint('👤 [PROFILE_REPO] Cannot update: no user logged in');
      return false;
    }

    try {
      final current = _cachedProfile ?? UserProfile.empty(uid);
      final updated = updater(current);

      // Guardar en nube
      await _saveToCloud(uid, updated);

      // Actualizar cache local
      _cachedProfile = updated;
      await _saveLocalCache();

      profileNotifier.value = _cachedProfile;

      debugPrint('👤 [PROFILE_REPO] Profile updated');
      return true;
    } catch (e) {
      debugPrint('👤 [PROFILE_REPO] Update error: $e');
      return false;
    }
  }

  /// Completar onboarding con gigantes y frecuencias
  Future<bool> completeOnboarding({
    required List<String> giants,
    required Map<String, String> frequencies,
  }) async {
    return updateProfile(
      (profile) => profile.copyWith(
        onboardingCompleted: true,
        selectedGiants: giants,
        giantFrequencies: frequencies,
      ),
    );
  }

  /// Actualizar configuración
  Future<bool> updateSettings({
    bool? bgmEnabled,
    bool? sfxEnabled,
    bool? isDarkMode,
    bool? notificationsEnabled,
  }) async {
    return updateProfile(
      (profile) => profile.copyWith(
        bgmEnabled: bgmEnabled,
        sfxEnabled: sfxEnabled,
        isDarkMode: isDarkMode,
        notificationsEnabled: notificationsEnabled,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLOUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<UserProfile?> _loadFromCloud(String uid) async {
    _lastCloudReadFailed = false;
    try {
      // FORZAR lectura desde servidor para evitar datos stale del cache
      // del SDK de Firestore (persiste entre reinicios de app)
      final doc = await retryWithBackoff(
        () => _firestore
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 15)),
      );

      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('👤 [PROFILE_REPO] Cloud load error (server): $e');
      // Si falla el servidor, intentar cache como fallback
      try {
        final doc = await _firestore
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.cache));
        if (doc.exists) {
          debugPrint('👤 [PROFILE_REPO] Using Firestore cache as fallback');
          return UserProfile.fromFirestore(doc);
        }
      } catch (e) {
        debugPrint('👤 [PROFILE_REPO] Cache fallback also failed: $e');
      }
      _lastCloudReadFailed = true;
      return null;
    }
  }

  Future<void> _saveToCloud(String uid, UserProfile profile) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set(profile.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('👤 [PROFILE_REPO] Cloud save error: $e');
      rethrow;
    }
  }

  void _startRealtimeSync(String uid) {
    _profileSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              _cachedProfile = UserProfile.fromFirestore(snapshot);
              _saveLocalCache(); // Sync to local
              profileNotifier.value = _cachedProfile;
              debugPrint('👤 [PROFILE_REPO] Realtime update received');
            }
          },
          onError: (e) {
            debugPrint('👤 [PROFILE_REPO] Realtime sync error: $e');
          },
        );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOCAL CACHE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadLocalCache() async {
    try {
      final json = _prefs?.getString(_keyProfileCache);
      if (json != null && json.isNotEmpty) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        _cachedProfile = UserProfile.fromLocal(data);
        profileNotifier.value = _cachedProfile;
        debugPrint('👤 [PROFILE_REPO] Loaded from local cache');
      }
    } catch (e) {
      debugPrint('👤 [PROFILE_REPO] Local cache load error: $e');
    }
  }

  Future<void> _saveLocalCache() async {
    try {
      if (_cachedProfile != null) {
        final json = jsonEncode(_cachedProfile!.toLocal());
        await _prefs?.setString(_keyProfileCache, json);
        await _prefs?.setString(_keyLastSync, DateTime.now().toIso8601String());
      }
    } catch (e) {
      debugPrint('👤 [PROFILE_REPO] Local cache save error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BORRADO (SOLO EXPLÍCITO)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Borrar solo cache local (el usuario debe confirmar)
  Future<void> clearLocalCache() async {
    debugPrint('👤 [PROFILE_REPO] Clearing LOCAL cache only');
    _connectingUid = null;
    _connectFuture = null;
    _cachedProfile = null;
    await _prefs?.remove(_keyProfileCache);
    await _prefs?.remove(_keyLastSync);
    profileNotifier.value = null;
  }

  /// Borrar todos los datos del usuario (nube + local) - IRREVERSIBLE
  /// Usar solo cuando el usuario explícitamente quiere eliminar su cuenta
  Future<bool> deleteAllUserData() async {
    final uid = currentUid;
    if (uid == null) return false;

    try {
      debugPrint('👤 [PROFILE_REPO] ⚠️ DELETING ALL USER DATA (cloud + local)');

      // 1. Cancelar suscripciones
      await _profileSubscription?.cancel();

      // 2. Borrar subcolecciones en Firestore
      // VictoryDays
      final victoryDays = await _firestore
          .collection('users')
          .doc(uid)
          .collection('victoryDays')
          .get();
      for (final doc in victoryDays.docs) {
        await doc.reference.delete();
      }

      // JournalEntries
      final journal = await _firestore
          .collection('users')
          .doc(uid)
          .collection('journalEntries')
          .get();
      for (final doc in journal.docs) {
        await doc.reference.delete();
      }

      // PlansProgress
      final plans = await _firestore.collection('users').doc(uid).collection('plansProgress').get();
      for (final doc in plans.docs) {
        await doc.reference.delete();
      }

      // WidgetConfig
      final widgets = await _firestore
          .collection('users')
          .doc(uid)
          .collection('widgetConfig')
          .get();
      for (final doc in widgets.docs) {
        await doc.reference.delete();
      }

      // 3. Borrar documento principal
      await _firestore.collection('users').doc(uid).delete();

      // 4. Borrar cache local
      await clearLocalCache();

      debugPrint('👤 [PROFILE_REPO] ✅ All user data deleted');
      return true;
    } catch (e) {
      debugPrint('👤 [PROFILE_REPO] Delete all error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MIGRACIÓN DESDE SERVICIOS LEGACY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Migrar datos desde OnboardingService legacy
  Future<void> migrateFromLegacyOnboarding(SharedPreferences prefs) async {
    try {
      final uid = currentUid;
      if (uid == null) return;

      // Verificar si ya hay datos en nube
      final cloudProfile = await _loadFromCloud(uid);
      if (cloudProfile != null && cloudProfile.onboardingCompleted) {
        debugPrint('👤 [PROFILE_REPO] Cloud already has onboarding data, skipping migration');
        return;
      }

      // Leer datos legacy
      final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      final selectedGiants = prefs.getStringList('selected_giants') ?? [];
      final frequenciesJson = prefs.getString('giant_frequencies_json');

      if (!onboardingCompleted || selectedGiants.isEmpty) {
        debugPrint('👤 [PROFILE_REPO] No legacy onboarding data to migrate');
        return;
      }

      Map<String, String> frequencies = {};
      if (frequenciesJson != null) {
        try {
          frequencies = Map<String, String>.from(jsonDecode(frequenciesJson));
        } catch (e) {
          debugPrint('👤 [PROFILE_REPO] Error parsing giant frequencies: $e');
        }
      }

      // Migrar a nuevo sistema
      await updateProfile(
        (profile) => profile.copyWith(
          onboardingCompleted: onboardingCompleted,
          selectedGiants: selectedGiants,
          giantFrequencies: frequencies,
        ),
      );

      debugPrint('👤 [PROFILE_REPO] ✅ Migrated legacy onboarding data');
    } catch (e) {
      debugPrint('👤 [PROFILE_REPO] Migration error: $e');
    }
  }
}
