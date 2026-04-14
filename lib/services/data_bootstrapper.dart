/// ═══════════════════════════════════════════════════════════════════════════
/// DATA BOOTSTRAPPER - Orquestador de inicio de sesión y carga de datos
/// Coordina la inicialización de todos los repositorios al hacer login
/// y la desconexión limpia (sin borrado) al hacer logout
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/profile_repository.dart';
import '../repositories/progress_repository.dart';
import '../repositories/journal_repository.dart';
import '../repositories/plans_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/badge_repository.dart';
import '../models/user_profile.dart';
import 'progress_sync_adapter.dart';
import 'journal_sync_adapter.dart';
import 'favorites_sync_adapter.dart';
import 'plans_sync_adapter.dart';
import 'badge_sync_adapter.dart';
import 'victory_scoring_service.dart';
import 'journal_service.dart';
import 'favorites_service.dart';
import 'plan_progress_service.dart';
import 'badge_service.dart';

/// Estado del bootstrapper
enum BootstrapState {
  idle,       // Sin sesión
  loading,    // Cargando datos
  ready,      // Datos listos
  error,      // Error de carga
}

class DataBootstrapper {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final DataBootstrapper _instance = DataBootstrapper._internal();
  factory DataBootstrapper() => _instance;
  DataBootstrapper._internal();
  
  static DataBootstrapper get I => _instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════
  
  bool _isInitialized = false;
  StreamSubscription<User?>? _authSubscription;
  String? _currentBootstrapUid; // Guard contra bootstrap duplicado concurrente
  
  /// Estado actual
  final ValueNotifier<BootstrapState> stateNotifier = ValueNotifier(BootstrapState.idle);
  
  /// Error de último intento
  String? lastError;
  
  bool get isInitialized => _isInitialized;
  BootstrapState get state => stateNotifier.value;
  bool get isReady => state == BootstrapState.ready;
  bool get hasUser => FirebaseAuth.instance.currentUser != null;
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Inicializar el bootstrapper y escuchar cambios de auth
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🚀 [BOOTSTRAP] Initializing...');
      
      // Inicializar repositorios (solo preparan SharedPreferences)
      await Future.wait([
        ProfileRepository.I.init(),
        ProgressRepository.I.init(),
        JournalRepository.I.init(),
        PlansRepository.I.init(),
        FavoritesRepository.I.init(),
        BadgeRepository.I.init(),
      ]);
      
      // Inicializar sync adapters (escuchan cambios de auth automáticamente)
      ProgressSyncAdapter.I.init();
      JournalSyncAdapter.I.init();
      FavoritesSyncAdapter.I.init();
      PlansSyncAdapter.I.init();
      BadgeSyncAdapter.I.init();
      
      // Escuchar cambios de autenticación
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
      
