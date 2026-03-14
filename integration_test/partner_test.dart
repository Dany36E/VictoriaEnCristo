/// ═══════════════════════════════════════════════════════════════════════════
/// BATTLE PARTNER INTEGRATION TEST - Compañero de Batalla E2E
///
/// Flujo de 2 usuarios en un solo testWidgets con switch de sesión:
///   PASO 0: Cleanup datos previos
///   PASO 1: User A — login, abrir Compañero, ver estado vacío + código
///   PASO 2: Switch a User B — buscar código → preview → enviar solicitud
///   PASO 3: Switch a User A — ver invitación pendiente → aceptar
///   PASO 4: User A — abrir sticker picker, verificar 8 opciones, enviar 1
///   PASO 5: Switch a User B — ver compañero activo + mensaje recibido
///   PASO 6: User B — desvincular compañero
///   PASO 7: User B — validaciones de error en AddPartnerScreen
///   PASO 8: Cleanup final
///
/// Ejecutar con:
///   flutter test integration_test/partner_test.dart -d DEVICE_ID
///
/// Usa test_a@victoria.com y test_b@victoria.com (creados por setup_test_accounts).
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_quitar/firebase_options.dart';
import 'package:app_quitar/main.dart';
import 'package:app_quitar/screens/home_screen.dart';
import 'package:app_quitar/screens/login_screen.dart';
import 'package:app_quitar/screens/onboarding/onboarding_welcome_screen.dart';
import 'package:app_quitar/screens/onboarding/giant_selection_screen.dart';
import 'package:app_quitar/screens/onboarding/giant_frequency_screen.dart';
import 'package:app_quitar/screens/battle_partner/battle_partner_screen.dart';
import 'package:app_quitar/screens/battle_partner/add_partner_screen.dart';
import 'package:app_quitar/widgets/battle_partner_card.dart';
import 'package:app_quitar/widgets/sticker_picker_sheet.dart';

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
import 'package:app_quitar/services/battle_partner_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════════════════

const _emailA = 'test_a@victoria.com';
const _emailB = 'test_b@victoria.com';
const _password = 'TestPass123!';

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _pumpAndWait(WidgetTester tester, {int seconds = 10}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      Duration(seconds: seconds),
    );
  } catch (_) {
    debugPrint('🤖 pumpAndSettle timeout — pump fijo');
    await tester.pump(const Duration(seconds: 2));
  }
}

Future<void> _safePump(WidgetTester tester) async {
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

Future<void> _waitForFirebase(WidgetTester tester, {int ms = 3000}) async {
  await Future.delayed(Duration(milliseconds: ms));
  await _pumpAndWait(tester, seconds: 5);
}

Future<void> _enterTextField(
  WidgetTester tester,
  String label,
  String text,
) async {
  final field = find.widgetWithText(TextFormField, label);
  expect(field, findsOneWidget, reason: 'Campo "$label" no encontrado');
  await tester.ensureVisible(field);
  await _safePump(tester);
  await tester.tap(field, warnIfMissed: false);
  await _safePump(tester);
  await tester.enterText(field, text);
  await _safePump(tester);
}

Future<bool> _scrollUntilFound(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
  double delta = -250,
  int maxScrolls = 15,
}) async {
  for (var i = 0; i < maxScrolls; i++) {
    if (target.evaluate().isNotEmpty) return true;
    final scr = scrollable ?? find.byType(Scrollable).first;
    if (scr.evaluate().isEmpty) return false;
    await tester.drag(scr, Offset(0, delta));
    await _safePump(tester);
  }
  return target.evaluate().isNotEmpty;
}

// ═══════════════════════════════════════════════════════════════════════════
// BOOTSTRAP / LOGIN
// ═══════════════════════════════════════════════════════════════════════════

late ThemeService _ts;
late OnboardingService _os;
bool _servicesInitialized = false;

