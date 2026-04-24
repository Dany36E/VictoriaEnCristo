import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_data.dart';
import 'screens/home_screen.dart';
import 'widgets/error_boundary.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding/onboarding_welcome_screen.dart';
import 'screens/widget_settings_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/devotional_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/battle_partner/battle_partner_screen.dart';
import 'services/theme_service.dart';
import 'services/favorites_service.dart';
import 'services/onboarding_service.dart';
import 'services/audio_engine.dart';
import 'services/app_error_handler.dart';
import 'services/feedback_engine.dart';
import 'services/exercise_log_service.dart';
import 'services/content_repository.dart';
import 'services/widget_sync_service.dart';
import 'services/victory_scoring_service.dart';
import 'services/jesus_widget_service.dart';
import 'services/data_bootstrapper.dart';
import 'services/account_session_manager.dart';
import 'services/daily_verse_service.dart';
import 'repositories/profile_repository.dart';
import 'models/user_profile.dart';
import 'utils/time_utils.dart';
import 'services/bible/bible_parser_service.dart';
import 'services/bible/bible_download_service.dart';
import 'services/notification_service.dart';
import 'services/emergency_sos_service.dart';
import 'services/fcm_service.dart';
import 'services/daily_practice_service.dart';
import 'services/learning/learning_registry.dart';
import 'data/devotionals.dart';

/// RouteObserver global para detectar navegación (usado por HomeScreen)
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // google_fonts: desactivar descargas en runtime. Las fuentes están
  // bundled en `google_fonts/` y declaradas como fonts nativas en pubspec,
  // así evitamos tráfico de red y latencia al pintar texto.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Inicializar Firebase con opciones de plataforma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics: capturar errores no manejados.
  // NOTA: los errores de layout (RenderFlex overflow por N píxeles) no
  // deberían reportarse como FATAL — no crashean la app, sólo pintan una
  // franja rayada en debug. Los degradamos a non-fatal para que no ensucien
  // el dashboard de estabilidad. El resto de errores siguen siendo fatal.
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    final isLayoutOverflow = msg.contains('RenderFlex overflowed') ||
        msg.contains('overflowed by') ||
        msg.contains('A RenderFlex overflowed');
    if (isLayoutOverflow) {
      // No fatal, pero sí queda registrado.
      FirebaseCrashlytics.instance.recordFlutterError(details);
      return;
    }
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Analytics: se usa en NavigatorObserver (ver MaterialApp)

  // Firestore: garantizar persistencia offline y cache generoso
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  // ═══════════════════════════════════════════════════════════════════════════
  // FASE 1 — CRÍTICO pre-runApp (bloquea el primer frame)
  // Solo lo indispensable para renderizar Login/Home correctamente.
  // ═══════════════════════════════════════════════════════════════════════════
  final themeService = ThemeService();
  final onboardingService = OnboardingService();
  final favoritesService = FavoritesService();
  final audioEngine = AudioEngine.I;
  final contentRepo = ContentRepository.I;

  await Future.wait([
    themeService.initialize(),
    onboardingService.init(),
    favoritesService.init(),
    audioEngine.init(),
    contentRepo.init(),
    Devotionals.init(),
  ]);

  // ═══════════════════════════════════════════════════════════════════════════
  // FASE 2 — dependientes pre-runApp (Home necesita streak y bootstrap)
  // ═══════════════════════════════════════════════════════════════════════════
  final scoringService = VictoryScoringService.I;
  await scoringService.init();
  await DataBootstrapper.I.init();
  await AccountSessionManager.I.init();

  // Si el audio estaba habilitado, intentar reproducir (fire-and-forget)
  if (audioEngine.bgmEnabled.value) {
    audioEngine.startBgm().then((success) {
      if (!success) {
        debugPrint('⚠️ [MAIN] BGM no pudo iniciarse al arrancar la app');
      }
    }).catchError((e) { debugPrint('❌ [MAIN] Error iniciando BGM: $e'); });
  }

  runApp(VictoriaEnCristoApp(
    themeService: themeService,
    onboardingService: onboardingService,
  ));

  // ═══════════════════════════════════════════════════════════════════════════
  // FASE 3 — NO CRÍTICO post-runApp (después del primer frame)
  // Estos servicios no son necesarios para la primera pantalla y
  // diferirlos acelera el tiempo de arranque percibido.
  // ═══════════════════════════════════════════════════════════════════════════
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final sw = Stopwatch()..start();
    try {
      final notificationService = NotificationService();
      await Future.wait([
        FeedbackEngine.I.init(),
        ExerciseLogService.I.init(),
        WidgetSyncService.I.init(),
        JesusWidgetService.I.init(),
        notificationService.initialize(),
        BibleDownloadService.I.init(),
        EmergencySosService.I.init(),
        DailyPracticeService.I.init(),
        FcmService.I.init(),
        // Escuela del Reino: un único entrypoint en lugar de 18 inits sueltos.
        LearningRegistry.I.initAll(),
      ]);
      // Requieren que las anteriores estén listas
      await Future.wait([
        BibleParserService.I.init(),
        notificationService.scheduleAllNotifications(),
      ]);
      WidgetSyncService.I.syncWidget();
      debugPrint('🚀 [MAIN] Deferred services ready in ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('⚠️ [MAIN] Deferred init error: $e');
    }
  });
}