      // Si ya hay usuario conectado, hacer bootstrap
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _bootstrapUser(user.uid);
      }
      
      _isInitialized = true;
      debugPrint('🚀 [BOOTSTRAP] Initialized');
    } catch (e) {
      debugPrint('🚀 [BOOTSTRAP] Init error: $e');
      lastError = e.toString();
      _isInitialized = true;
    }
  }
  
  /// Reactivar listener de auth (después de delete account que lo canceló)
  Future<void> reactivateAuthListener() async {
    if (_authSubscription != null) return; // Ya activo
    
    debugPrint('🚀 [BOOTSTRAP] Reactivating auth listener...');
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
    
    // Re-procesar usuario actual si existe
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _bootstrapUser(currentUser.uid);
    }
  }
  
  /// Manejar cambios de autenticación
  void _onAuthStateChanged(User? user) async {
    if (user != null) {
      // Usuario conectado -> bootstrap
      await _bootstrapUser(user.uid);
    } else {
      // Usuario desconectado -> limpiar estado (NO borrar datos)
      await _onUserDisconnected();
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // BOOTSTRAP (LOGIN)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Cargar todos los datos del usuario desde la nube
  Future<UserProfile?> _bootstrapUser(String uid) async {
    // Guard: evitar bootstrap duplicado concurrente
    if (_currentBootstrapUid == uid) {
      debugPrint('🚀 [BOOTSTRAP] Already bootstrapping $uid, skipping duplicate');
      return null;
    }
    _currentBootstrapUid = uid;
    
    debugPrint('🚀 [BOOTSTRAP] Starting for user: $uid');
    stateNotifier.value = BootstrapState.loading;
    lastError = null;
    
    try {
      // 1. Conectar ProfileRepository primero (contiene config de gigantes)
      final profile = await ProfileRepository.I.connectUser(uid);
      
      if (profile == null) {
        debugPrint('🚀 [BOOTSTRAP] No profile found, creating new');
        stateNotifier.value = BootstrapState.ready;
        return null;
      }
      
      // 2. Obtener configuración de gigantes
      final selectedGiants = profile.selectedGiants.isNotEmpty 
          ? profile.selectedGiants 
          : ['general'];
      final threshold = profile.victoryThreshold;
      
      // 3. Conectar resto de repositorios en paralelo
      await Future.wait([
        ProgressRepository.I.connectUser(
          uid,
          selectedGiants: selectedGiants,
          threshold: threshold,
        ),
        JournalRepository.I.connectUser(uid),
        PlansRepository.I.connectUser(uid),
        FavoritesRepository.I.connectUser(uid),
        BadgeRepository.I.connectUser(uid),
      ]);
      
      // 4. CRÍTICO: Hidratar servicios locales con datos de cloud.
      // Los repositorios ya descargaron de Firestore; ahora transferimos
      // esos datos a VictoryScoringService y JournalService (que son los
      // que la UI realmente lee desde SharedPreferences).
      await _hydrateLocalServicesFromCloud(selectedGiants, threshold);
      
      stateNotifier.value = BootstrapState.ready;
      
      debugPrint('🚀 [BOOTSTRAP] ✅ Complete for user: $uid');
      debugPrint('   - Onboarding: ${profile.onboardingCompleted}');
      debugPrint('   - Giants: ${profile.selectedGiants}');
      
      return profile;
    } catch (e) {
      debugPrint('🚀 [BOOTSTRAP] ❌ Error: $e');
      lastError = e.toString();
      stateNotifier.value = BootstrapState.error;
      return null;
    }
  }
  
  /// Forzar re-bootstrap (útil si cambian gigantes)
  Future<UserProfile?> refresh() async {
    final uid = currentUid;
    if (uid == null) return null;
    _currentBootstrapUid = null; // Permitir re-bootstrap
    return _bootstrapUser(uid);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HIDRATACIÓN: CLOUD → SERVICIOS LOCALES
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Después de que los repositorios descargan de Firestore, transferir
  /// esos datos a los servicios locales (SharedPreferences) que la UI lee.
  Future<void> _hydrateLocalServicesFromCloud(
    List<String> selectedGiants,
    double threshold,
  ) async {
    try {
      debugPrint('🚀 [BOOTSTRAP] Hydrating local services from cloud...');
      
      // --- Victory/Progress ---
      final cachedDays = ProgressRepository.I.cachedDays;
      if (cachedDays.isNotEmpty) {
        // Convertir Map<String, VictoryDay> → Map<String, Map<String, int>>
        final Map<String, Map<String, int>> victoryData = {};
        for (final entry in cachedDays.entries) {
          victoryData[entry.key] = Map<String, int>.from(entry.value.giants);
        }
        
        final scoring = VictoryScoringService.I;
        await scoring.init();
        await scoring.restoreFromCloud(victoryData);
        
        debugPrint('🚀 [BOOTSTRAP]   ✅ Progress: ${cachedDays.length} days hydrated');
      } else {
        debugPrint('🚀 [BOOTSTRAP]   ℹ️ Progress: cloud empty, nothing to hydrate');
      }
      
      // --- Journal ---
      final cachedEntries = JournalRepository.I.cachedEntries;
      if (cachedEntries.isNotEmpty) {
        // Convertir JournalEntryCloud → JournalEntry (servicio local)
        final localEntries = cachedEntries.values.map((cloud) => JournalEntry(
          id: cloud.id,
          date: cloud.timestamp,
          content: cloud.content,
          mood: cloud.mood,
          triggers: cloud.triggers,
          hadVictory: cloud.hadVictory,
          verseOfDay: cloud.verseOfDay,
        )).toList();
        
        final journalService = JournalService();
        await journalService.initialize();
        await journalService.restoreFromCloud(localEntries);
        
        debugPrint('🚀 [BOOTSTRAP]   ✅ Journal: ${cachedEntries.length} entries hydrated');
      } else {
        debugPrint('🚀 [BOOTSTRAP]   ℹ️ Journal: cloud empty, nothing to hydrate');
      }
      
      // --- Favorites ---
      final cachedFavorites = FavoritesRepository.I.cachedFavorites;
      if (cachedFavorites.isNotEmpty) {
        final favService = FavoritesService();
        await favService.init();
        await favService.restoreFromCloud(cachedFavorites);
        
        debugPrint('🚀 [BOOTSTRAP]   ✅ Favorites: ${cachedFavorites.length} restored');
      } else {
        debugPrint('🚀 [BOOTSTRAP]   ℹ️ Favorites: cloud empty, nothing to hydrate');
      }
      
      // --- Plan Progress ---
      final cachedPlans = PlansRepository.I.getAll();
      if (cachedPlans.isNotEmpty) {
        final planService = PlanProgressService.I;
        await planService.init();
        await planService.restoreFromCloud(cachedPlans);
        
        debugPrint('🚀 [BOOTSTRAP]   ✅ Plans: ${cachedPlans.length} restored');
      } else {
        debugPrint('🚀 [BOOTSTRAP]   ℹ️ Plans: cloud empty, nothing to hydrate');
      }
      
      // --- Badges ---
      final cachedBadges = BadgeRepository.I.cachedLevels;
      if (cachedBadges.isNotEmpty) {
        await BadgeService.I.init();
        await BadgeService.I.restoreFromCloud(cachedBadges);
        
        debugPrint('🚀 [BOOTSTRAP]   ✅ Badges: ${cachedBadges.length} levels restored');
      } else {
        debugPrint('🚀 [BOOTSTRAP]   ℹ️ Badges: cloud empty, nothing to hydrate');
      }
      
      debugPrint('🚀 [BOOTSTRAP] ✅ Local services hydrated from cloud');
    } catch (e) {
      debugPrint('🚀 [BOOTSTRAP] ⚠️ Hydration error: $e');
      // No fallar el bootstrap por un error de hidratación
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LOGOUT (NO BORRA DATOS)
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _onUserDisconnected() async {
    debugPrint('🚀 [BOOTSTRAP] User disconnected');
    
    // Desconectar repositorios (cancelan suscripciones)
    await Future.wait([
      ProfileRepository.I.disconnectUser(),
      ProgressRepository.I.disconnectUser(),
      JournalRepository.I.disconnectUser(),
      PlansRepository.I.disconnectUser(),
      FavoritesRepository.I.disconnectUser(),
      BadgeRepository.I.disconnectUser(),
    ]);
    
    // CRÍTICO: Limpiar cache local para que un re-login
    // no encuentre datos stale que puedan subirse a cloud
    await Future.wait([
      ProfileRepository.I.clearLocalCache(),
      ProgressRepository.I.clearLocalCache(),
      JournalRepository.I.clearLocalCache(),
      PlansRepository.I.clearLocalCache(),
      FavoritesRepository.I.clearLocalCache(),
      BadgeRepository.I.clearLocalCache(),
    ]);
    
    stateNotifier.value = BootstrapState.idle;
    _currentBootstrapUid = null; // Permitir re-bootstrap con nuevo usuario
    
    debugPrint('🚀 [BOOTSTRAP] Disconnected (local cache cleared, cloud untouched)');
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // BORRADO EXPLÍCITO (SOLO CUANDO EL USUARIO LO SOLICITA)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Borrar solo cache local (datos en nube se mantienen)
  /// Usar cuando el usuario quiere "liberar espacio" o "limpiar dispositivo"
  Future<void> clearLocalCacheOnly() async {
    debugPrint('🚀 [BOOTSTRAP] ⚠️ Clearing LOCAL cache only');
    
    await Future.wait([
      ProfileRepository.I.clearLocalCache(),
      ProgressRepository.I.clearLocalCache(),
      JournalRepository.I.clearLocalCache(),
      PlansRepository.I.clearLocalCache(),
      FavoritesRepository.I.clearLocalCache(),
      BadgeRepository.I.clearLocalCache(),
    ]);
    
    debugPrint('🚀 [BOOTSTRAP] ✅ Local cache cleared');
  }
  
  /// Borrar TODOS los datos del usuario (nube + local)
  /// ⚠️ IRREVERSIBLE - Solo usar cuando el usuario confirma eliminar cuenta
  Future<bool> deleteAllUserData() async {
    debugPrint('🚀 [BOOTSTRAP] ⚠️⚠️⚠️ DELETING ALL USER DATA ⚠️⚠️⚠️');
    
    try {
      // Usar ProfileRepository que borra todo en cascada
      final success = await ProfileRepository.I.deleteAllUserData();
      
      if (success) {
        // Limpiar caches locales de otros repos
        await Future.wait([
          ProgressRepository.I.clearLocalCache(),
          JournalRepository.I.clearLocalCache(),
          PlansRepository.I.clearLocalCache(),
          FavoritesRepository.I.clearLocalCache(),
          BadgeRepository.I.clearLocalCache(),
        ]);
      }
      
      return success;
    } catch (e) {
      debugPrint('🚀 [BOOTSTRAP] Delete all error: $e');
      return false;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MIGRACIÓN DESDE SISTEMA LEGACY
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Migrar datos desde servicios legacy (SharedPreferences directos)
  /// Llamar después del primer login si es usuario existente
  Future<void> migrateFromLegacy() async {
    final uid = currentUid;
    if (uid == null) {
      debugPrint('🚀 [BOOTSTRAP] Cannot migrate: no user');
      return;
    }
    
    debugPrint('🚀 [BOOTSTRAP] Starting legacy migration...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Verificar si ya se migró
      final migrated = prefs.getBool('cloud_migration_done') ?? false;
      if (migrated) {
        debugPrint('🚀 [BOOTSTRAP] Already migrated, skipping');
        return;
      }
      
      // Obtener perfil actual
      final profile = ProfileRepository.I.currentProfile;
      final selectedGiants = profile?.selectedGiants ?? ['general'];
      final threshold = profile?.victoryThreshold ?? 0.60;
      
      // Migrar cada servicio
      await ProfileRepository.I.migrateFromLegacyOnboarding(prefs);
      await ProgressRepository.I.migrateFromLegacy(prefs, selectedGiants, threshold);
      await JournalRepository.I.migrateFromLegacy(prefs);
      await PlansRepository.I.migrateFromLegacy(prefs);
      
      // Marcar como migrado
      await prefs.setBool('cloud_migration_done', true);
      
      // Re-sincronizar con nube
      await refresh();
      
      debugPrint('🚀 [BOOTSTRAP] ✅ Legacy migration complete');
    } catch (e) {
      debugPrint('🚀 [BOOTSTRAP] Migration error: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtener perfil actual
  UserProfile? get currentProfile => ProfileRepository.I.currentProfile;
  
  /// Verificar si onboarding está completado
  bool get isOnboardingCompleted => currentProfile?.onboardingCompleted ?? false;
  
  /// Obtener gigantes seleccionados
  List<String> get selectedGiants => currentProfile?.selectedGiants ?? [];
  
  /// Obtener umbral de victoria
  double get victoryThreshold => currentProfile?.victoryThreshold ?? 0.60;
  
  /// Dispose
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
  }
}
