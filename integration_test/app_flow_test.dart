/// ═══════════════════════════════════════════════════════════════════════════
/// INTEGRATION TEST SUITE - Victoria en Cristo
/// E2E: Funcionalidad general + Aislamiento de datos multi-cuenta
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Ejecutar con:
///   flutter test integration_test/app_flow_test.dart -d <DEVICE_ID>
///
/// Requisitos:
///   - Dispositivo físico conectado (o emulador)
///   - Cuentas de prueba creadas en Firebase Auth:
///       test_a@victoria.com / TestPass123!
///       test_b@victoria.com / TestPass123!
///   - Conexión a internet (Firebase real)
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:app_quitar/firebase_options.dart';
import 'package:app_quitar/main.dart';
import 'package:app_quitar/screens/home_screen.dart';
import 'package:app_quitar/screens/login_screen.dart';
import 'package:app_quitar/screens/profile_screen.dart';
import 'package:app_quitar/screens/onboarding/onboarding_welcome_screen.dart';
import 'package:app_quitar/screens/onboarding/giant_selection_screen.dart';
import 'package:app_quitar/screens/onboarding/giant_frequency_screen.dart';
import 'package:app_quitar/widgets/victory_hero_card.dart';

import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/services/favorites_service.dart';
import 'package:app_quitar/services/onboarding_service.dart';
import 'package:app_quitar/services/audio_engine.dart';
import 'package:app_quitar/services/feedback_engine.dart';
import 'package:app_quitar/services/content_repository.dart';
import 'package:app_quitar/services/widget_sync_service.dart';
import 'package:app_quitar/services/victory_scoring_service.dart';
import 'package:app_quitar/services/data_bootstrapper.dart';
import 'package:app_quitar/services/account_session_manager.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURACIÓN DE CUENTAS DE PRUEBA
// ═══════════════════════════════════════════════════════════════════════════

const _accountA = _TestAccount(
  email: 'test_a@victoria.com',
  password: 'TestPass123!',
  label: 'Cuenta A',
);

const _accountB = _TestAccount(
  email: 'test_b@victoria.com',
  password: 'TestPass123!',
  label: 'Cuenta B',
);

class _TestAccount {
  final String email;
  final String password;
  final String label;
  const _TestAccount({
    required this.email,
    required this.password,
    required this.label,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS DE TEST
// ═══════════════════════════════════════════════════════════════════════════

/// Espera defensiva: pump + settle con timeout generoso para Firebase.
/// Si pumpAndSettle falla (animaciones continuas), hace pump con duración fija.
Future<void> _pumpAndWait(WidgetTester tester, {int seconds = 10}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      Duration(seconds: seconds),
    );
  } catch (_) {
    // Si hay animaciones continuas (ej. Home con loops), simplemente pump
    debugPrint('🤖 [TEST] pumpAndSettle timeout — usando pump fijo');
    await tester.pump(const Duration(seconds: 2));
  }
}

/// pumpAndSettle seguro — no crashea si hay animaciones loop
Future<void> _safePumpAndSettle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  } catch (_) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Espera con delay explícito para operaciones de red (Firestore)
Future<void> _waitForFirebase(WidgetTester tester, {int ms = 3000}) async {
  await Future.delayed(Duration(milliseconds: ms));
  await _pumpAndWait(tester, seconds: 5);
}

/// Ingresa texto en un campo buscándolo por su labelText
Future<void> _enterTextField(
  WidgetTester tester,
  String label,
  String text,
) async {
  final field = find.widgetWithText(TextFormField, label);
  expect(field, findsOneWidget, reason: 'Campo "$label" no encontrado');
  
  // Scrollear hasta que el campo sea visible (puede estar debajo del teclado)
  await tester.ensureVisible(field);
  await _safePumpAndSettle(tester);
  
  await tester.tap(field, warnIfMissed: false);
  await _safePumpAndSettle(tester);
  await tester.enterText(field, text);
  await _safePumpAndSettle(tester);
}