Future<void> _initServices() async {
  if (_servicesInitialized) return;

  _ts = ThemeService();
  await _ts.initialize();
  final fav = FavoritesService();
  await fav.init();
  _os = OnboardingService();
  await _os.init();
  await AudioEngine.I.init();
  await FeedbackEngine.I.init();
  await ContentRepository.I.init();
  await WidgetSyncService.I.init();
  await VictoryScoringService.I.init();
  await DataBootstrapper.I.init();
  await AccountSessionManager.I.init();

  _servicesInitialized = true;
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(VictoriaEnCristoApp(
    themeService: _ts,
    onboardingService: _os,
  ));
  await _waitForFirebase(tester, ms: 3000);
}

/// Sign out current user, stop partner service, let auth stream route to Login.
Future<void> _switchUser(WidgetTester tester) async {
  debugPrint('🤖 Switching user...');

  // 1. Pop all pushed routes to get back to root (HomeScreen)
  //    This ensures the StreamBuilder's rebuild to LoginScreen is visible.
  final navFinder = find.byType(Navigator);
  if (navFinder.evaluate().isNotEmpty) {
    final navState = tester.state<NavigatorState>(navFinder.first);
    navState.popUntil((route) => route.isFirst);
    await _safePump(tester);
    debugPrint('🤖 Routes popped to root');
  }

  // 2. Stop partner service
  try {
    BattlePartnerService.I.stop();
  } catch (_) {}

  // 3. Sign out
  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {}

  // 4. Verify sign out
  for (var i = 0; i < 10; i++) {
    if (FirebaseAuth.instance.currentUser == null) break;
    await Future.delayed(const Duration(milliseconds: 500));
  }
  debugPrint('🤖 currentUser after signOut: ${FirebaseAuth.instance.currentUser}');

  // 5. Let the StreamBuilder react to the auth change → LoginScreen
  await Future.delayed(const Duration(seconds: 1));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byType(LoginScreen).evaluate().isNotEmpty) {
      debugPrint('🤖 LoginScreen appeared after ${(i + 1) * 500}ms');
      break;
    }
  }
  await _safePump(tester);
}

Future<void> _login(WidgetTester tester, String email) async {
  debugPrint('🤖 Login: $email');

  for (var i = 0; i < 20; i++) {
    if (find.byType(LoginScreen).evaluate().isNotEmpty) break;
    await tester.pump(const Duration(seconds: 1));
  }
  expect(find.byType(LoginScreen), findsOneWidget,
      reason: 'LoginScreen no encontrado');

  await _enterTextField(tester, 'Correo electrónico', email);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _safePump(tester);

  await _enterTextField(tester, 'Contraseña', _password);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _safePump(tester);

  final loginBtn = find.text('INICIAR SESIÓN');
  await tester.ensureVisible(loginBtn.first);
  await _safePump(tester);
  await tester.tap(loginBtn.first, warnIfMissed: false);
  await _waitForFirebase(tester, ms: 5000);
}

Future<void> _skipOnboardingIfNeeded(WidgetTester tester) async {
  if (find.byType(OnboardingWelcomeScreen).evaluate().isNotEmpty ||
      find.byType(GiantSelectionScreen).evaluate().isNotEmpty) {
    debugPrint('🤖 Onboarding detectado, saltando...');
    final welcomeBtn = find.text('ELEGIR MIS GIGANTES');
    if (welcomeBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(welcomeBtn);
      await _safePump(tester);
      await tester.tap(welcomeBtn, warnIfMissed: false);
      await Future.delayed(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await Future.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));

    if (find.byType(GiantSelectionScreen).evaluate().isNotEmpty) {
      final cards = find.byType(GestureDetector);
      if (cards.evaluate().length >= 2) {
        await tester.tap(cards.at(1), warnIfMissed: false);
        await _safePump(tester);
      }
      final cont = find.text('CONTINUAR');
      if (cont.evaluate().isNotEmpty) {
        await tester.ensureVisible(cont);
        await _safePump(tester);
        await tester.tap(cont, warnIfMissed: false);
        await _waitForFirebase(tester, ms: 2000);
      }
    }
    if (find.byType(GiantFrequencyScreen).evaluate().isNotEmpty) {
      final emp = find.text('EMPEZAR');
      if (emp.evaluate().isNotEmpty) {
        await tester.ensureVisible(emp);
        await _safePump(tester);
        await tester.tap(emp, warnIfMissed: false);
        await _waitForFirebase(tester, ms: 3000);
      }
    }
  }

  for (var i = 0; i < 15; i++) {
    if (find.byType(HomeScreen).evaluate().isNotEmpty) break;
    await tester.pump(const Duration(seconds: 1));
  }
  expect(find.byType(HomeScreen), findsOneWidget,
      reason: 'HomeScreen no apareció');
}

