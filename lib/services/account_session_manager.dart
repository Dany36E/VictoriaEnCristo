/// ═══════════════════════════════════════════════════════════════════════════
/// ACCOUNT SESSION MANAGER - Aislamiento Total por UID
/// Maneja cambios de cuenta, limpia cache al cambiar usuario, y previene
/// mezcla de datos entre cuentas.
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
import 'widget_sync_service.dart';
import 'victory_scoring_service.dart';
import 'journal_service.dart';
import 'favorites_service.dart';
import 'plan_progress_service.dart';
import 'badge_service.dart';
import 'battle_partner_service.dart';
import 'bible/bible_user_data_service.dart';
import 'bible/bible_reading_stats_service.dart';
import 'bible/collection_service.dart';
import 'bible/chapter_note_service.dart';
import 'bible/blb_api_service.dart';
import 'bible/red_letter_service.dart';
import 'bible/bible_dictionary_service.dart';
import 'bible/bible_timeline_service.dart';
import 'bible/typology_service.dart';
import 'bible/ot_quotes_service.dart';
import 'bible/gospel_harmony_service.dart';
import 'bible/treasury_service.dart';
import 'bible/map_events_service.dart';
import 'bible/share_cache_service.dart';
import 'connectivity_service.dart';
import 'notification_service.dart';
import 'exercise_log_service.dart';
import 'fcm_service.dart';
import 'learning/learning_cloud_sync.dart';
import 'learning/talents_service.dart';

/// Clave para guardar el último UID conocido
const String _keyLastKnownUid = 'account_last_known_uid';

/// Estado de la sesión
enum SessionState {
  idle,           // Sin usuario
  switching,      // Cambiando de cuenta (limpiando)
  bootstrapping,  // Cargando datos del nuevo usuario
  ready,          // Sesión activa y datos listos
  error,          // Error durante el proceso
}

class AccountSessionManager {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final AccountSessionManager _instance = AccountSessionManager._internal();
  factory AccountSessionManager() => _instance;
  AccountSessionManager._internal();
  
  static AccountSessionManager get I => _instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════
  
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  String? _currentSessionUid;
  StreamSubscription<User?>? _authSubscription;
  
  /// Estado actual de la sesión
  final ValueNotifier<SessionState> stateNotifier = ValueNotifier(SessionState.idle);
  
  /// Último error
  String? lastError;
  
  bool get isInitialized => _isInitialized;
  SessionState get state => stateNotifier.value;
  bool get isReady => state == SessionState.ready;
  String? get currentUid => _currentSessionUid;
  bool get hasActiveSession => _currentSessionUid != null && isReady;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Inicializar el manager y comenzar a escuchar cambios de auth
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🔐 [SESSION] Initializing AccountSessionManager...');
      
      _prefs = await SharedPreferences.getInstance();
      