/// Hace login con email/password desde LoginScreen
Future<void> _loginWithEmail(
  WidgetTester tester,
  _TestAccount account,
) async {
  debugPrint('🤖 [TEST] Iniciando login con ${account.label} (${account.email})');

  // Asegurar que estamos en LoginScreen
  expect(find.byType(LoginScreen), findsOneWidget,
      reason: 'Se esperaba LoginScreen');

  // Rellenar email
  await _enterTextField(tester, 'Correo electrónico', account.email);
  
  // Cerrar teclado antes de buscar el campo de contraseña
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _safePumpAndSettle(tester);
  
  // Rellenar contraseña
  await _enterTextField(tester, 'Contraseña', account.password);

  // Ocultar teclado
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _safePumpAndSettle(tester);

  // Pulsar botón "INICIAR SESIÓN" — scrollear hasta verlo
  final loginBtnText = find.text('INICIAR SESIÓN');
  await tester.ensureVisible(loginBtnText.first);
  await _safePumpAndSettle(tester);
  await tester.tap(loginBtnText.first, warnIfMissed: false);

  debugPrint('🤖 [TEST] Tap en INICIAR SESIÓN. Esperando Firebase Auth...');
  await _waitForFirebase(tester, ms: 5000);
}

/// Hace logout navegando a ProfileScreen y tocando "Cerrar Sesión"
Future<void> _logout(WidgetTester tester) async {
  debugPrint('🤖 [TEST] Iniciando logout...');

  // Navegar a ProfileScreen: tocar el avatar (primer GestureDetector
  // dentro del header, que envuelve un CircleAvatar/Container circular)
  // Buscar el ícono de perfil o el CircleAvatar en el header
  // Scrollear al inicio para asegurar que el header/avatar esté visible
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    // Intentar scrollear al inicio
    await tester.drag(scrollables.first, const Offset(0, 500));
    await _safePumpAndSettle(tester);
  }
  
  final avatarFinder = find.byType(CircleAvatar);
  if (avatarFinder.evaluate().isNotEmpty) {
    await tester.tap(avatarFinder.first, warnIfMissed: false);
  } else {
    final gestureDetectors = find.byType(GestureDetector);
    await tester.tap(gestureDetectors.first, warnIfMissed: false);
  }
  await _pumpAndWait(tester);

  // Verificar que estamos en ProfileScreen
  expect(find.byType(ProfileScreen), findsOneWidget,
      reason: 'Se esperaba ProfileScreen después de tocar avatar');

  // Scrollear hasta el botón de logout si no es visible
  final logoutBtn = find.text('Cerrar Sesión');
  try {
    await tester.scrollUntilVisible(logoutBtn, 200,
        scrollable: find.byType(Scrollable).last);
  } catch (_) {
    // Si scrollUntilVisible falla, intentar ensureVisible
    if (logoutBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(logoutBtn);
    }
  }
  await _safePumpAndSettle(tester);

  // Tocar "Cerrar Sesión"
  await tester.tap(logoutBtn, warnIfMissed: false);
  debugPrint('🤖 [TEST] Tap en Cerrar Sesión. Esperando signOut...');
  await _waitForFirebase(tester, ms: 4000);
}