/// Navigate Home → BattlePartnerScreen
Future<void> _goToPartnerScreen(WidgetTester tester) async {
  debugPrint('🤖 Navegando a Compañero de Batalla...');

  // First ensure we're on HomeScreen
  for (var i = 0; i < 10; i++) {
    if (find.byType(HomeScreen).evaluate().isNotEmpty) break;
    await tester.pump(const Duration(seconds: 1));
  }
  expect(find.byType(HomeScreen), findsOneWidget,
      reason: 'HomeScreen no visible antes de navegar');

  // Scroll to find "Compañero" button
  final btn = find.text('Compañero');
  final found = await _scrollUntilFound(tester, btn);
  expect(found, isTrue, reason: 'Botón "Compañero" no encontrado en Home');

  await tester.ensureVisible(btn);
  await _safePump(tester);
  await tester.tap(btn, warnIfMissed: false);
  debugPrint('🤖 Tap en "Compañero" realizado');

  // Wait for route to push
  await _waitForFirebase(tester, ms: 4000);

  // Check if BattlePartnerScreen appeared
  for (var i = 0; i < 5; i++) {
    if (find.byType(BattlePartnerScreen).evaluate().isNotEmpty) break;
    await tester.pump(const Duration(seconds: 1));
  }
  expect(find.byType(BattlePartnerScreen), findsOneWidget,
      reason: 'BattlePartnerScreen no abrió');
}

// ═══════════════════════════════════════════════════════════════════════════
// CLEANUP
// ═══════════════════════════════════════════════════════════════════════════