class VictoriaEnCristoApp extends StatefulWidget {
  final ThemeService themeService;
  final OnboardingService onboardingService;
  
  const VictoriaEnCristoApp({
    super.key, 
    required this.themeService,
    required this.onboardingService,
  });

  @override
  State<VictoriaEnCristoApp> createState() => _VictoriaEnCristoAppState();
}

class _VictoriaEnCristoAppState extends State<VictoriaEnCristoApp>
    with WidgetsBindingObserver {
  late bool _isDarkMode;
  String? _pendingRoute;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _navigationChannel = const MethodChannel('victoria/navigation');
  /// Fecha conocida para detectar cambio de día al volver del background
  String _lastKnownDate = TimeUtils.todayISO();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isDarkMode = widget.themeService.isDarkMode;
    widget.themeService.addListener(_onThemeChanged);
    _updateSystemUI();
    _checkInitialRoute();
    WidgetSyncService.I.registerInteractionCallback(navigatorKey: _navigatorKey);

    // Deep-link desde notificaciones locales.
    // Ejecutamos tras el primer frame para asegurar que el Navigator exista.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeNotificationPayload(NotificationService.lastTapPayload.value);
      NotificationService.lastTapPayload.addListener(_onNotificationPayload);
    });
  }

  void _onNotificationPayload() {
    _consumeNotificationPayload(NotificationService.lastTapPayload.value);
  }

  /// Traduce el payload de una notificación a una ruta y navega.
  void _consumeNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    // Limpiamos antes de navegar para no re-disparar si vuelve a reconstruir.
    NotificationService.lastTapPayload.value = null;

    try {
      if (payload == NotificationService.payloadMorning) {
        nav.push(MaterialPageRoute(builder: (_) => const DevotionalScreen()));
      } else if (payload == NotificationService.payloadNight) {
        nav.push(MaterialPageRoute(builder: (_) => const JournalScreen()));
      } else if (payload == NotificationService.payloadBattleInvite ||
          payload == NotificationService.payloadBattleMessage ||
          payload == NotificationService.payloadBattleSos) {
        nav.push(MaterialPageRoute(builder: (_) => const BattlePartnerScreen()));
      } else if (payload == NotificationService.payloadVictory) {
        // Victoria se marca desde Home; llevamos a home sin push extra.
        nav.popUntil((r) => r.isFirst);
      } else if (payload == NotificationService.payloadReengagement) {
        nav.popUntil((r) => r.isFirst);
      } else if (payload.startsWith(NotificationService.payloadPlanPrefix)) {
        // Plan deep-link: por ahora llevamos a home; el Plan Screen se abre
        // desde el dashboard. (Extender aquí cuando haya ruta específica.)
        nav.popUntil((r) => r.isFirst);
      } else {
        debugPrint('🔔 Payload de notificación desconocido: $payload');
      }
    } catch (e) {
      debugPrint('⚠️ Error navegando desde notificación: $e');
    }
  }
  
  /// Lee la ruta inicial desde el widget (Android)
  Future<void> _checkInitialRoute() async {
    try {
      final route = await _navigationChannel.invokeMethod<String>('getInitialRoute');
      if (route != null && route.isNotEmpty && mounted) {
        setState(() => _pendingRoute = route);
      }
    } catch (e) {
      debugPrint('⚠️ [NAVIGATION] Error leyendo initial route: $e');
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.themeService.removeListener(_onThemeChanged);
    NotificationService.lastTapPayload.removeListener(_onNotificationPayload);
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LIFECYCLE — BGM pause/resume + detección de cambio de día
  // ═══════════════════════════════════════════════════════════════════════
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = AudioEngine.I;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Pausar BGM al salir al fondo
        engine.pauseBgm();
        break;
      case AppLifecycleState.resumed:
        // Reanudar BGM si el usuario lo tenía habilitado
        if (engine.bgmEnabled.value) {
          engine.resumeBgm();
        }
        // Sincronizar widget al volver (actualiza saludo por hora del día)
        WidgetSyncService.I.syncWidget();
        // Detectar cambio de día
        final today = TimeUtils.todayISO();
        if (today != _lastKnownDate) {
          _lastKnownDate = today;
          debugPrint('🌅 [LIFECYCLE] Cambio de día detectado → refrescando datos');
          // Refrescar versículo del día
          DailyVerseService.I.refreshToday();
          // Refrescar scoring (streak, loggedToday)
          VictoryScoringService.I.refreshAfterDayChange();
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }
  
  void _onThemeChanged() {
    setState(() {
      _isDarkMode = widget.themeService.isDarkMode;
    });
    _updateSystemUI();
  }
  
  void _updateSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: _isDarkMode ? AppTheme.darkBackground : AppTheme.backgroundColor,
        systemNavigationBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  void _handleThemeChange() {
    setState(() {
      _isDarkMode = widget.themeService.isDarkMode;
    });
    _updateSystemUI();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = widget.themeService.currentTheme;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: AppErrorHandler.I.messengerKey,
      title: 'Victoria en Cristo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      navigatorObservers: [
        routeObserver,
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      // Ruta inicial
      initialRoute: '/',
      routes: {
        '/widget-settings': (context) => const WidgetSettingsScreen(),
        '/emergency': (context) => const EmergencyScreen(),
      },
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => _buildHomeOrOnboarding(),
        );
      },
      builder: (context, child) {
        return AppThemeData.provider(
          theme: appTheme,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _buildHomeOrOnboarding(),
    );
  }
  
  /// Widget que decide dinámicamente qué mostrar basándose en el estado actual
  /// CLOUD-DRIVEN: La decisión de Home vs Onboarding es 100% basada en Firestore
  Widget _buildHomeOrOnboarding() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mostrar pantalla de carga mientras se verifica auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Si NO está autenticado => Login
        if (!snapshot.hasData || snapshot.data == null) {
          return LoginScreen(onThemeChanged: _handleThemeChange);
        }
        
        // Usuario autenticado => Verificar perfil en NUBE (no cache local)
        final user = snapshot.data!;
        
        return _ProfileGate(
          user: user,
          onThemeChanged: _handleThemeChange,
          pendingRoute: _pendingRoute,
          onRouteConsumed: () => setState(() => _pendingRoute = null),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE GATE - Decide Home vs Onboarding basado en CLOUD (no cache)
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileGate extends StatefulWidget {
  final User user;
  final VoidCallback onThemeChanged;
  final String? pendingRoute;
  final VoidCallback onRouteConsumed;
  
  const _ProfileGate({
    required this.user,
    required this.onThemeChanged,
    required this.pendingRoute,
    required this.onRouteConsumed,
  });

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

enum _ProfileGateStatus { loading, needsOnboarding, ready, error }

class _ProfileGateState extends State<_ProfileGate> {
  _ProfileGateStatus _status = _ProfileGateStatus.loading;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _checkProfileFromCloud();
    // Escuchar cambios de perfil (ej: cuando onboarding se completa)
    // para transicionar automáticamente de Onboarding → Home
    ProfileRepository.I.profileNotifier.addListener(_onProfileChanged);
  }
  
  @override
  void dispose() {
    ProfileRepository.I.profileNotifier.removeListener(_onProfileChanged);
    super.dispose();
  }
  
  @override
  void didUpdateWidget(covariant _ProfileGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia el usuario, re-verificar
    if (oldWidget.user.uid != widget.user.uid) {
      _checkProfileFromCloud();
    }
  }
  
  /// Detectar cambios en el perfil (cloud sync / realtime updates)
  /// Esto permite que cuando el onboarding se completa y el perfil se actualiza
  /// en Firestore, el Gate transicione automáticamente a Home sin navegación manual
  void _onProfileChanged() {
    final profile = ProfileRepository.I.profileNotifier.value;
    if (profile == null) return;
    if (profile.uid != widget.user.uid) return;
    
    // Si estamos en onboarding y el perfil ahora está completo → transicionar a Home
    if (_status == _ProfileGateStatus.needsOnboarding &&
        profile.onboardingCompleted &&
        profile.selectedGiants.isNotEmpty) {
      debugPrint('🚪 [PROFILE_GATE] 🎉 Profile updated! Onboarding now complete, transitioning to Home');
      _bootstrapAndGoHome();
    }
  }
  
  /// Verificación asíncrona de seguridad: consultar cloud directamente
  /// para detectar si el onboarding se completó pero el listener no disparó
  bool _isVerifying = false;
  Future<void> _verifyStillNeedsOnboarding() async {
    if (_isVerifying) return;
    _isVerifying = true;
    
    try {
      final uid = widget.user.uid;
      final profile = await _fetchProfileFromCloud(uid);
      
      if (!mounted || _status != _ProfileGateStatus.needsOnboarding) return;
      
      if (profile != null && 
          profile.onboardingCompleted && 
          profile.selectedGiants.isNotEmpty) {
        debugPrint('🚪 [PROFILE_GATE] 🔍 Cloud verify found completed profile! Transitioning...');
        _bootstrapAndGoHome();
      }
    } catch (e) {
      debugPrint('🚪 [PROFILE_GATE] Verify warning: $e');
    } finally {
      _isVerifying = false;
    }
  }
  
  /// Bootstrap repositorios y transicionar a Home
  Future<void> _bootstrapAndGoHome() async {
    if (!mounted) return;
    setState(() => _status = _ProfileGateStatus.loading);
    
    try {
      await _bootstrapRepositories(widget.user.uid);
      if (mounted) {
        setState(() => _status = _ProfileGateStatus.ready);
      }
    } catch (e) {
      debugPrint('🚪 [PROFILE_GATE] Bootstrap error during transition: $e');
      if (mounted) {
        // Aún transicionar a Home aunque el bootstrap falle parcialmente
        setState(() => _status = _ProfileGateStatus.ready);
      }
    }
  }
  
  /// Verificar perfil DIRECTAMENTE desde Firestore (no cache)
  /// Esta es la ÚNICA fuente de verdad para decidir navegación
  Future<void> _checkProfileFromCloud() async {
    if (!mounted) return;
    
    setState(() {
      _status = _ProfileGateStatus.loading;
      _errorMessage = null;
    });
    
    final uid = widget.user.uid;
    debugPrint('🚪 [PROFILE_GATE] Checking profile for UID: $uid');
    
    // PRIMERO: Limpiar cache local si es de otro usuario
    final cachedProfile = ProfileRepository.I.currentProfile;
    if (cachedProfile != null && cachedProfile.uid != uid) {
      debugPrint('🚪 [PROFILE_GATE] ⚠️ Cache is from different user (${cachedProfile.uid}), clearing...');
      await ProfileRepository.I.clearLocalCache();
    }
    
    try {
      // 1. FIX: Usuarios anónimos viejos sin onboarding => signOut
      if (widget.user.isAnonymous) {
        final creationTime = widget.user.metadata.creationTime;
        if (creationTime != null) {
          final timeSinceCreation = DateTime.now().difference(creationTime);
          // Si la cuenta anónima tiene más de 1 minuto y no hay perfil válido
          if (timeSinceCreation.inMinutes > 1) {
            final profile = await _fetchProfileFromCloud(uid);
            if (profile == null || !profile.onboardingCompleted) {
              debugPrint('🚪 [PROFILE_GATE] Old anonymous user without onboarding, signing out');
              await FirebaseAuth.instance.signOut();
              return;
            }
          }
        }
      }
      
      // 2. Cargar perfil desde Firestore (NO cache)
      final profile = await _fetchProfileFromCloud(uid);
      
      if (!mounted) return;
      
      // 3. Decidir navegación basado en perfil cloud
      if (profile == null) {
        // NO existe documento => crear minimal y enviar a Onboarding
        debugPrint('🚪 [PROFILE_GATE] No profile exists, creating minimal and going to Onboarding');
        await _createMinimalProfile(uid);
        // CRÍTICO: Conectar ProfileRepository para que el realtime listener
        // y profileNotifier funcionen cuando el onboarding se complete
        await _connectRepositoriesForOnboarding(uid);
        if (mounted) setState(() => _status = _ProfileGateStatus.needsOnboarding);
        return;
      }
      
      // 4. Verificar si onboarding está completo
      if (!profile.onboardingCompleted || profile.selectedGiants.isEmpty) {
        debugPrint('🚪 [PROFILE_GATE] Onboarding incomplete (completed=${profile.onboardingCompleted}, giants=${profile.selectedGiants.length})');
        // CRÍTICO: Conectar ProfileRepository para que el realtime listener
        // y profileNotifier funcionen cuando el onboarding se complete
        await _connectRepositoriesForOnboarding(uid);
        if (mounted) setState(() => _status = _ProfileGateStatus.needsOnboarding);
        return;
      }
      
      // 5. Perfil válido => Home
      debugPrint('🚪 [PROFILE_GATE] Profile valid, going to Home');
      
      // Conectar repositorios para sincronizar datos
      await _bootstrapRepositories(uid);
      
      if (mounted) setState(() => _status = _ProfileGateStatus.ready);
      
    } catch (e) {
      debugPrint('🚪 [PROFILE_GATE] ❌ Error checking profile: $e');
      if (mounted) {
        setState(() {
          _status = _ProfileGateStatus.error;
          _errorMessage = 'No se pudo cargar tu perfil. Verifica tu conexión e intenta de nuevo.';
        });
      }
    }
  }
  
  /// Fetch perfil vía ProfileRepository (source of truth centralizado)
  Future<UserProfile?> _fetchProfileFromCloud(String uid) async {
    return ProfileRepository.I.fetchProfileFromServer(uid);
  }
  
  /// Crear perfil minimal vía ProfileRepository
  Future<void> _createMinimalProfile(String uid) async {
    final user = widget.user;
    await ProfileRepository.I.createMinimalProfile(
      uid: uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
    );
  }
  
  /// Conectar SOLO ProfileRepository para onboarding
  /// Esto inicia el realtime listener para que profileNotifier funcione
  /// cuando el usuario complete el onboarding  
  Future<void> _connectRepositoriesForOnboarding(String uid) async {
    try {
      debugPrint('🚪 [PROFILE_GATE] Connecting ProfileRepository for onboarding...');
      await ProfileRepository.I.connectUser(uid);
      // También reactivar AccountSessionManager y DataBootstrapper
      // (podrían estar "sordos" después de un deleteAccount)
      await AccountSessionManager.I.reactivateAuthListener();
      await DataBootstrapper.I.reactivateAuthListener();
      debugPrint('🚪 [PROFILE_GATE] ✅ ProfileRepository connected for onboarding');
    } catch (e) {
      debugPrint('🚪 [PROFILE_GATE] ⚠️ Connect for onboarding warning: $e');
    }
  }
  
  /// Bootstrap TODOS los repositorios después de confirmar perfil válido
  Future<void> _bootstrapRepositories(String uid) async {
    try {
      // El ProfileRepository conecta y sincroniza el perfil
      await ProfileRepository.I.connectUser(uid);
      // Reactivar listeners que podrían haberse detenido por deleteAccount
      await AccountSessionManager.I.reactivateAuthListener();
      await DataBootstrapper.I.reactivateAuthListener();
    } catch (e) {
      debugPrint('🚪 [PROFILE_GATE] Bootstrap warning: $e');
      // No fallar, el perfil ya está validado
    }
  }
  
  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _ProfileGateStatus.loading:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Cargando tu perfil...'),
                const SizedBox(height: 32),
                // Botón de emergencia para cerrar sesión si algo falla
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  child: const Text(
                    '¿Problemas? Cerrar sesión',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
        
      case _ProfileGateStatus.error:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo cargar tu perfil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Error de conexión',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _checkProfileFromCloud,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        
      case _ProfileGateStatus.needsOnboarding:
        // Safety check: si el perfil ya se completó mientras estábamos en onboarding
        // (ej: routes popearon pero el listener no disparó a tiempo)
        final currentProfile = ProfileRepository.I.currentProfile;
        if (currentProfile != null &&
            currentProfile.uid == widget.user.uid &&
            currentProfile.onboardingCompleted &&
            currentProfile.selectedGiants.isNotEmpty) {
          debugPrint('🚪 [PROFILE_GATE] Safety: profile already complete during needsOnboarding build');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _status == _ProfileGateStatus.needsOnboarding) {
              _bootstrapAndGoHome();
            }
          });
          // Mostrar loading mientras transicionamos (NO OnboardingWelcomeScreen)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Safety check 2: Verificar desde cloud en caso de que el cache esté desactualizado
        // Esto se ejecuta en background y si detecta que el onboarding está completo,
        // _onProfileChanged lo manejará automáticamente
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _status == _ProfileGateStatus.needsOnboarding) {
            _verifyStillNeedsOnboarding();
          }
        });
        
        return const OnboardingWelcomeScreen();
        
      case _ProfileGateStatus.ready:
        return _NavigationHandler(
          pendingRoute: widget.pendingRoute,
          onRouteConsumed: widget.onRouteConsumed,
          child: ErrorBoundary(
            child: HomeScreen(onThemeChanged: widget.onThemeChanged),
          ),
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NAVIGATION HANDLER - Maneja deep links desde widgets
// ═══════════════════════════════════════════════════════════════════════════

class _NavigationHandler extends StatefulWidget {
  final String? pendingRoute;
  final VoidCallback onRouteConsumed;
  final Widget child;
  
  const _NavigationHandler({
    required this.pendingRoute,
    required this.onRouteConsumed,
    required this.child,
  });

  @override
  State<_NavigationHandler> createState() => _NavigationHandlerState();
}

class _NavigationHandlerState extends State<_NavigationHandler> {
  @override
  void initState() {
    super.initState();
    // Navegar en el siguiente frame después de que el widget tree esté construido
    if (widget.pendingRoute != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePendingRoute();
      });
    }
  }
  
  void _handlePendingRoute() {
    if (!mounted || widget.pendingRoute == null) return;
    
    final route = widget.pendingRoute!;
    debugPrint('🔗 [NAVIGATION] Navegando a: $route');
    
    // Intentar navegar a la ruta
    try {
      Navigator.of(context).pushNamed(route).then((_) {
        // Marcar ruta como consumida después de navegar
        widget.onRouteConsumed();
      }).catchError((error) {
        debugPrint('⚠️ [NAVIGATION] Error navegando a $route: $error');
        // Marcar como consumida incluso si falla
        widget.onRouteConsumed();
      });
    } catch (e) {
      debugPrint('⚠️ [NAVIGATION] Excepción navegando: $e');
      widget.onRouteConsumed();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