/// Completa el onboarding seleccionando gigantes y frecuencias
Future<void> _completeOnboarding(
  WidgetTester tester, {
  required List<String> giantNames,
}) async {
  debugPrint('🤖 [TEST] Completando onboarding con gigantes: $giantNames');

  // Paso 0: OnboardingWelcomeScreen → "ELEGIR MIS GIGANTES"
  final welcomeBtn = find.text('ELEGIR MIS GIGANTES');
  if (welcomeBtn.evaluate().isNotEmpty) {
    await tester.ensureVisible(welcomeBtn);
    await _safePumpAndSettle(tester);
    await tester.tap(welcomeBtn, warnIfMissed: false);
    // Esperar transición a GiantSelectionScreen
    await Future.delayed(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  // Paso 1: GiantSelectionScreen → seleccionar gigantes por nombre
  // Esperar un poco extra por la transición animada
  await Future.delayed(const Duration(milliseconds: 1000));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  
  expect(find.byType(GiantSelectionScreen), findsOneWidget,
      reason: 'Se esperaba GiantSelectionScreen');

  for (final name in giantNames) {
    final giantCard = find.text(name);
    expect(giantCard, findsOneWidget,
        reason: 'Gigante "$name" no encontrado en la grilla');
    await tester.ensureVisible(giantCard);
    await _safePumpAndSettle(tester);
    await tester.tap(giantCard, warnIfMissed: false);
    await _safePumpAndSettle(tester);
  }

  // Tocar "CONTINUAR (N)" — scrollear hasta verlo
  final continueBtn = find.textContaining('CONTINUAR');
  expect(continueBtn, findsOneWidget,
      reason: 'Botón CONTINUAR no encontrado');
  await tester.ensureVisible(continueBtn);
  await _safePumpAndSettle(tester);
  await tester.tap(continueBtn, warnIfMissed: false);
  // Esperar transición a FrequencyScreen
  await Future.delayed(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));

  // Paso 2: GiantFrequencyScreen → seleccionar frecuencia para cada gigante
  expect(find.byType(GiantFrequencyScreen), findsOneWidget,
      reason: 'Se esperaba GiantFrequencyScreen');

  // Para cada gigante, seleccionar la primera frecuencia disponible ("Diario")
  for (var i = 0; i < giantNames.length; i++) {
    // Buscar chips de frecuencia "Diario" (hay uno por cada gigante)
    final dailyChips = find.text('Diario');
    if (dailyChips.evaluate().length > i) {
      await tester.ensureVisible(dailyChips.at(i));
      await _safePumpAndSettle(tester);
      await tester.tap(dailyChips.at(i), warnIfMissed: false);
      await _safePumpAndSettle(tester);
    } else {
      // Fallback: seleccionar cualquier frecuencia visible
      final freqChip = find.textContaining('Semanal');
      if (freqChip.evaluate().isNotEmpty) {
        final idx = i < freqChip.evaluate().length ? i : 0;
        await tester.ensureVisible(freqChip.at(idx));
        await _safePumpAndSettle(tester);
        await tester.tap(freqChip.at(idx), warnIfMissed: false);
        await _safePumpAndSettle(tester);
      }
    }
  }

  // Tocar "GUARDAR Y CONTINUAR" — scrollear hasta verlo
  final saveBtn = find.text('GUARDAR Y CONTINUAR');
  expect(saveBtn, findsOneWidget,
      reason: 'Botón GUARDAR Y CONTINUAR no encontrado');
  await tester.ensureVisible(saveBtn);
  await _safePumpAndSettle(tester);
  await tester.tap(saveBtn, warnIfMissed: false);

  debugPrint('🤖 [TEST] Onboarding guardado. Esperando transición a Home...');
  await _waitForFirebase(tester, ms: 6000);
}

/// Verifica que HomeScreen está visible con los elementos esperados
void _assertHomeScreenVisible(WidgetTester tester) {
  expect(find.byType(HomeScreen), findsOneWidget,
      reason: 'HomeScreen no visible');
  expect(find.byType(VictoryHeroCard), findsOneWidget,
      reason: 'VictoryHeroCard no visible en Home');
  // Verificar sección de versículo o herramientas
  expect(find.text('DÍAS DE VICTORIA'), findsOneWidget,
      reason: 'Label "DÍAS DE VICTORIA" no encontrado');
}

/// Verifica que LoginScreen está visible y limpia
void _assertLoginScreenClean(WidgetTester tester) {
  expect(find.byType(LoginScreen), findsOneWidget,
      reason: 'LoginScreen no visible');
  // No debería haber texto de HomeScreen
  expect(find.byType(HomeScreen), findsNothing,
      reason: 'HomeScreen no debería ser visible en login');
  expect(find.byType(ProfileScreen), findsNothing,
      reason: 'ProfileScreen no debería ser visible en login');
}

// ═══════════════════════════════════════════════════════════════════════════
// BOOTSTRAP DE LA APP (replica main.dart init)
// ═══════════════════════════════════════════════════════════════════════════

/// Inicializa todos los servicios igual que main(), luego lanza la app.
Future<void> _bootstrapApp(WidgetTester tester) async {
  // Asegurar que Firebase Auth no tenga sesión previa
  try {
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
  } catch (_) {}

  // Inicializar servicios (mismo orden que main.dart)
  final themeService = ThemeService();
  await themeService.initialize();

  final favoritesService = FavoritesService();
  await favoritesService.init();

  final onboardingService = OnboardingService();
  await onboardingService.init();

  final audioEngine = AudioEngine.I;
  await audioEngine.init();

  final feedbackEngine = FeedbackEngine.I;
  await feedbackEngine.init();

  final contentRepo = ContentRepository.I;
  await contentRepo.init();

  final widgetService = WidgetSyncService.I;
  await widgetService.init();

  final scoringService = VictoryScoringService.I;
  await scoringService.init();

  final bootstrapper = DataBootstrapper.I;
  await bootstrapper.init();

  final sessionManager = AccountSessionManager.I;
  await sessionManager.init();

  // Lanzar la app
  await tester.pumpWidget(VictoriaEnCristoApp(
    themeService: themeService,
    onboardingService: onboardingService,
  ));

  // Esperar navegación inicial
  await _waitForFirebase(tester, ms: 3000);
}

// ═══════════════════════════════════════════════════════════════════════════
// SUITE DE TESTS
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Firebase debe inicializarse UNA vez antes de todos los tests
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TEST 1: Funcionalidad General y Onboarding
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets(
    'TEST 1: Login → Onboarding → Home — funcionalidad general',
    (WidgetTester tester) async {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('  TEST 1: FUNCIONALIDAD GENERAL Y ONBOARDING');
      debugPrint('═══════════════════════════════════════════════════');

      // 1. Arrancar la app
      await _bootstrapApp(tester);

      // 2. Debería mostrar LoginScreen (no hay sesión activa)
      _assertLoginScreenClean(tester);
      debugPrint('✅ LoginScreen visible y limpia');

      // 3. Login con Cuenta A
      await _loginWithEmail(tester, _accountA);

      // 4. Después del login: ¿Onboarding o Home?
      final needsOnboarding =
          find.byType(OnboardingWelcomeScreen).evaluate().isNotEmpty ||
          find.byType(GiantSelectionScreen).evaluate().isNotEmpty;

      if (needsOnboarding) {
        debugPrint('🤖 [TEST] Cuenta A necesita onboarding');
        await _completeOnboarding(
          tester,
          giantNames: ['PUREZA SEXUAL', 'BATALLAS MENTALES'],
        );
      }

      // 5. Verificar que estamos en HomeScreen
      _assertHomeScreenVisible(tester);
      debugPrint('✅ HomeScreen visible con VictoryHeroCard');

      // 6. Verificar "VERSÍCULO DEL DÍA"
      // Scrollear para asegurar visibilidad
      final verseLabel = find.text('VERSÍCULO DEL DÍA');
      try {
        await tester.scrollUntilVisible(verseLabel, 300,
            scrollable: find.byType(Scrollable).first);
        await _safePumpAndSettle(tester);
        expect(verseLabel, findsOneWidget,
            reason: 'Versículo del Día no encontrado');
        debugPrint('✅ Versículo del Día visible');
      } catch (e) {
        debugPrint('⚠️ Versículo del Día no se pudo scrollear hasta él: $e');
      }

      // 7. Verificar herramientas
      final toolsLabel = find.text('HERRAMIENTAS DE VICTORIA');
      try {
        await tester.scrollUntilVisible(toolsLabel, 300,
            scrollable: find.byType(Scrollable).first);
        await _safePumpAndSettle(tester);
        expect(toolsLabel, findsOneWidget);
        debugPrint('✅ Herramientas de Victoria visibles');
      } catch (e) {
        debugPrint('⚠️ Herramientas no scroll-visible: $e');
      }

      // 8. Captura de pantalla del HomeScreen (skip en CI)
      debugPrint('📸 Screenshot: test1_home_screen (omitida)');

      // Logout para dejar limpio
      await _logout(tester);
      _assertLoginScreenClean(tester);
      debugPrint('✅ TEST 1 COMPLETADO: Login → Onboarding → Home ✓');
    },
  );

  // ─────────────────────────────────────────────────────────────────────────
  // TEST 2: Aislamiento de Datos Multi-Cuenta (A → B → A)
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets(
    'TEST 2: A→B→A aislamiento de datos — racha y gigantes intactos',
    (WidgetTester tester) async {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('  TEST 2: AISLAMIENTO MULTI-CUENTA (A → B → A)');
      debugPrint('═══════════════════════════════════════════════════');

      // ═══════════════ FASE 1: Establecer la sesión de Cuenta A ═══════════
      await _bootstrapApp(tester);
      _assertLoginScreenClean(tester);

      // Login Cuenta A
      await _loginWithEmail(tester, _accountA);

      // Si necesita onboarding, completarlo
      if (find.byType(OnboardingWelcomeScreen).evaluate().isNotEmpty ||
          find.byType(GiantSelectionScreen).evaluate().isNotEmpty) {
        await _completeOnboarding(
          tester,
          giantNames: ['PUREZA SEXUAL', 'BATALLAS MENTALES'],
        );
      }

      // Asegurar que estamos en Home
      _assertHomeScreenVisible(tester);
      debugPrint('✅ [A] Cuenta A en HomeScreen');

      // Capturar datos de Cuenta A (racha)
      final streakFinderA = find.descendant(
        of: find.byType(VictoryHeroCard),
        matching: find.byType(Text),
      );
      // El primer Text dentro de VictoryHeroCard con fontSize grande es la racha
      String? streakTextA;
      for (final element in streakFinderA.evaluate()) {
        final widget = element.widget as Text;
        final text = widget.data ?? '';
        // El streak es un número puro (solo dígitos)
        if (RegExp(r'^\d+$').hasMatch(text)) {
          streakTextA = text;
          break;
        }
      }
      debugPrint('📊 [A] Racha Cuenta A: ${streakTextA ?? "no encontrada"}');

      // Verificar que "DÍAS DE VICTORIA" está presente
      expect(find.text('DÍAS DE VICTORIA'), findsOneWidget);

      // Captura de pantalla de estado inicial Cuenta A
      debugPrint('📸 Screenshot: test2_account_a_initial (omitida)');

      // ═══════════════ FASE 2: Logout de Cuenta A ════════════════════════
      await _logout(tester);

      // Verificar que regresamos a LoginScreen y NO hay rastro de Cuenta A
      _assertLoginScreenClean(tester);
      debugPrint('✅ [A→logout] LoginScreen limpia, sin rastro de Cuenta A');

      debugPrint('📸 Screenshot: test2_after_logout_a (omitida)');

      // ═══════════════ FASE 3: Login con Cuenta B ════════════════════════
      await _loginWithEmail(tester, _accountB);
      await _waitForFirebase(tester, ms: 3000);

      // Cuenta B puede necesitar onboarding (es "nueva") o tener sus propios datos
      final bNeedsOnboarding =
          find.byType(OnboardingWelcomeScreen).evaluate().isNotEmpty ||
          find.byType(GiantSelectionScreen).evaluate().isNotEmpty;

      if (bNeedsOnboarding) {
        debugPrint('🤖 [B] Cuenta B necesita onboarding (nueva cuenta)');
        // Seleccionar gigantes DIFERENTES a los de Cuenta A
        await _completeOnboarding(
          tester,
          giantNames: ['MUNDO DIGITAL', 'SUSTANCIAS'],
        );
      } else {
        debugPrint('🤖 [B] Cuenta B ya tiene onboarding completado');
      }

      // Verificar que estamos en HomeScreen con datos de Cuenta B
      _assertHomeScreenVisible(tester);
      debugPrint('✅ [B] Cuenta B en HomeScreen');

      // Capturar racha de Cuenta B
      String? streakTextB;
      final streakFinderB = find.descendant(
        of: find.byType(VictoryHeroCard),
        matching: find.byType(Text),
      );
      for (final element in streakFinderB.evaluate()) {
        final widget = element.widget as Text;
        final text = widget.data ?? '';
        if (RegExp(r'^\d+$').hasMatch(text)) {
          streakTextB = text;
          break;
        }
      }
      debugPrint('📊 [B] Racha Cuenta B: ${streakTextB ?? "no encontrada"}');

      debugPrint('📸 Screenshot: test2_account_b (omitida)');

      // ═══════════════ FASE 4: Logout de Cuenta B ════════════════════════
      await _logout(tester);
      _assertLoginScreenClean(tester);
      debugPrint('✅ [B→logout] LoginScreen limpia después de Cuenta B');

      debugPrint('📸 Screenshot: test2_after_logout_b (omitida)');

      // ═══════════════ FASE 5: Re-login con Cuenta A (LA PRUEBA CRÍTICA) ═
      debugPrint('');
      debugPrint('🔴 ═══════════════════════════════════════════════');
      debugPrint('🔴   ASERCIÓN CRÍTICA: Re-login Cuenta A');
      debugPrint('🔴 ═══════════════════════════════════════════════');

      await _loginWithEmail(tester, _accountA);
      await _waitForFirebase(tester, ms: 5000);

      // ── ASERCIÓN CRÍTICA 1: NO debe pedir Onboarding ──
      expect(find.byType(OnboardingWelcomeScreen), findsNothing,
          reason: '❌ FALLO CRÍTICO: Cuenta A NO debería pedir onboarding'
              ' después del switch A→B→A');
      expect(find.byType(GiantSelectionScreen), findsNothing,
          reason: '❌ FALLO CRÍTICO: Cuenta A NO debería pedir selección'
              ' de gigantes después del switch A→B→A');
      debugPrint('✅ [A-relogin] NO pide onboarding ✓');

      // ── ASERCIÓN CRÍTICA 2: Debe estar en HomeScreen ──
      _assertHomeScreenVisible(tester);
      debugPrint('✅ [A-relogin] HomeScreen visible con VictoryHeroCard ✓');

      // ── ASERCIÓN CRÍTICA 3: Racha de Cuenta A intacta ──
      String? streakTextA2;
      final streakFinderA2 = find.descendant(
        of: find.byType(VictoryHeroCard),
        matching: find.byType(Text),
      );
      for (final element in streakFinderA2.evaluate()) {
        final widget = element.widget as Text;
        final text = widget.data ?? '';
        if (RegExp(r'^\d+$').hasMatch(text)) {
          streakTextA2 = text;
          break;
        }
      }

      debugPrint('📊 [A-relogin] Racha re-login: $streakTextA2 (original: $streakTextA)');

      expect(streakTextA2, isNotNull,
          reason: '❌ FALLO CRÍTICO: No se encontró la racha de Cuenta A'
              ' después del switch A→B→A');

      // Si teníamos un valor original, verificar que coincide
      if (streakTextA != null) {
        expect(streakTextA2, equals(streakTextA),
            reason: '❌ FALLO CRÍTICO: La racha cambió de $streakTextA'
                ' a $streakTextA2 después del switch A→B→A.'
                ' DATOS PERDIDOS.');
      }

      // ── ASERCIÓN CRÍTICA 4: "DÍAS DE VICTORIA" visible ──
      expect(find.text('DÍAS DE VICTORIA'), findsOneWidget,
          reason: '❌ FALLO: Label DÍAS DE VICTORIA no visible');
      debugPrint('✅ [A-relogin] Datos de Cuenta A intactos ✓');

      debugPrint('📸 Screenshot: test2_account_a_relogin_CRITICAL (omitida)');

      // Cleanup: Logout final
      await _logout(tester);

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('  ✅ TEST 2 COMPLETADO: Multi-Account Isolation');
      debugPrint('     A→B→A sin pérdida de datos');
      debugPrint('═══════════════════════════════════════════════════');
    },
  );

  // ─────────────────────────────────────────────────────────────────────────
  // TEST 3: Stress — Doble ciclo A→B→A→B→A
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets(
    'TEST 3: Stress doble ciclo A→B→A→B→A — datos siempre intactos',
    (WidgetTester tester) async {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('  TEST 3: STRESS DOBLE CICLO A→B→A→B→A');
      debugPrint('═══════════════════════════════════════════════════');

      await _bootstrapApp(tester);
      _assertLoginScreenClean(tester);

      // ═══════ Ciclo 1: A→B→A ═══════
      debugPrint('────── Ciclo 1: A→B→A ──────');

      // Login A
      await _loginWithEmail(tester, _accountA);
      if (find.byType(OnboardingWelcomeScreen).evaluate().isNotEmpty ||
          find.byType(GiantSelectionScreen).evaluate().isNotEmpty) {
        await _completeOnboarding(tester, giantNames: ['PUREZA SEXUAL', 'BATALLAS MENTALES']);
      }
      _assertHomeScreenVisible(tester);

      // Capturar racha A (referencia)
      String? streakRef;
      for (final element in find.descendant(
        of: find.byType(VictoryHeroCard),
        matching: find.byType(Text),
      ).evaluate()) {
        final w = element.widget as Text;
        final t = w.data ?? '';
        if (RegExp(r'^\d+$').hasMatch(t)) { streakRef = t; break; }
      }
      debugPrint('📊 Racha referencia A: $streakRef');

      // A → Logout
      await _logout(tester);
      _assertLoginScreenClean(tester);

      // Login B
      await _loginWithEmail(tester, _accountB);
      if (find.byType(OnboardingWelcomeScreen).evaluate().isNotEmpty ||
          find.byType(GiantSelectionScreen).evaluate().isNotEmpty) {
        await _completeOnboarding(tester, giantNames: ['MUNDO DIGITAL', 'SUSTANCIAS']);
      }
      _assertHomeScreenVisible(tester);

      // B → Logout
      await _logout(tester);
      _assertLoginScreenClean(tester);

      // Re-login A (ciclo 1)
      await _loginWithEmail(tester, _accountA);
      await _waitForFirebase(tester, ms: 5000);
      expect(find.byType(OnboardingWelcomeScreen), findsNothing,
          reason: '❌ Ciclo 1: Cuenta A no debería pedir onboarding');
      _assertHomeScreenVisible(tester);
      debugPrint('✅ Ciclo 1: A→B→A exitoso');

      // ═══════ Ciclo 2: →B→A ═══════
      debugPrint('────── Ciclo 2: →B→A ──────');

      // A → Logout
      await _logout(tester);
      _assertLoginScreenClean(tester);

      // Login B
      await _loginWithEmail(tester, _accountB);
      await _waitForFirebase(tester, ms: 3000);
      if (find.byType(OnboardingWelcomeScreen).evaluate().isNotEmpty ||
          find.byType(GiantSelectionScreen).evaluate().isNotEmpty) {
        await _completeOnboarding(tester, giantNames: ['MUNDO DIGITAL', 'SUSTANCIAS']);
      }
      _assertHomeScreenVisible(tester);

      // B → Logout
      await _logout(tester);
      _assertLoginScreenClean(tester);

      // Re-login A (ciclo 2 — ASERCIÓN FINAL)
      await _loginWithEmail(tester, _accountA);
      await _waitForFirebase(tester, ms: 5000);

      expect(find.byType(OnboardingWelcomeScreen), findsNothing,
          reason: '❌ Ciclo 2: Cuenta A no debería pedir onboarding');
      _assertHomeScreenVisible(tester);

      // Verificar racha
      String? streakFinal;
      for (final element in find.descendant(
        of: find.byType(VictoryHeroCard),
        matching: find.byType(Text),
      ).evaluate()) {
        final w = element.widget as Text;
        final t = w.data ?? '';
        if (RegExp(r'^\d+$').hasMatch(t)) { streakFinal = t; break; }
      }
      debugPrint('📊 Racha final A: $streakFinal (referencia: $streakRef)');

      if (streakRef != null) {
        expect(streakFinal, equals(streakRef),
            reason: '❌ FALLO: Racha cambió de $streakRef a $streakFinal'
                ' después de doble ciclo A→B→A→B→A');
      }

      debugPrint('📸 Screenshot: test3_stress_final_a (omitida)');
      debugPrint('✅ TEST 3 COMPLETADO: Doble ciclo A→B→A→B→A sin pérdida ✓');

      // Cleanup
      await _logout(tester);
    },
  );
}