/// Delete partner data for each user. Must sign in as each user individually
/// so Firestore rules (isOwner) allow the deletes.
Future<void> _cleanupPartnerData() async {
  final db = FirebaseFirestore.instance;

  // Helper: sign in as user, delete their partner-related data, then sign out.
  Future<String?> cleanupForUser(String email) async {
    String? uid;
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: _password);
      uid = cred.user?.uid;
      if (uid == null) return null;

      // Delete battlePartners docs
      final partners = await db
          .collection('users').doc(uid).collection('battlePartners').get();
      for (final doc in partners.docs) {
        await doc.reference.delete();
      }

      // Delete partnerInvites docs
      final invites = await db
          .collection('users').doc(uid).collection('partnerInvites').get();
      for (final doc in invites.docs) {
        await doc.reference.delete();
      }

      // Delete battleMessages docs
      final messages = await db
          .collection('users').doc(uid).collection('battleMessages').get();
      for (final doc in messages.docs) {
        await doc.reference.delete();
      }

      debugPrint('🤖 Cleanup $email (uid=$uid): '
          '${partners.docs.length} partners, '
          '${invites.docs.length} invites, '
          '${messages.docs.length} messages deleted');

      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('🤖 Cleanup error for $email: $e');
      try { await FirebaseAuth.instance.signOut(); } catch (_) {}
    }
    return uid;
  }

  await cleanupForUser(_emailA);
  await cleanupForUser(_emailB);

  debugPrint('🤖 Cleanup completado');
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN TEST
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await _cleanupPartnerData();
  });

  testWidgets(
    'PARTNER TEST: Código → Solicitud → Aceptar → Sticker → Stats → Desvincular',
    (WidgetTester tester) async {
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('  PARTNER TEST: FLUJO COMPLETO COMPAÑERO DE BATALLA');
      debugPrint('═══════════════════════════════════════════════════');

      final db = FirebaseFirestore.instance;
      await _initServices();

      // ════════════════════════════════════════════════════════════════════
      // PASO 1: User A — login, abrir Compañero, ver estado vacío + código
      // ════════════════════════════════════════════════════════════════════
      debugPrint('\n🤖 ═══ PASO 1: User A — estado vacío + código ═══');

      await _pumpApp(tester);
      await _login(tester, _emailA);
      await _skipOnboardingIfNeeded(tester);

      final userAUid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('🤖 User A uid: $userAUid');

      await _goToPartnerScreen(tester);

      // Verificar estado vacío
      expect(find.textContaining('Compañeros de batalla'), findsOneWidget,
          reason: 'Sección compañeros no visible');
      expect(find.textContaining('Ningún compañero aún'), findsOneWidget,
          reason: 'Estado vacío no visible');

      // Scroll to invite code section
      final codeSectionFinder = find.text('Tu código de invitación');
      await _scrollUntilFound(tester, codeSectionFinder);

      // Wait for code to load
      await Future.delayed(const Duration(seconds: 3));
      await _safePump(tester);

      // Read invite code from Firestore
      final userADoc = await db.collection('users').doc(userAUid).get();
      final userAInviteCode = userADoc.data()?['inviteCode'] as String?;
      debugPrint('🤖 User A invite code: $userAInviteCode');
      expect(userAInviteCode, isNotNull, reason: 'User A no tiene inviteCode');
      expect(userAInviteCode!.length, 8);

      // Verify code in UI
      expect(find.text(userAInviteCode), findsOneWidget,
          reason: 'inviteCode no visible en pantalla');

      // Verify add-partner button (may appear in AppBar + empty state)
      expect(find.byIcon(Icons.person_add_alt_1), findsWidgets,
          reason: 'Botón agregar compañero no visible');

      debugPrint('✅ PASO 1 OK — código: $userAInviteCode');

      // ════════════════════════════════════════════════════════════════════
      // PASO 2: Switch → User B — buscar código, preview, enviar solicitud
      // ════════════════════════════════════════════════════════════════════
      debugPrint('\n🤖 ═══ PASO 2: User B — buscar código + enviar solicitud ═══');

      await _switchUser(tester);
      await _login(tester, _emailB);
      await _skipOnboardingIfNeeded(tester);

      await _goToPartnerScreen(tester);

      // Empty state for B
      expect(find.textContaining('Ningún compañero aún'), findsOneWidget,
          reason: 'User B debería ver estado vacío');

      // Open AddPartnerScreen (use .first — AppBar icon)
      await tester.tap(find.byIcon(Icons.person_add_alt_1).first, warnIfMissed: false);
      await _pumpAndWait(tester, seconds: 5);
      expect(find.byType(AddPartnerScreen), findsOneWidget,
          reason: 'AddPartnerScreen no abrió');

      // Verify UI
      expect(find.textContaining('Ingresa el código'), findsOneWidget);
      expect(find.text('Buscar compañero'), findsOneWidget);

      // Enter User A's code
      final codeInput = find.byType(TextField);
      expect(codeInput, findsOneWidget, reason: 'Input de código no encontrado');
      await tester.tap(codeInput, warnIfMissed: false);
      await _safePump(tester);
      await tester.enterText(codeInput, userAInviteCode);
      await tester.pump(const Duration(milliseconds: 500));
      await _safePump(tester);

      // Dismiss keyboard before tapping search button
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _safePump(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));

      // Search
      final searchBtnFilled = find.widgetWithText(FilledButton, 'Buscar compañero');
      expect(searchBtnFilled, findsOneWidget, reason: 'Botón "Buscar compañero" no encontrado');

      // Verify button state
      final btn = tester.widget<FilledButton>(searchBtnFilled);
      if (btn.onPressed == null) {
        fail('Botón "Buscar compañero" está DISABLED con código de 8 chars');
      }

      await tester.ensureVisible(searchBtnFilled);
      await _safePump(tester);
      await tester.tap(searchBtnFilled, warnIfMissed: false);
      debugPrint('🤖 Buscando código $userAInviteCode...');
      await _waitForFirebase(tester, ms: 5000);

      // Preview card — retry if not immediately visible
      for (var i = 0; i < 5; i++) {
        if (find.textContaining('Enviar solicitud').evaluate().isNotEmpty) break;
        await Future.delayed(const Duration(seconds: 2));
        await _safePump(tester);
      }
      expect(find.textContaining('Enviar solicitud'), findsWidgets,
          reason: 'Preview/botón "Enviar solicitud" no encontrado');

      // Send invite
      final sendBtn = find.widgetWithText(FilledButton, 'Enviar solicitud');
      if (sendBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(sendBtn);
        await _safePump(tester);
        await tester.tap(sendBtn, warnIfMissed: false);
      } else {
        final altSend = find.textContaining('Enviar solicitud');
        await tester.ensureVisible(altSend.first);
        await _safePump(tester);
        await tester.tap(altSend.first, warnIfMissed: false);
      }
      debugPrint('🤖 Enviando solicitud...');
      await _waitForFirebase(tester, ms: 5000);

      // Confirm
      final snack = find.textContaining('Solicitud enviada');
      expect(snack, findsOneWidget, reason: 'SnackBar "Solicitud enviada" no apareció');

      debugPrint('✅ PASO 2 OK — solicitud enviada de B → A');

      // Note: Can't verify User A's partnerInvites from User B (permission-denied).
      // PASO 3 will verify the invite arrived.

      // ════════════════════════════════════════════════════════════════════
      // PASO 3: Switch → User A — ver invitación pendiente → aceptar
      // ════════════════════════════════════════════════════════════════════
      debugPrint('\n🤖 ═══ PASO 3: User A — aceptar invitación ═══');

      await _switchUser(tester);
      await _login(tester, _emailA);
      await _skipOnboardingIfNeeded(tester);

      await _goToPartnerScreen(tester);

      // Wait for Firestore listener — give extra time for real-time update 
      for (var i = 0; i < 12; i++) {
        if (find.textContaining('Invitaciones pendientes').evaluate().isNotEmpty) break;
        await Future.delayed(const Duration(seconds: 2));
        await _safePump(tester);
      }

      expect(find.textContaining('Invitaciones pendientes'), findsOneWidget,
          reason: 'Sección de invitaciones pendientes no visible');

      // "Quiere ser tu compañero"
      expect(find.textContaining('Quiere ser tu compañero'), findsOneWidget,
          reason: 'Texto de invitación no visible');

      // Accept invite
      final acceptIcon = find.byIcon(Icons.check_circle);
      expect(acceptIcon, findsOneWidget, reason: 'Botón aceptar no encontrado');
      await tester.tap(acceptIcon, warnIfMissed: false);
      debugPrint('🤖 Aceptando invitación...');
      await _waitForFirebase(tester, ms: 5000);

      // Wait for partner card
      for (var i = 0; i < 5; i++) {
        if (find.byType(BattlePartnerCard).evaluate().isNotEmpty) break;
        await Future.delayed(const Duration(seconds: 2));
        await _safePump(tester);
      }
      expect(find.byType(BattlePartnerCard), findsOneWidget,
          reason: 'BattlePartnerCard no apareció tras aceptar');

      // Stats on card
      expect(find.textContaining('día'), findsWidgets,
          reason: 'Estadísticas de racha no visibles');

      // Invitations section gone
      expect(find.textContaining('Invitaciones pendientes'), findsNothing,
          reason: 'Invitaciones pendientes debería desaparecer');

      debugPrint('✅ PASO 3 OK — User A aceptó, compañero activo visible');

      // ════════════════════════════════════════════════════════════════════
      // PASO 4: User A — sticker picker + enviar ánimo
      // ════════════════════════════════════════════════════════════════════
      debugPrint('\n🤖 ═══ PASO 4: Sticker picker + enviar ánimo ═══');

      // Tap Ánimo button
      final animoBtn = find.textContaining('Ánimo');
      expect(animoBtn, findsOneWidget, reason: 'Botón "Ánimo" no encontrado');
      await tester.tap(animoBtn, warnIfMissed: false);
      await _pumpAndWait(tester, seconds: 5);

      // StickerPickerSheet
      expect(find.byType(StickerPickerSheet), findsOneWidget,
          reason: 'StickerPickerSheet no abrió');

      // Title
      expect(find.textContaining('Enviar ánimo a'), findsOneWidget,
          reason: 'Título del sheet no visible');

      // All 8 stickers
      expect(find.textContaining('Orando por ti'), findsOneWidget);
      expect(find.textContaining('Bien hecho'), findsOneWidget);
      expect(find.textContaining('No estás solo'), findsOneWidget);
      expect(find.textContaining('Sigue adelante'), findsOneWidget);
      expect(find.textContaining('Dios está contigo'), findsOneWidget);
      expect(find.textContaining('Aquí cuando'), findsOneWidget);
      expect(find.textContaining('orgulloso'), findsOneWidget);
      expect(find.textContaining('Mantente firme'), findsOneWidget);
      debugPrint('🤖 8 stickers verificados');

      // Rate limit counter
      expect(find.textContaining('restante'), findsOneWidget,
          reason: 'Contador de rate-limit no visible');

      // Send sticker
      await tester.tap(find.textContaining('Orando por ti'), warnIfMissed: false);
      debugPrint('🤖 Enviando sticker "Orando por ti"...');
      await _waitForFirebase(tester, ms: 4000);

      // SnackBar
      final snackSent = find.textContaining('Mensaje enviado');
      if (snackSent.evaluate().isNotEmpty) {
        debugPrint('🤖 SnackBar "Mensaje enviado" visible');
      }

      debugPrint('✅ PASO 4 OK — sticker enviado de A → B');

      // ════════════════════════════════════════════════════════════════════
      // PASO 5: Switch → User B — ver compañero activo + mensaje recibido
      // ════════════════════════════════════════════════════════════════════
      debugPrint('\n🤖 ═══ PASO 5: User B — stats + mensaje recibido ═══');

      await _switchUser(tester);
      await _login(tester, _emailB);
      await _skipOnboardingIfNeeded(tester);

      await _goToPartnerScreen(tester);

      // Wait for listeners
      await Future.delayed(const Duration(seconds: 4));
      await _safePump(tester);

      // Partner card
      for (var i = 0; i < 5; i++) {
        if (find.byType(BattlePartnerCard).evaluate().isNotEmpty) break;
        await Future.delayed(const Duration(seconds: 2));
        await _safePump(tester);
      }
      expect(find.byType(BattlePartnerCard), findsOneWidget,
          reason: 'BattlePartnerCard (User A) no visible para User B');

      // Streak info
      expect(find.textContaining('día'), findsWidgets,
          reason: 'Información de racha no visible');

      // Check messages - may have been auto-read
      final msgSection = find.textContaining('Mensajes recientes');
      if (msgSection.evaluate().isNotEmpty) {
        debugPrint('🤖 Sección "Mensajes recientes" visible');
      } else {
        // Verify via Firestore
        debugPrint('🤖 Mensajes posiblemente auto-leídos al entrar');
        final uidB = FirebaseAuth.instance.currentUser?.uid;
        if (uidB != null) {
          final msgs = await db
              .collection('users')
              .doc(uidB)
              .collection('battleMessages')
              .get();
          debugPrint('🤖 User B tiene ${msgs.docs.length} mensajes en Firestore');
          expect(msgs.docs.length, greaterThanOrEqualTo(1),
              reason: 'Debería haber al menos 1 mensaje de A');
        }
      }

      // No empty state
      expect(find.textContaining('Ningún compañero aún'), findsNothing,
          reason: 'No debería mostrar estado vacío');

      debugPrint('✅ PASO 5 OK — User B ve partner + mensaje');

      // ════════════════════════════════════════════════════════════════════
      // PASO 6: User B — desvincular compañero
      // ════════════════════════════════════════════════════════════════════
      debugPrint('\n🤖 ═══ PASO 6: Desvincular compañero ═══');

      final cardToRemove = find.byType(BattlePartnerCard);
      expect(cardToRemove, findsOneWidget);
      await tester.longPress(cardToRemove, warnIfMissed: false);
      await _pumpAndWait(tester, seconds: 3);

      // Dialog
      expect(find.textContaining('Desvincular compañero'), findsOneWidget,
          reason: 'Diálogo de desvincular no apareció');
      expect(find.textContaining('Se dejará de compartir'), findsOneWidget,
          reason: 'Texto de confirmación no visible');

      // Confirm
      final unlinkBtn = find.text('Desvincular');
      expect(unlinkBtn, findsOneWidget);
      await tester.tap(unlinkBtn, warnIfMissed: false);
      debugPrint('🤖 Desvinculando...');
      await _waitForFirebase(tester, ms: 5000);

      // Wait for empty state
      for (var i = 0; i < 5; i++) {
        if (find.textContaining('Ningún compañero aún').evaluate().isNotEmpty) break;
        await Future.delayed(const Duration(seconds: 2));
        await _safePump(tester);
      }
      expect(find.textContaining('Ningún compañero aún'), findsOneWidget,
          reason: 'Debería volver a estado vacío');

      debugPrint('✅ PASO 6 OK — compañero desvinculado');

      // ════════════════════════════════════════════════════════════════════
      // PASO 7: User B — validaciones de error en AddPartnerScreen
      // ════════════════════════════════════════════════════════════════════
      debugPrint('\n🤖 ═══ PASO 7: Validaciones de error ═══');

      await tester.tap(find.byIcon(Icons.person_add_alt_1).first, warnIfMissed: false);
      await _pumpAndWait(tester, seconds: 5);
      expect(find.byType(AddPartnerScreen), findsOneWidget);

      // Non-existent code
      final errInput = find.byType(TextField);
      await tester.enterText(errInput, 'ZZZZZZZZ');
      await _safePump(tester);
      // Dismiss keyboard
      await tester.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));
      final errSearchBtn = find.widgetWithText(FilledButton, 'Buscar compañero');
      await tester.ensureVisible(errSearchBtn);
      await _safePump(tester);
      await tester.tap(errSearchBtn, warnIfMissed: false);
      await _waitForFirebase(tester, ms: 4000);

      expect(find.textContaining('no encontrado'), findsOneWidget,
          reason: 'Error "Código no encontrado" no apareció');
      debugPrint('🤖 ✓ Código inexistente → error correcto');

      // Own code — reopen AddPartnerScreen for fresh state
      final uidB = FirebaseAuth.instance.currentUser?.uid;
      String? codeB;
      if (uidB != null) {
        final docB = await db.collection('users').doc(uidB).get();
        codeB = docB.data()?['inviteCode'] as String?;
        codeB ??= await BattlePartnerService.I.ensureInviteCode();
      }
      if (codeB != null) {
        debugPrint('🤖 Testing own code: $codeB');
        // Go back and reopen to get fresh state
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        nav.pop();
        await _safePump(tester);
        await tester.tap(find.byIcon(Icons.person_add_alt_1).first, warnIfMissed: false);
        await _pumpAndWait(tester, seconds: 5);
        expect(find.byType(AddPartnerScreen), findsOneWidget);

        final ownInput = find.byType(TextField);
        await tester.enterText(ownInput, codeB);
        await _safePump(tester);
        // Dismiss keyboard
        await tester.testTextInput.receiveAction(TextInputAction.done);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 500));
        final ownSearchBtn = find.widgetWithText(FilledButton, 'Buscar compañero');
        await tester.ensureVisible(ownSearchBtn);
        await _safePump(tester);
        await tester.tap(ownSearchBtn, warnIfMissed: false);
        await _waitForFirebase(tester, ms: 4000);

        expect(find.textContaining('tu propio código'), findsOneWidget,
            reason: 'Error "tu propio código" no apareció');
        debugPrint('🤖 ✓ Código propio → error correcto');
      }

      debugPrint('✅ PASO 7 OK — validaciones de error');

      // ════════════════════════════════════════════════════════════════════
      // PASO 8: Cleanup final
      // ════════════════════════════════════════════════════════════════════
      debugPrint('\n🤖 ═══ PASO 8: Cleanup final ═══');
      await _cleanupPartnerData();

      debugPrint('✅ PASO 8 OK — cleanup');

      debugPrint('\n═══════════════════════════════════════════════════');
      debugPrint('  ✅ PARTNER TEST: TODOS LOS PASOS COMPLETADOS');
      debugPrint('═══════════════════════════════════════════════════\n');
    },
  );
}