      // Escuchar cambios de autenticación
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        _onAuthStateChanged,
        onError: (e) {
          debugPrint('🔐 [SESSION] Auth stream error: $e');
          lastError = e.toString();
        },
      );
      
      // Procesar usuario actual si existe
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _handleUserLogin(currentUser.uid);
      }
      
      _isInitialized = true;
      debugPrint('🔐 [SESSION] ✅ Initialized');
    } catch (e) {
      debugPrint('🔐 [SESSION] ❌ Init error: $e');
      lastError = e.toString();
      _isInitialized = true;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MANEJO DE CAMBIOS DE AUTH
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _onAuthStateChanged(User? user) async {
    if (user != null) {
      await _handleUserLogin(user.uid);
    } else {
      await _handleUserLogout();
    }
  }
  
  /// Manejar login de usuario - DETECTA CAMBIO DE CUENTA
  Future<void> _handleUserLogin(String newUid) async {
    debugPrint('🔐 [SESSION] User login detected: $newUid');
    
    final lastKnownUid = _prefs?.getString(_keyLastKnownUid);
    final isAccountChange = lastKnownUid != null && lastKnownUid != newUid;
    
    if (isAccountChange) {
      debugPrint('🔐 [SESSION] ⚠️ ACCOUNT CHANGE DETECTED!');
      debugPrint('   Previous: $lastKnownUid');
      debugPrint('   New: $newUid');
      
      // CRITICAL: Limpiar TODO el estado del usuario anterior
      await _performAccountSwitch(lastKnownUid, newUid);
    } else if (_currentSessionUid == newUid) {
      // Mismo usuario, ya activo o bootstrapping - no duplicar
      debugPrint('🔐 [SESSION] Same user already active/bootstrapping, skipping');
      return;
    }
    
    // Actualizar UID guardado (setString es async, pero guardar la referencia
    // en _currentSessionUid ANTES del await para prevenir reentrada desde stream)
    _currentSessionUid = newUid;
    await _prefs?.setString(_keyLastKnownUid, newUid);
    
    // Bootstrap del nuevo usuario
    await _bootstrapNewUser(newUid);
  }
  
  /// Manejar logout
  Future<void> _handleUserLogout() async {
    debugPrint('🔐 [SESSION] User logout detected');
    
    // 0. Flush de sincronización de Escuela del Reino + Talentos para no
    // perder cambios pendientes antes de desconectar.
    try {
      await LearningCloudSync.I.flush();
      await TalentsService.I.flushSync();
    } catch (e) {
      debugPrint('🔐 [SESSION] flush learning sync falló: $e');
    }
    
    // 1. Cancelar listeners de Firestore
    await _disconnectAllRepositories();
    BattlePartnerService.I.stop();
    BibleUserDataService.I.stop();
    ChapterNoteService.I.stop();
    CollectionService.I.stop();
    BibleReadingStatsService.I.stop();

    // 1b. Eliminar el token FCM de este dispositivo del user doc de Firestore
    // para que la Cloud Function deje de enviar push a este device para un
    // usuario que ya no está autenticado. Best-effort (no bloquea logout).
    unawaited(FcmService.I.clearTokenForUser());
    
    // 2. Reset estado en memoria
    _resetInMemoryState();
    
    // 3. CRÍTICO: Purgar cache local para evitar que datos stale
    // se suban a la nube si otro usuario inicia sesión después.
    // La nube es la fuente de verdad; al re-login se descargarán los datos.
    await _purgeAllLocalCache();
    
    _currentSessionUid = null;
    stateNotifier.value = SessionState.idle;
    
    debugPrint('🔐 [SESSION] ✅ Logout complete (local cache purged, cloud untouched)');
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CAMBIO DE CUENTA (CRÍTICO)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Realizar cambio de cuenta - LIMPIA TODO del usuario anterior
  Future<void> _performAccountSwitch(String oldUid, String newUid) async {
    debugPrint('🔐 [SESSION] 🔄 Performing account switch...');
    stateNotifier.value = SessionState.switching;
    
    try {
      // 1. Cancelar TODOS los listeners de Firestore del usuario anterior
      debugPrint('🔐 [SESSION] Step 1: Canceling Firestore listeners...');
      await _disconnectAllRepositories();
      
      // 2. Limpiar estado en memoria (controllers, notifiers, caches)
      debugPrint('🔐 [SESSION] Step 2: Resetting in-memory state...');
      _resetInMemoryState();
      
      // 3. PURGAR cache local completo (evita mezcla de datos)
      debugPrint('🔐 [SESSION] Step 3: Purging local cache...');
      await _purgeAllLocalCache();
      
      // 4. Limpiar widget a valores por defecto (discretos)
      debugPrint('🔐 [SESSION] Step 4: Resetting widget to defaults...');
      await _resetWidgetToDefaults();
      
      debugPrint('🔐 [SESSION] ✅ Account switch preparation complete');
    } catch (e) {
      debugPrint('🔐 [SESSION] ❌ Account switch error: $e');
      lastError = e.toString();
      // Continuar de todos modos - mejor tener algunos errores que mezclar datos
    }
  }
  
  /// Desconectar todos los repositorios (cancela listeners Firestore)
  Future<void> _disconnectAllRepositories() async {
    await Future.wait([
      ProfileRepository.I.disconnectUser(),
      ProgressRepository.I.disconnectUser(),
      JournalRepository.I.disconnectUser(),
      PlansRepository.I.disconnectUser(),
      FavoritesRepository.I.disconnectUser(),
      BadgeRepository.I.disconnectUser(),
    ]);
  }
  
  /// Reset estado en memoria de todos los servicios
  void _resetInMemoryState() {
    // Reset notifiers de ProfileRepository
    ProfileRepository.I.profileNotifier.value = null;
    
    // Reset notifiers de ProgressRepository
    ProgressRepository.I.currentStreakNotifier.value = 0;
    ProgressRepository.I.loggedTodayNotifier.value = false;
    ProgressRepository.I.totalYearNotifier.value = 0;
    ProgressRepository.I.bestStreakNotifier.value = 0;
    
    // Reset notifiers de JournalRepository
    JournalRepository.I.entriesNotifier.value = [];
    
    // Reset VictoryScoringService notifiers
    VictoryScoringService.I.currentStreakNotifier.value = 0;
    VictoryScoringService.I.loggedTodayNotifier.value = false;
    VictoryScoringService.I.totalYearNotifier.value = 0;
    VictoryScoringService.I.bestStreakNotifier.value = 0;
    
    // Reset BattlePartnerService notifiers
    BattlePartnerService.I.partnersNotifier.value = [];
    BattlePartnerService.I.pendingInvitesNotifier.value = [];
    BattlePartnerService.I.unreadMessagesNotifier.value = [];
    
    // Reset BibleUserDataService
    BibleUserDataService.I.stop();
    ChapterNoteService.I.stop();
    CollectionService.I.stop();
    BibleReadingStatsService.I.stop();
    
    debugPrint('🔐 [SESSION] In-memory state reset complete');
  }
  
  /// Purgar TODO el cache local (SharedPreferences)
  Future<void> _purgeAllLocalCache() async {
    try {
      // Limpiar caches de repositorios
      await Future.wait([
        ProfileRepository.I.clearLocalCache(),
        ProgressRepository.I.clearLocalCache(),
        JournalRepository.I.clearLocalCache(),
        PlansRepository.I.clearLocalCache(),
        FavoritesRepository.I.clearLocalCache(),
        BadgeRepository.I.clearLocalCache(),
      ]);
      
      // Limpiar servicios legacy que usan SharedPreferences directamente
      final prefs = await SharedPreferences.getInstance();
      
      // Keys de VictoryScoringService
      await prefs.remove('victory_by_giant_v1');
      await prefs.remove('migrated_victory_to_by_giant');
      await prefs.remove('victory_threshold');
      
      // Keys de OnboardingService
      await prefs.remove('onboarding_completed');
      await prefs.remove('selected_giants');
      await prefs.remove('selected_intensity');
      await prefs.remove('giant_frequencies_json');
      
      // Keys de JournalService
      await prefs.remove('journal_entries');

      // Keys del ExerciseLog (v1) — si no se purga, el nuevo usuario hereda
      // el historial del anterior hasta la próxima hidratación.
      await prefs.remove('exercise_log_v1');

      // Keys de otros servicios
      await prefs.remove('cloud_migration_done');
      
      // NO borrar _keyLastKnownUid - lo necesitamos para detectar cambios
      
      debugPrint('🔐 [SESSION] ✅ Local cache purged');
    } catch (e) {
      debugPrint('🔐 [SESSION] ⚠️ Purge error (continuing): $e');
    }
  }
  
  /// Reset widget a valores por defecto discretos
  Future<void> _resetWidgetToDefaults() async {
    try {
      await WidgetSyncService.I.init();
      await WidgetSyncService.I.clearToDefaults();
    } catch (e) {
      debugPrint('🔐 [SESSION] ⚠️ Widget reset error: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // BOOTSTRAP DEL NUEVO USUARIO
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Cargar datos del nuevo usuario desde la nube
  Future<UserProfile?> _bootstrapNewUser(String uid) async {
    debugPrint('🔐 [SESSION] 🚀 Bootstrapping user: $uid');
    stateNotifier.value = SessionState.bootstrapping;
    lastError = null;
    
    try {
      // 1. Inicializar repositorios si no lo están
      await Future.wait([
        ProfileRepository.I.init(),
        ProgressRepository.I.init(),
        JournalRepository.I.init(),
        PlansRepository.I.init(),
        FavoritesRepository.I.init(),
        BadgeRepository.I.init(),
      ]);
      
      // 2. Conectar ProfileRepository primero (contiene config de gigantes)
      final profile = await ProfileRepository.I.connectUser(uid);
      
      if (profile == null) {
        debugPrint('🔐 [SESSION] No profile found, new user');
        stateNotifier.value = SessionState.ready;
        return null;
      }
      
      // 3. Obtener configuración de gigantes
      final selectedGiants = profile.selectedGiants.isNotEmpty 
          ? profile.selectedGiants 
          : ['general'];
      final threshold = profile.victoryThreshold;
      
      // 4. Conectar resto de repositorios en paralelo
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
      
      // 5. Hidratar servicios locales con datos de cloud
      await _hydrateLocalServicesFromCloud(selectedGiants, threshold);
      
      // 6. Sincronizar widget con datos del nuevo usuario
      await _syncWidgetForUser(uid);
      
      // 7. Inicializar BattlePartnerService
      await BattlePartnerService.I.init(uid);
      BattlePartnerService.I.syncPublicProgress(); // fire-and-forget
      
      // 8. Inicializar BibleUserDataService
      await BibleUserDataService.I.init(uid);
      
      // 8b. Inicializar ChapterNoteService
      await ChapterNoteService.I.init(uid);
      
      // 9. Inicializar CollectionService y BibleReadingStatsService
      await CollectionService.I.init(uid);
      await BibleReadingStatsService.I.init(uid);

      // 9b. Hidratar el log de ejercicios desde la nube (cross-device).
      await ExerciseLogService.I.hydrateFromCloud();

      // 9c. Re-registrar el token FCM bajo el nuevo uid. Esto es idempotente
      // (set merge) y corrige el caso en que el token ya estaba obtenido
      // pero no se había escrito bajo este uid.
      unawaited(FcmService.I.registerTokenForCurrentUser());

      // 10. Inicializar BlbApiService (no depende de uid)
      await BlbApiService.instance.init();

      // 11. Inicializar conectividad
      unawaited(ConnectivityService.I.init());

      // 12. Precargar servicios de estudio offline (no bloquean)
      unawaited(_preloadBibleAssets());

      // 13. Reprogramar notificaciones (sobreviven reinicios de app)
      unawaited(_rescheduleNotifications());
      
      stateNotifier.value = SessionState.ready;
      
      debugPrint('🔐 [SESSION] ✅ Bootstrap complete for: $uid');
      debugPrint('   - Onboarding: ${profile.onboardingCompleted}');
      debugPrint('   - Giants: ${profile.selectedGiants}');
      
      return profile;
    } catch (e) {
      debugPrint('🔐 [SESSION] ❌ Bootstrap error: $e');
      lastError = e.toString();
      stateNotifier.value = SessionState.error;
      return null;
    }
  }
  
  /// Sincronizar widget con datos del usuario actual
  Future<void> _syncWidgetForUser(String uid) async {
    try {
      await WidgetSyncService.I.init();
      await WidgetSyncService.I.syncWidget();
      debugPrint('🔐 [SESSION] Widget synced for user: $uid');
    } catch (e) {
      debugPrint('🔐 [SESSION] ⚠️ Widget sync error: $e');
    }
  }
  
  /// Hidratar servicios locales (SharedPreferences) con datos ya descargados
  /// de Firestore por los repositorios. Esto asegura que la UI (que lee de
  /// VictoryScoringService y JournalService) tenga los datos correctos.
  Future<void> _hydrateLocalServicesFromCloud(
    List<String> selectedGiants,
    double threshold,
  ) async {
    try {
      debugPrint('🔐 [SESSION] Hydrating local services from cloud...');
      
      // --- Victory/Progress ---
      final cachedDays = ProgressRepository.I.cachedDays;
      if (cachedDays.isNotEmpty) {
        final Map<String, Map<String, int>> victoryData = {};
        for (final entry in cachedDays.entries) {
          victoryData[entry.key] = Map<String, int>.from(entry.value.giants);
        }
        
        final scoring = VictoryScoringService.I;
        await scoring.init();
        await scoring.restoreFromCloud(victoryData);
        
        debugPrint('🔐 [SESSION]   ✅ Progress: ${cachedDays.length} days hydrated');
      } else {
        debugPrint('🔐 [SESSION]   ℹ️ Progress: cloud empty');
      }
      
      // --- Journal ---
      final cachedEntries = JournalRepository.I.cachedEntries;
      if (cachedEntries.isNotEmpty) {
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
        
        debugPrint('🔐 [SESSION]   ✅ Journal: ${cachedEntries.length} entries hydrated');
      } else {
        debugPrint('🔐 [SESSION]   ℹ️ Journal: cloud empty');
      }
      
      // --- Favorites ---
      final cachedFavorites = FavoritesRepository.I.cachedFavorites;
      if (cachedFavorites.isNotEmpty) {
        final favService = FavoritesService();
        await favService.init();
        await favService.restoreFromCloud(cachedFavorites);
        
        debugPrint('🔐 [SESSION]   ✅ Favorites: ${cachedFavorites.length} restored');
      } else {
        debugPrint('🔐 [SESSION]   ℹ️ Favorites: cloud empty');
      }
      
      // --- Plan Progress ---
      final cachedPlans = PlansRepository.I.getAll();
      if (cachedPlans.isNotEmpty) {
        final planService = PlanProgressService.I;
        await planService.init();
        await planService.restoreFromCloud(cachedPlans);
        
        debugPrint('🔐 [SESSION]   ✅ Plans: ${cachedPlans.length} restored');
      } else {
        debugPrint('🔐 [SESSION]   ℹ️ Plans: cloud empty');
      }
      
      // --- Badges ---
      final cachedBadges = BadgeRepository.I.cachedLevels;
      if (cachedBadges.isNotEmpty) {
        await BadgeService.I.init();
        await BadgeService.I.restoreFromCloud(cachedBadges);
        
        debugPrint('🔐 [SESSION]   ✅ Badges: ${cachedBadges.length} levels restored');
      } else {
        debugPrint('🔐 [SESSION]   ℹ️ Badges: cloud empty');
      }
      
      debugPrint('🔐 [SESSION] ✅ Local services hydrated');
    } catch (e) {
      debugPrint('🔐 [SESSION] ⚠️ Hydration error: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS PÚBLICOS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtener perfil del usuario actual
  UserProfile? get currentProfile => ProfileRepository.I.currentProfile;
  
  /// Verificar si onboarding está completado
  bool get isOnboardingCompleted => currentProfile?.onboardingCompleted ?? false;
  
  /// Forzar refresh de datos desde la nube
  Future<UserProfile?> refresh() async {
    final uid = _currentSessionUid;
    if (uid == null) return null;
    return _bootstrapNewUser(uid);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CONTROL DE SUSCRIPCIONES (PARA DELETE ACCOUNT)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Detener TODAS las suscripciones de Firestore
  /// CRÍTICO: Llamar ANTES de eliminar datos para evitar spam de realtime updates
  Future<void> stopAllSubscriptions() async {
    debugPrint('🔐 [SESSION] Stopping all Firestore subscriptions...');
    
    try {
      // Cancelar nuestra suscripción de auth temporalmente
      // (la reactivaremos si el delete falla)
      await _authSubscription?.cancel();
      _authSubscription = null;
      
      // Desconectar todos los repositorios (cancela sus listeners)
      await _disconnectAllRepositories();
      
      // Reset estado en memoria para evitar escrituras basadas en datos viejos
      _resetInMemoryState();
      
      debugPrint('🔐 [SESSION] ✅ All subscriptions stopped');
    } catch (e) {
      debugPrint('🔐 [SESSION] ⚠️ Error stopping subscriptions: $e');
    }
  }
  
  /// ════════════════════════════════════════════════════════════════════════════
  /// HARD RESET PARA ELIMINACIÓN DE CUENTA
  /// ════════════════════════════════════════════════════════════════════════════
  /// Este método es DIFERENTE a logout:
  /// - Logout: preserva cache local para cuando el usuario vuelva
  /// - Delete: ELIMINA TODO porque la cuenta ya no existe
  /// ════════════════════════════════════════════════════════════════════════════
  Future<void> hardResetForAccountDeletion() async {
    debugPrint('🔐 [SESSION] 🗑️ HARD RESET FOR ACCOUNT DELETION');
    
    try {
      // 1. Cancelar suscripción de auth (si no se hizo ya)
      await _authSubscription?.cancel();
      _authSubscription = null;
      
      // 2. Desconectar repositorios (cancela listeners Firestore)
      await _disconnectAllRepositories();
      BattlePartnerService.I.stop();
      
      // 3. Reset COMPLETO de estado en memoria
      _resetInMemoryState();
      
      // 4. PURGAR cache local (NO "keeping data")
      await _purgeAllLocalCache();
      
      // 5. Limpiar widget a valores por defecto
      await _resetWidgetToDefaults();
      
      // 6. Limpiar UID guardado (la cuenta ya no existe)
      await _prefs?.remove(_keyLastKnownUid);
      _currentSessionUid = null;
      
      // 7. Estado a idle
      stateNotifier.value = SessionState.idle;
      
      debugPrint('🔐 [SESSION] ✅ Hard reset complete - all data cleared');
    } catch (e) {
      debugPrint('🔐 [SESSION] ⚠️ Hard reset error (continuing): $e');
      // Continuar de todos modos - mejor tener errores que dejar datos
    }
  }
  
  /// Reactivar listener de auth (si delete falló y usuario sigue logueado)
  Future<void> reactivateAuthListener() async {
    if (_authSubscription != null) return; // Ya activo
    
    debugPrint('🔐 [SESSION] Reactivating auth listener...');
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _onAuthStateChanged,
      onError: (e) {
        debugPrint('🔐 [SESSION] Auth stream error: $e');
        lastError = e.toString();
      },
    );
    
    // Re-procesar usuario actual si existe
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _handleUserLogin(currentUser.uid);
    }
  }
  
  /// Precargar assets bíblicos offline para acceso instantáneo
  Future<void> _preloadBibleAssets() async {
    try {
      await Future.wait([
        RedLetterService.instance.init(),
        BibleDictionaryService.instance.init(),
        BibleTimelineService.I.init(),
        TypologyService.instance.getAll(),
        OTQuotesService.instance.getAll(),
        GospelHarmonyService.instance.getAllSections(),
        TreasuryService.instance.getCrossReferences(1, 1, 1), // warm cache
        MapEventsService.I.preload(),
      ]);
      debugPrint('📖 [BIBLE] All offline assets preloaded');

      // Pre-caché de imágenes compartibles (no bloquea)
      unawaited(ShareCacheService.I.warmUp());
    } catch (e) {
      debugPrint('📖 [BIBLE] Preload error (non-blocking): $e');
    }
  }

  /// Reprogramar notificaciones tras reinicio de app
  Future<void> _rescheduleNotifications() async {
    try {
      final ns = NotificationService();
      await ns.initialize();
      await ns.scheduleAllNotifications();
      debugPrint('🔔 [SESSION] Notifications rescheduled');
    } catch (e) {
      debugPrint('🔔 [SESSION] Notification reschedule error (non-blocking): $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
  }
}
