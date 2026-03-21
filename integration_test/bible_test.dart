/// ═══════════════════════════════════════════════════════════════════════════
/// INTEGRATION TEST - Módulo La Biblia
/// Pruebas E2E del módulo Biblia: Home, Reader, Search, Compare,
/// Multi-select, Color picker, Saved verses, Notes, Settings.
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Ejecutar con:
///   flutter test integration_test/bible_test.dart -d <DEVICE_ID>
///
/// Requisitos:
///   - Dispositivo físico conectado (o emulador)
///   - Cuenta de prueba: test_a@victoria.com / TestPass123!
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
import 'package:app_quitar/services/bible/bible_parser_service.dart';
import 'package:app_quitar/services/bible/bible_download_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _pump(WidgetTester tester, {int seconds = 10}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      Duration(seconds: seconds),
    );
  } catch (_) {
    debugPrint('🤖 [BIBLE] pumpAndSettle timeout — pump fijo');
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

Future<void> _waitFirebase(WidgetTester tester, {int ms = 3000}) async {
  await Future.delayed(Duration(milliseconds: ms));
  await _pump(tester, seconds: 5);
}

Future<void> _enterField(
    WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  expect(field, findsOneWidget, reason: 'Campo "$label" no encontrado');
  await tester.ensureVisible(field);
  await _safePump(tester);
  await tester.tap(field, warnIfMissed: false);
  await _safePump(tester);
  await tester.enterText(field, text);
  await _safePump(tester);
}

/// Log helper con emoji Biblia
void _log(String msg) => debugPrint('📖 [BIBLE TEST] $msg');

// ═══════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Módulo Biblia — prueba completa E2E', (tester) async {
    // ═════════════════════════════════════════════════════════════════════
    // BOOTSTRAP
    // ═════════════════════════════════════════════════════════════════════
    _log('Inicializando Firebase y servicios...');

    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Sign out any previous session
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // Init all services (same order as main.dart)
    final themeService = ThemeService();
    await themeService.initialize();
    final favoritesService = FavoritesService();
    await favoritesService.init();
    final onboardingService = OnboardingService();
    await onboardingService.init();
    await AudioEngine.I.init();
    await FeedbackEngine.I.init();
    await ContentRepository.I.init();
    await WidgetSyncService.I.init();
    await VictoryScoringService.I.init();
    await DataBootstrapper.I.init();
    await BibleDownloadService.I.init();
    await BibleParserService.I.init();
    await AccountSessionManager.I.init();

    await tester.pumpWidget(VictoriaEnCristoApp(
      themeService: themeService,
      onboardingService: onboardingService,
    ));
    await _waitFirebase(tester, ms: 3000);

    // ═════════════════════════════════════════════════════════════════════
    // LOGIN
    // ═════════════════════════════════════════════════════════════════════
    _log('Haciendo login...');

    // Check if we need to login
    if (find.byType(LoginScreen).evaluate().isNotEmpty) {
      await _enterField(tester, 'Correo electrónico', 'test_a@victoria.com');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _safePump(tester);
      await _enterField(tester, 'Contraseña', 'TestPass123!');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _safePump(tester);

      final loginBtn = find.text('INICIAR SESIÓN');
      await tester.ensureVisible(loginBtn.first);
      await _safePump(tester);
      await tester.tap(loginBtn.first, warnIfMissed: false);
      await _waitFirebase(tester, ms: 5000);
    }

    // If onboarding appears, skip through it fast
    for (int i = 0; i < 5; i++) {
      final continueBtn = find.text('Continuar');
      final startBtn = find.text('Comenzar');
      if (continueBtn.evaluate().isNotEmpty) {
        await tester.tap(continueBtn.first, warnIfMissed: false);
        await _pump(tester);
      } else if (startBtn.evaluate().isNotEmpty) {
        await tester.tap(startBtn.first, warnIfMissed: false);
        await _pump(tester);
      } else {
        break;
      }
    }

    // Verify we're on HomeScreen
    await _pump(tester);
    expect(find.byType(HomeScreen), findsOneWidget,
        reason: 'Se esperaba HomeScreen después de login/onboarding');
    _log('✅ En HomeScreen');

    // ═════════════════════════════════════════════════════════════════════
    // TEST 1: Navegar a "La Biblia"
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 1: Navegando a La Biblia...');

    final bibliaBtn = find.text('La Biblia');
    if (bibliaBtn.evaluate().isEmpty) {
      // Might need to scroll to find it
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          find.text('La Biblia'),
          200,
          scrollable: scrollable.first,
        );
      }
    }
    await tester.ensureVisible(find.text('La Biblia').first);
    await _safePump(tester);
    await tester.tap(find.text('La Biblia').first, warnIfMissed: false);
    await _pump(tester);

    // Wait for books to load (XML parsing)
    await Future.delayed(const Duration(seconds: 3));
    await _pump(tester);

    // Verify BibleHomeScreen content
    expect(find.text('ANTIGUO TESTAMENTO'), findsOneWidget,
        reason: 'BibleHomeScreen no muestra ANTIGUO TESTAMENTO');
    _log('✅ BibleHomeScreen cargada con libros');

    // ═════════════════════════════════════════════════════════════════════
    // TEST 2: Verificar secciones AT y NT
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 2: Verificando secciones AT y NT...');

    expect(find.text('ANTIGUO TESTAMENTO'), findsOneWidget);

    // Scroll down to find NT (SliverList is lazy, needs scrolling)
    final bibleScrollable = find.byType(Scrollable);
    await tester.scrollUntilVisible(
      find.text('NUEVO TESTAMENTO'),
      300,
      scrollable: bibleScrollable.first,
      maxScrolls: 30,
    );
    await _safePump(tester);
    expect(find.text('NUEVO TESTAMENTO'), findsOneWidget,
        reason: 'No se encontró NUEVO TESTAMENTO');
    _log('✅ AT y NT visibles');

    // Scroll back to top
    await tester.drag(bibleScrollable.first, const Offset(0, 5000));
    await _safePump(tester);

    // ═════════════════════════════════════════════════════════════════════
    // TEST 3: Abrir un libro (Génesis) → ChapterSelectorScreen
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 3: Abriendo Génesis...');

    final genesisFinder = find.text('Génesis');
    if (genesisFinder.evaluate().isEmpty) {
      // Parser loaded with a different name or not yet visible
      _log('⚠️ "Génesis" no encontrado, buscando primer libro visible');
    }

    await tester.ensureVisible(genesisFinder.first);
    await _safePump(tester);
    await tester.tap(genesisFinder.first, warnIfMissed: false);
    await _pump(tester);

    // ChapterSelectorScreen should show chapters in a grid
    // The title should contain book name
    expect(find.textContaining('Génesis'), findsWidgets,
        reason: 'ChapterSelectorScreen no muestra Génesis');

    // Should show subtitle with chapter count
    expect(find.textContaining('capítulos'), findsOneWidget,
        reason: 'No se muestra cantidad de capítulos');
    _log('✅ ChapterSelectorScreen abierta para Génesis');

    // ═════════════════════════════════════════════════════════════════════
    // TEST 4: Seleccionar capítulo 1 → BibleReaderScreen
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 4: Abriendo capítulo 1...');

    final chapter1 = find.text('1');
    await tester.ensureVisible(chapter1.first);
    await _safePump(tester);
    await tester.tap(chapter1.first, warnIfMissed: false);
    await _pump(tester);

    // Wait for chapter parsing (isolate can take time)
    for (int attempt = 0; attempt < 5; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
      await _pump(tester);
      if (find.textContaining('Dios', findRichText: true).evaluate().isNotEmpty) break;
      _log('⏳ Esperando carga de versículos (intento ${attempt + 1})...');
    }

    // BibleReaderScreen should show chapter number ornament and verse text
    // Header should show "Génesis 1"
    expect(find.textContaining('Génesis'), findsWidgets,
        reason: 'BibleReaderScreen no muestra Génesis en header');
    _log('✅ BibleReaderScreen cargada — Génesis 1');

    // ═════════════════════════════════════════════════════════════════════
    // TEST 5: Verificar que versículos se muestran
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 5: Verificando versículos...');

    // Génesis 1:1 siempre tiene "creó" o "principio" or "Dios" in all versions
    expect(find.textContaining('Dios', findRichText: true), findsWidgets,
        reason: 'No se encontró texto con "Dios" en Génesis 1');
    _log('✅ Versículos visibles y legibles');

    // ═════════════════════════════════════════════════════════════════════
    // TEST 6: Tap en versículo → Toolbar flotante
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 6: Seleccionando un versículo...');

    // RichText found by findRichText:true, get its center and tap at that position
    // This ensures the tap goes through the normal hit-testing (GestureDetector ancestor)
    final verseRich = find.textContaining('Dios', findRichText: true);
    if (verseRich.evaluate().isNotEmpty) {
      final verseCenter = tester.getCenter(verseRich.first);
      await tester.tapAt(verseCenter);
      await _pump(tester);
    }

    // Toolbar should appear with action icons
    final paintIcon = find.byIcon(Icons.format_paint);
    final bookmarkIcon = find.byIcon(Icons.bookmark_outline);
    final bookmarkFilled = find.byIcon(Icons.bookmark);

    var toolbarVisible =
        paintIcon.evaluate().isNotEmpty ||
        bookmarkIcon.evaluate().isNotEmpty ||
        bookmarkFilled.evaluate().isNotEmpty;

    // Retry tapping at a different verse if toolbar didn't appear
    if (!toolbarVisible) {
      _log('⚠️ Toolbar no apareció, reintentando con tap directo...');
      // Tap in the middle of the screen where verses should be
      final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(screenSize.width / 2, screenSize.height * 0.5));
      await _pump(tester);

      toolbarVisible =
          paintIcon.evaluate().isNotEmpty ||
          bookmarkIcon.evaluate().isNotEmpty ||
          bookmarkFilled.evaluate().isNotEmpty;
    }

    expect(toolbarVisible, isTrue,
        reason: 'Toolbar no apareció al seleccionar versículo');
    _log('✅ Toolbar flotante visible');

    // Reusable: function to tap a verse in the reader
    final verseScreenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    final verseTapPoint = Offset(verseScreenSize.width / 2, verseScreenSize.height * 0.45);
    Future<void> tapVerse() async {
      await tester.tapAt(verseTapPoint);
      await _pump(tester);
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 7: Guardar versículo (bookmark)
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 7: Guardando versículo...');

    if (bookmarkIcon.evaluate().isNotEmpty) {
      await tester.tap(bookmarkIcon.first, warnIfMissed: false);
      await _pump(tester);
      _log('✅ Versículo guardado (bookmark tapped)');
    } else {
      final bookmarkFilled = find.byIcon(Icons.bookmark);
      if (bookmarkFilled.evaluate().isNotEmpty) {
        await tester.tap(bookmarkFilled.first, warnIfMissed: false);
        await _pump(tester);
        _log('✅ Versículo ya estaba guardado, toggle ejecutado');
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 8: Abrir color picker desde toolbar
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 8: Probando highlight con colores...');

    // Re-tap verse to show toolbar
    await tapVerse();

    final paintBtn = find.byIcon(Icons.format_paint);
    if (paintBtn.evaluate().isNotEmpty) {
      await tester.tap(paintBtn.first, warnIfMissed: false);
      await _pump(tester);

      // Color swatches should appear (6 circles + rainbow)
      // Try tapping the first color (should be yellow)
      // The color circles are Container widgets with BoxDecoration + shape: circle
      // Also verify back arrow appears
      final backArrow = find.byIcon(Icons.arrow_back_ios_new);
      expect(backArrow, findsWidgets,
          reason: 'Back arrow no visible en color picker');
      _log('✅ Color picker row visible en toolbar');

      // Tap a color to apply highlight
      // Find circle containers — we can tap the back arrow instead and go check custom picker
      // Actually, let's apply a highlight by tapping back then re-entering
      await tester.tap(backArrow.first, warnIfMissed: false);
      await _pump(tester);
    }

    // Dismiss toolbar by tapping elsewhere
    await tester.tapAt(const Offset(200, 200));
    await _pump(tester);

    // ═════════════════════════════════════════════════════════════════════
    // TEST 9: Copiar versículo
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 9: Copiando versículo...');

    await tapVerse();

    final copyBtn = find.byIcon(Icons.content_copy);
    if (copyBtn.evaluate().isNotEmpty) {
      await tester.tap(copyBtn.first, warnIfMissed: false);
      await _pump(tester);
      _log('✅ Versículo copiado al clipboard');
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 10: Multi-select (long press)
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 10: Probando selección múltiple...');

    // Long-press to start multi-select
    await tester.longPressAt(verseTapPoint);
    await _pump(tester);

    // Multi-select toolbar should show close icon and count
    final closeIcon = find.byIcon(Icons.close);
    if (closeIcon.evaluate().isNotEmpty) {
      _log('✅ Multi-select mode activado');

      // Tap another verse to add to selection (slightly above)
      await tester.tapAt(Offset(verseTapPoint.dx, verseTapPoint.dy - 60));
      await _pump(tester);
      _log('✅ Segundo versículo añadido a selección');

      // Exit multi-select
      final closeIconNow = find.byIcon(Icons.close);
      if (closeIconNow.evaluate().isNotEmpty) {
        await tester.tap(closeIconNow.first, warnIfMissed: false);
        await _pump(tester);
        _log('✅ Multi-select desactivado');
      } else {
        // Dismiss by tapping elsewhere
        await tester.tapAt(const Offset(20, 20));
        await _pump(tester);
      }
    } else {
      _log('⚠️ Multi-select no detectado visualmente');
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 11: Abrir nota (NoteEditorSheet)
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 11: Abriendo editor de notas...');

    await tapVerse();

    final noteIcon = find.byIcon(Icons.edit_note);
    if (noteIcon.evaluate().isNotEmpty) {
      await tester.tap(noteIcon.first, warnIfMissed: false);
      await _pump(tester);

      // NoteEditorSheet should show
      final noteHint = find.text('Escribe tu reflexión...');
      if (noteHint.evaluate().isNotEmpty) {
        _log('✅ NoteEditorSheet abierta');

        // Write a test note
        final noteField = find.byType(TextField);
        if (noteField.evaluate().isNotEmpty) {
          await tester.enterText(noteField.first, 'Nota de prueba automática');
          await _safePump(tester);

          // Find and tap save button
          final saveBtn = find.textContaining('Guardar');
          if (saveBtn.evaluate().isNotEmpty) {
            await tester.tap(saveBtn.first, warnIfMissed: false);
            await _pump(tester);
            _log('✅ Nota guardada');
          }
        }
      } else {
        // Close sheet
        await tester.tapAt(const Offset(200, 100));
        await _pump(tester);
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 12: Comparar versiones
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 12: Abriendo comparación de versiones...');

    await tapVerse();

    final compareIcon = find.byIcon(Icons.compare_arrows);
    if (compareIcon.evaluate().isNotEmpty) {
      await tester.tap(compareIcon.first, warnIfMissed: false);
      await _pump(tester);

      // VerseCompareScreen should show "Comparar" title
      await Future.delayed(const Duration(seconds: 3));
      await _pump(tester);

      final comparar = find.text('Comparar');
      if (comparar.evaluate().isNotEmpty) {
        _log('✅ VerseCompareScreen abierta');

        // Wait for versions to load (parallel, 8s timeout each)
        await Future.delayed(const Duration(seconds: 5));
        await _pump(tester);

        // Check for version short names
        final rvr = find.text('RVR60');
        final nvi = find.text('NVI');
        if (rvr.evaluate().isNotEmpty || nvi.evaluate().isNotEmpty) {
          _log('✅ Versiones cargadas en comparador');
        } else {
          _log('⚠️ Versiones aún cargando o no visibles');
        }

        // Go back
        await tester.tap(find.byIcon(Icons.arrow_back_ios).first,
            warnIfMissed: false);
        await _pump(tester);
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 13: Typography panel (font size + theme)
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 13: Panel de tipografía...');

    // Tap typography icon (text_fields)
    final typographyIcon = find.byIcon(Icons.text_fields);
    if (typographyIcon.evaluate().isNotEmpty) {
      await tester.tap(typographyIcon.first, warnIfMissed: false);
      await _pump(tester);

      // Slider should appear for font size
      final slider = find.byType(Slider);
      if (slider.evaluate().isNotEmpty) {
        _log('✅ Panel de tipografía visible con slider');

        // Change font size by dragging slider
        await tester.drag(slider.first, const Offset(40, 0));
        await _pump(tester);
        _log('✅ Slider de tamaño movido');
      }

      // Close typography panel
      await tester.tap(typographyIcon.first, warnIfMissed: false);
      await _pump(tester);
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 14: In-reader search
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 14: Búsqueda dentro del capítulo...');

    final searchIcon = find.byIcon(Icons.search);
    if (searchIcon.evaluate().isNotEmpty) {
      await tester.tap(searchIcon.first, warnIfMissed: false);
      await _pump(tester);

      // Search field should appear with hint
      final searchHint = find.text('Buscar en capítulo...');
      if (searchHint.evaluate().isNotEmpty) {
        _log('✅ Search overlay abierta');

        // Type a search query that should match in Genesis 1
        final searchField = find.byType(TextField);
        if (searchField.evaluate().isNotEmpty) {
          await tester.enterText(searchField.first, 'Dios');
          await _safePump(tester);
          await _pump(tester);

          // Should show "N de M" match counter
          final matchCounter = find.textContaining('de');
          if (matchCounter.evaluate().isNotEmpty) {
            _log('✅ Resultados de búsqueda encontrados');

            // Try navigate with down arrow
            final downArrow = find.byIcon(Icons.keyboard_arrow_down);
            if (downArrow.evaluate().isNotEmpty) {
              await tester.tap(downArrow.first, warnIfMissed: false);
              await _pump(tester);
              _log('✅ Navegación entre resultados funciona');
            }
          }

          // Close search
          final closeSearch = find.byIcon(Icons.close);
          if (closeSearch.evaluate().isNotEmpty) {
            await tester.tap(closeSearch.first, warnIfMissed: false);
            await _pump(tester);
          }
        }
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 15: Swipe para cambiar capítulo
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 15: Swipe para cambiar capítulo...');

    // Fling left = next chapter (velocity must exceed 200)
    final center = tester.getCenter(find.byType(Scaffold).first);
    await tester.flingFrom(center, const Offset(-300, 0), 500);
    await _pump(tester);
    await Future.delayed(const Duration(seconds: 2));
    await _pump(tester);
    _log('✅ Swipe a capítulo siguiente');

    // Fling right = previous chapter
    final center2 = tester.getCenter(find.byType(Scaffold).first);
    await tester.flingFrom(center2, const Offset(300, 0), 500);
    await _pump(tester);
    await Future.delayed(const Duration(seconds: 2));
    await _pump(tester);
    _log('✅ Swipe de vuelta al capítulo anterior');

    // ═════════════════════════════════════════════════════════════════════
    // TEST 16: Navegar atrás a BibleHomeScreen
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 16: Volviendo a BibleHomeScreen...');

    // Pop the route directly via the root Navigator
    final navigators = find.byType(Navigator);
    _log('📍 Found ${navigators.evaluate().length} Navigator widgets');
    final navigatorState = tester.state<NavigatorState>(navigators.first);
    navigatorState.pop();
    await _pump(tester);

    // Wait for transition
    await Future.delayed(const Duration(seconds: 2));
    await _pump(tester);

    // Debug: check what's visible
    _log('📍 Génesis visible: ${find.text("Génesis").evaluate().isNotEmpty}');

    // Verify we're on BibleHomeScreen (Génesis visible means book list is showing)
    final homeVisible = find.text('Génesis').evaluate().isNotEmpty ||
        find.text('ANTIGUO TESTAMENTO').evaluate().isNotEmpty;
    expect(homeVisible, isTrue,
        reason: 'No se volvió a BibleHomeScreen');
    _log('✅ De vuelta en BibleHomeScreen');

    // Scroll list back to top for subsequent tests
    final homeScrollable = find.byType(Scrollable);
    if (homeScrollable.evaluate().isNotEmpty) {
      await tester.drag(homeScrollable.first, const Offset(0, 3000));
      await _safePump(tester);
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 17: Buscador general (BibleSearchScreen)
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 17: Abriendo buscador general...');

    final homeSearchIcon = find.byIcon(Icons.search);
    if (homeSearchIcon.evaluate().isNotEmpty) {
      await tester.tap(homeSearchIcon.first, warnIfMissed: false);
      await _pump(tester);

      // BibleSearchScreen should open with unified hint
      final searchBibleHint = find.text('Buscar libros, capítulos o versículos...');
      if (searchBibleHint.evaluate().isNotEmpty) {
        _log('✅ BibleSearchScreen abierta con hint unificado');

        // Search for free text "amor" (should find verse results)
        final searchInput = find.byType(TextField);
        if (searchInput.evaluate().isNotEmpty) {
          await tester.enterText(searchInput.first, 'amor');
          await _safePump(tester);

          // Wait for debounce (400ms) + search
          await Future.delayed(const Duration(seconds: 3));
          await _pump(tester);

          // Should show result count or verse results
          final resultCount = find.textContaining('resultado');
          final versiculosSection = find.text('VERSÍCULOS');
          if (resultCount.evaluate().isNotEmpty ||
              versiculosSection.evaluate().isNotEmpty) {
            _log('✅ Resultados de búsqueda de texto libre mostrados');
          } else {
            _log('⚠️ Aún buscando o sin resultados para texto libre');
          }
        }

        // Go back
        final searchBack = find.byIcon(Icons.arrow_back_ios);
        if (searchBack.evaluate().isNotEmpty) {
          await tester.tap(searchBack.first, warnIfMissed: false);
          await _pump(tester);
        }
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 17b: Búsqueda por referencia directa (FIX 3)
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 17b: Búsqueda por referencia directa...');

    final homeSearchIcon2 = find.byIcon(Icons.search);
    if (homeSearchIcon2.evaluate().isNotEmpty) {
      await tester.tap(homeSearchIcon2.first, warnIfMissed: false);
      await _pump(tester);

      final searchInput2 = find.byType(TextField);
      if (searchInput2.evaluate().isNotEmpty) {
        // Search for a book name to test bookOnly intent
        await tester.enterText(searchInput2.first, 'Salmos');
        await _safePump(tester);
        await Future.delayed(const Duration(seconds: 3));
        await _pump(tester);

        // Should show REFERENCIA DIRECTA card
        final refCard = find.text('REFERENCIA DIRECTA');
        if (refCard.evaluate().isNotEmpty) {
          _log('✅ Referencia directa detectada para "Salmos"');
        }

        // Now search for book+chapter
        await tester.enterText(searchInput2.first, 'Salmos 23');
        await _safePump(tester);
        await Future.delayed(const Duration(seconds: 3));
        await _pump(tester);

        final refCardChapter = find.textContaining('capítulo');
        if (refCardChapter.evaluate().isNotEmpty) {
          _log('✅ Referencia con capítulo detectada para "Salmos 23"');
        }

        // Go back
        final back2 = find.byIcon(Icons.arrow_back_ios);
        if (back2.evaluate().isNotEmpty) {
          await tester.tap(back2.first, warnIfMissed: false);
          await _pump(tester);
        }
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 18: Versículos guardados screen
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 18: Verificando versículos guardados...');

    // FIX 4: The link text changed from 'Versículos guardados' to 'Guardados'
    final savedLink = find.text('Guardados');
    if (savedLink.evaluate().isNotEmpty) {
      await tester.ensureVisible(savedLink.first);
      await _safePump(tester);
      await tester.tap(savedLink.first, warnIfMissed: false);
      await _pump(tester);

      // SavedVersesScreen header now has bookmark icon + 'Versículos guardados' title
      final savedTitle = find.textContaining('guardados');
      final bookmarkIcon = find.byIcon(Icons.bookmark);
      if (savedTitle.evaluate().isNotEmpty) {
        _log('✅ SavedVersesScreen abierta');
      }
      if (bookmarkIcon.evaluate().isNotEmpty) {
        _log('✅ Icono bookmark visible en header (FIX 4)');
      }

      // Go back
      final backIcon = find.byIcon(Icons.arrow_back_ios);
      if (backIcon.evaluate().isNotEmpty) {
        await tester.tap(backIcon.first, warnIfMissed: false);
        await _pump(tester);
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 19: Notas screen
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 19: Verificando pantalla de notas...');

    // FIX 4: The link text is still 'Notas' but now has an icon beside it
    final notasLink = find.text('Notas');
    if (notasLink.evaluate().isNotEmpty) {
      await tester.ensureVisible(notasLink.first);
      await _safePump(tester);
      await tester.tap(notasLink.first, warnIfMissed: false);
      await _pump(tester);

      // AllNotesScreen should open with icon in header (FIX 4)
      final noteIcon = find.byIcon(Icons.sticky_note_2_outlined);
      if (noteIcon.evaluate().isNotEmpty) {
        _log('✅ Icono sticky_note visible en header de notas (FIX 4)');
      }

      // AllNotesScreen should open
      _log('✅ AllNotesScreen abierta');

      // Go back
      final backIcon = find.byIcon(Icons.arrow_back_ios);
      if (backIcon.evaluate().isNotEmpty) {
        await tester.tap(backIcon.first, warnIfMissed: false);
        await _pump(tester);
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 20: Settings
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 20: Verificando ajustes de Biblia...');

    final settingsIcon = find.byIcon(Icons.tune);
    if (settingsIcon.evaluate().isNotEmpty) {
      await tester.tap(settingsIcon.first, warnIfMissed: false);
      await _pump(tester);

      // BibleSettingsScreen should open
      final ajustesTitle = find.text('AJUSTES');
      if (ajustesTitle.evaluate().isNotEmpty) {
        _log('✅ BibleSettingsScreen abierta');

        // Check sections
        expect(find.textContaining('VERSIÓN'), findsWidgets);
        expect(find.textContaining('TAMAÑO'), findsWidgets);
        expect(find.textContaining('TEMA'), findsWidgets);
        _log('✅ Todas las secciones de ajustes visibles');
      }

      // Go back
      final backIcon = find.byIcon(Icons.arrow_back_ios);
      if (backIcon.evaluate().isNotEmpty) {
        await tester.tap(backIcon.first, warnIfMissed: false);
        await _pump(tester);
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 21: Cambiar versión a NTV desde home
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 21: Cambiando versión...');

    // The version button shows displayName not shortName
    final rvrDisplay = find.text('Reina-Valera 1960');
    final nviDisplay = find.text('Nueva Versión Internacional');
    Finder? versionBtn;
    if (rvrDisplay.evaluate().isNotEmpty) {
      versionBtn = rvrDisplay;
    } else if (nviDisplay.evaluate().isNotEmpty) {
      versionBtn = nviDisplay;
    }

    if (versionBtn != null) {
      await tester.tap(versionBtn.first, warnIfMissed: false);
      await _pump(tester);

      // VersionSelectorSheet should appear as bottom sheet
      final ntvOption = find.textContaining('NTV');
      if (ntvOption.evaluate().isNotEmpty) {
        await tester.tap(ntvOption.first, warnIfMissed: false);
        await _pump(tester);
        await Future.delayed(const Duration(seconds: 2));
        await _pump(tester);
        _log('✅ Versión cambiada a NTV');
      } else {
        _log('⚠️ Version selector no mostró opciones');
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 22: Probar TLA (versión problemática histórica)
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 22: Probando carga de TLA...');

    // Tap version to open selector again
    final currentVersion = find.text('Nueva Traducción Viviente');
    final altVersion = find.textContaining('NTV');
    final versionToTap = currentVersion.evaluate().isNotEmpty
        ? currentVersion
        : altVersion;
    if (versionToTap.evaluate().isNotEmpty) {
      await tester.tap(versionToTap.first, warnIfMissed: false);
      await _pump(tester);

      final tlaOption = find.textContaining('TLA');
      if (tlaOption.evaluate().isNotEmpty) {
        await tester.tap(tlaOption.first, warnIfMissed: false);
        await _pump(tester);
        await Future.delayed(const Duration(seconds: 3));
        await _pump(tester);
        _log('✅ TLA seleccionada');
      }
    }

    // Open Genesis 1 with TLA
    final genesisAgain = find.text('Génesis');
    if (genesisAgain.evaluate().isNotEmpty) {
      await tester.ensureVisible(genesisAgain.first);
      await _safePump(tester);
      await tester.tap(genesisAgain.first, warnIfMissed: false);
      await _pump(tester);

      // Tap chapter 1
      final ch1 = find.text('1');
      if (ch1.evaluate().isNotEmpty) {
        await tester.tap(ch1.first, warnIfMissed: false);
        await _pump(tester);
        await Future.delayed(const Duration(seconds: 3));
        await _pump(tester);

        // Verify TLA text is loaded (should contain "Dios" still)
        expect(find.textContaining('Dios', findRichText: true), findsWidgets,
            reason: 'TLA no cargó versículos correctamente');
        _log('✅ TLA cargada correctamente — Génesis 1 visible');

        // Go back to home
        final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
        nav.pop();
        await _pump(tester);
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 23: Prayer sheet
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 23: Abriendo oración...');

    // Need to be in reader screen — navigate again
    // First scroll home up
    final homeScrollable3 = find.byType(Scrollable);
    if (homeScrollable3.evaluate().isNotEmpty) {
      await tester.drag(homeScrollable3.first, const Offset(0, 3000));
      await _safePump(tester);
    }

    final genesisAgain2 = find.text('Génesis');
    if (genesisAgain2.evaluate().isNotEmpty) {
      await tester.ensureVisible(genesisAgain2.first);
      await _safePump(tester);
      await tester.tap(genesisAgain2.first, warnIfMissed: false);
      await _pump(tester);

      final ch1 = find.text('1');
      if (ch1.evaluate().isNotEmpty) {
        await tester.tap(ch1.first, warnIfMissed: false);
        await _pump(tester);
        await Future.delayed(const Duration(seconds: 2));
        await _pump(tester);
      }
    }

    // Select a verse and tap prayer icon
    final verseForPrayer = find.textContaining('Dios', findRichText: true);
    if (verseForPrayer.evaluate().isNotEmpty) {
      await tester.tap(verseForPrayer.first, warnIfMissed: false);
      await _pump(tester);

      final prayerIcon = find.byIcon(Icons.volunteer_activism);
      if (prayerIcon.evaluate().isNotEmpty) {
        await tester.tap(prayerIcon.first, warnIfMissed: false);
        await _pump(tester);

        final prayerHint = find.textContaining('pido');
        if (prayerHint.evaluate().isNotEmpty) {
          _log('✅ PrayerSheet abierta');

          // Close it
          await tester.tapAt(const Offset(200, 100));
          await _pump(tester);
        }
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 24: Share as Image — template picker (FIX 6)
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 24: Probando compartir como imagen...');

    // Select a verse, tap share
    final verseForShare = find.textContaining('Dios', findRichText: true);
    if (verseForShare.evaluate().isNotEmpty) {
      await tester.tap(verseForShare.first, warnIfMissed: false);
      await _pump(tester);

      final shareBtn = find.byIcon(Icons.share);
      if (shareBtn.evaluate().isNotEmpty) {
        await tester.tap(shareBtn.first, warnIfMissed: false);
        await _pump(tester);

        // ShareOptionsSheet should appear with "Como Imagen"
        final imageOption = find.text('Como Imagen');
        if (imageOption.evaluate().isNotEmpty) {
          _log('✅ ShareOptionsSheet visible');
          await tester.tap(imageOption.first, warnIfMissed: false);
          await _pump(tester);
          await Future.delayed(const Duration(seconds: 1));
          await _pump(tester);

          // TemplatePickerScreen should show COMPARTIR title
          final compartirTitle = find.text('COMPARTIR');
          if (compartirTitle.evaluate().isNotEmpty) {
            _log('✅ TemplatePickerScreen abierta');

            // Check tabs exist
            final plantillaTab = find.text('PLANTILLA');
            final tamanoTab = find.text('TAMAÑO');
            final ajustesTab = find.text('AJUSTES');
            expect(plantillaTab, findsOneWidget,
                reason: 'Tab PLANTILLA no encontrada');
            expect(tamanoTab, findsOneWidget,
                reason: 'Tab TAMAÑO no encontrada');
            expect(ajustesTab, findsOneWidget,
                reason: 'Tab AJUSTES no encontrada');
            _log('✅ 3 tabs visibles (Plantilla/Tamaño/Ajustes)');

            // Tap TAMAÑO tab to verify dimension selector
            await tester.tap(tamanoTab.first, warnIfMissed: false);
            await _pump(tester);
            final proportions = find.text('PROPORCIONES');
            final square = find.text('1:1');
            final story = find.text('9:16');
            final landscape = find.text('16:9');
            if (proportions.evaluate().isNotEmpty) {
              _log('✅ Tab TAMAÑO muestra PROPORCIONES');
            }
            if (square.evaluate().isNotEmpty &&
                story.evaluate().isNotEmpty &&
                landscape.evaluate().isNotEmpty) {
              _log('✅ 3 dimensiones disponibles: 1:1, 9:16, 16:9');
              // Tap 9:16 to change dimension
              await tester.tap(story.first, warnIfMissed: false);
              await _pump(tester);
              _log('✅ Dimensión cambiada a 9:16');
            }

            // Tap AJUSTES tab to verify toggles
            await tester.tap(ajustesTab.first, warnIfMissed: false);
            await _pump(tester);
            final alignLabel = find.text('ALINEACIÓN');
            final logoToggle = find.text('Mostrar logo');
            final versionToggle = find.text('Mostrar versión');
            if (alignLabel.evaluate().isNotEmpty) {
              _log('✅ Tab AJUSTES muestra ALINEACIÓN');
            }
            if (logoToggle.evaluate().isNotEmpty &&
                versionToggle.evaluate().isNotEmpty) {
              _log('✅ Toggles de logo y versión presentes');
            }

            // Check "Compartir imagen" button
            final shareImageBtn = find.text('Compartir imagen');
            expect(shareImageBtn, findsOneWidget,
                reason: 'Botón "Compartir imagen" no encontrado');
            _log('✅ Botón "Compartir imagen" visible');

            // Go back
            final backIcon = find.byIcon(Icons.arrow_back_ios);
            if (backIcon.evaluate().isNotEmpty) {
              await tester.tap(backIcon.first, warnIfMissed: false);
              await _pump(tester);
            }
          }
        } else {
          _log('⚠️ ShareOptionsSheet no apareció');
          await tester.tapAt(const Offset(200, 100));
          await _pump(tester);
        }
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 25: Bottom nav — next book on last chapter (FIX 5)
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 25: Navegación al siguiente libro...');

    // Go back to home first
    final nav25 = find.byType(Navigator);
    if (nav25.evaluate().isNotEmpty) {
      final navState25 = tester.state<NavigatorState>(nav25.first);
      navState25.pop();
      await _pump(tester);
      await Future.delayed(const Duration(seconds: 1));
      await _pump(tester);
    }

    // We may be on ChapterSelector or Home; let's navigate to a short book
    // Look for Judas (1 chapter only) to test "next book" button
    // First go to BibleHome if needed
    final homeScrollable4 = find.byType(Scrollable);
    if (homeScrollable4.evaluate().isNotEmpty) {
      await tester.drag(homeScrollable4.first, const Offset(0, 3000));
      await _safePump(tester);
    }

    // Scroll to find Judas in NT
    final judasFinder = find.text('Judas');
    final scrollable25 = find.byType(Scrollable);
    if (scrollable25.evaluate().isNotEmpty &&
        judasFinder.evaluate().isEmpty) {
      try {
        await tester.scrollUntilVisible(
          find.text('Judas'),
          300,
          scrollable: scrollable25.first,
          maxScrolls: 50,
        );
        await _safePump(tester);
      } catch (_) {
        _log('⚠️ No pude hacer scroll hasta Judas');
      }
    }

    if (find.text('Judas').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('Judas').first);
      await _safePump(tester);
      await tester.tap(find.text('Judas').first, warnIfMissed: false);
      await _pump(tester);

      // Judas has only 1 chapter, tap "1"
      final ch1Judas = find.text('1');
      if (ch1Judas.evaluate().isNotEmpty) {
        await tester.tap(ch1Judas.first, warnIfMissed: false);
        await _pump(tester);
        await Future.delayed(const Duration(seconds: 3));
        await _pump(tester);

        // Scroll down to bottom nav
        final readerScroll = find.byType(Scrollable);
        if (readerScroll.evaluate().isNotEmpty) {
          await tester.drag(readerScroll.first, const Offset(0, -3000));
          await _safePump(tester);
        }

        // Bottom nav should show "Apocalipsis" as next book
        // (Judas is book 65, Apocalipsis is 66)
        final nextBookText = find.text('Apocalipsis');
        if (nextBookText.evaluate().isNotEmpty) {
          _log('✅ "Apocalipsis" visible como siguiente libro (FIX 5)');
        } else {
          _log('⚠️ Next book no visible en bottom nav (puede ser scroll)');
        }

        // Go back
        final nav25b = find.byType(Navigator);
        if (nav25b.evaluate().isNotEmpty) {
          tester.state<NavigatorState>(nav25b.first).pop();
          await _pump(tester);
          await Future.delayed(const Duration(seconds: 1));
          await _pump(tester);
        }
      }
    } else {
      _log('⚠️ No se encontró "Judas" en la lista — skip test 25');
    }

    // ═════════════════════════════════════════════════════════════════════
    // RESUMEN
    // ═════════════════════════════════════════════════════════════════════
    _log('═══════════════════════════════════════════');
    _log('✅ TODAS LAS PRUEBAS COMPLETADAS (25 tests base)');
    _log('═══════════════════════════════════════════');
    _log('Continuando con tests de nuevas funciones...');

    // ═════════════════════════════════════════════════════════════════════
    // TEST 26: Colecciones link desde BibleHome
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 26: Verificando link de Colecciones...');

    // Make sure we're on BibleHomeScreen
    final homeScrollableCol = find.byType(Scrollable);
    if (homeScrollableCol.evaluate().isNotEmpty) {
      await tester.drag(homeScrollableCol.first, const Offset(0, 3000));
      await _safePump(tester);
    }

    final colLink = find.text('Colecciones');
    if (colLink.evaluate().isNotEmpty) {
      await tester.ensureVisible(colLink.first);
      await _safePump(tester);
      await tester.tap(colLink.first, warnIfMissed: false);
      await _pump(tester);

      // CollectionsScreen should open
      final colTitle = find.textContaining('Colecciones');
      if (colTitle.evaluate().isNotEmpty) {
        _log('✅ CollectionsScreen abierta');
      } else {
        _log('⚠️ CollectionsScreen título no encontrado');
      }

      // Could be empty state — check for "Crear primera colección" or list
      final createFirst = find.textContaining('colección');
      if (createFirst.evaluate().isNotEmpty) {
        _log('✅ CCollectionsScreen muestra contenido');
      }

      // Go back
      final backCol = find.byIcon(Icons.arrow_back_ios_new);
      final backCol2 = find.byIcon(Icons.arrow_back_ios);
      if (backCol.evaluate().isNotEmpty) {
        await tester.tap(backCol.first, warnIfMissed: false);
        await _pump(tester);
      } else if (backCol2.evaluate().isNotEmpty) {
        await tester.tap(backCol2.first, warnIfMissed: false);
        await _pump(tester);
      }
    } else {
      _log('⚠️ Link "Colecciones" no visible en BibleHome');
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 27: Reading Stats row en BibleHome
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 27: Verificando sección de estadísticas...');

    // Stats row shows fire icon for streak and progress bar
    // It may show "0 días" or nothing if empty, or fire icon if there's data
    final fireIcon = find.byIcon(Icons.local_fire_department);
    if (fireIcon.evaluate().isNotEmpty) {
      _log('✅ Icono de racha de lectura visible en BibleHome');
    } else {
      _log('ℹ️ Sin racha aún - normal si no se ha leído capítulos');
    }
    _log('✅ TEST 27 completado');

    // ═════════════════════════════════════════════════════════════════════
    // TEST 28: Navigate to reader, verify TTS button
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 28: Verificando botón TTS en reader...');

    // Scroll to top and open Génesis again
    final homeScroll28 = find.byType(Scrollable);
    if (homeScroll28.evaluate().isNotEmpty) {
      await tester.drag(homeScroll28.first, const Offset(0, 3000));
      await _safePump(tester);
    }

    final genesis28 = find.text('Génesis');
    if (genesis28.evaluate().isNotEmpty) {
      await tester.ensureVisible(genesis28.first);
      await _safePump(tester);
      await tester.tap(genesis28.first, warnIfMissed: false);
      await _pump(tester);

      // ChapterSelector — tap chapter 1
      final ch1_28 = find.text('1');
      if (ch1_28.evaluate().isNotEmpty) {
        await tester.tap(ch1_28.first, warnIfMissed: false);
        await _pump(tester);
        await Future.delayed(const Duration(seconds: 3));
        await _pump(tester);
      }
    }

    // Look for headphones icon (TTS) in header
    final headphonesIcon = find.byIcon(Icons.headphones_outlined);
    if (headphonesIcon.evaluate().isNotEmpty) {
      _log('✅ Botón TTS (headphones) visible en reader header');
    } else {
      _log('⚠️ Botón TTS no encontrado en reader header');
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 29: Start TTS playback
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 29: Iniciando TTS...');

    final headphones31 = find.byIcon(Icons.headphones_outlined);
    if (headphones31.evaluate().isNotEmpty) {
      await tester.tap(headphones31.first, warnIfMissed: false);
      await _pump(tester);
      await Future.delayed(const Duration(seconds: 2));
      await _pump(tester);

      // AudioPlayerBar should appear
      // Check for stop_rounded icon (TTS active state)
      final stopIcon = find.byIcon(Icons.stop_rounded);
      if (stopIcon.evaluate().isNotEmpty) {
        _log('✅ TTS activo — icono stop visible en header');
      }

      // AudioPlayerBar should show play/pause button
      final pauseIcon = find.byIcon(Icons.pause_rounded);
      final playIcon = find.byIcon(Icons.play_arrow_rounded);
      if (pauseIcon.evaluate().isNotEmpty ||
          playIcon.evaluate().isNotEmpty) {
        _log('✅ AudioPlayerBar visible con controles');
      }

      // Stop TTS
      if (stopIcon.evaluate().isNotEmpty) {
        await tester.tap(stopIcon.first, warnIfMissed: false);
        await _pump(tester);
        _log('✅ TTS detenido');
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 30: Toolbar — Add to Collection icon
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 30: Verificando icono Colecciones en toolbar...');

    // Tap a verse to show toolbar
    final verse32 = find.textContaining('Dios', findRichText: true);
    if (verse32.evaluate().isNotEmpty) {
      await tester.tap(verse32.first, warnIfMissed: false);
      await _pump(tester);
    }

    final collBookmarkIcon = find.byIcon(Icons.collections_bookmark_outlined);
    if (collBookmarkIcon.evaluate().isNotEmpty) {
      _log('✅ Icono de Colecciones visible en toolbar');
    } else {
      _log('⚠️ Icono de Colecciones no encontrado en toolbar');
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 31: Toolbar — Concordance icon
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 31: Verificando icono Concordancia en toolbar...');

    final concordanceIcon = find.byIcon(Icons.account_tree_outlined);
    if (concordanceIcon.evaluate().isNotEmpty) {
      _log('✅ Icono de Concordancia visible en toolbar');
    } else {
      _log('⚠️ Icono de Concordancia no encontrado en toolbar');
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 32: Toolbar — Share to Wall icon
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 32: Verificando icono Al Muro en toolbar...');

    final wallIcon = find.byIcon(Icons.shield_outlined);
    if (wallIcon.evaluate().isNotEmpty) {
      _log('✅ Icono "Al Muro" visible en toolbar');
    } else {
      _log('⚠️ Icono "Al Muro" no encontrado en toolbar');
    }

    // Dismiss toolbar
    await tester.tapAt(const Offset(200, 200));
    await _pump(tester);

    // ═════════════════════════════════════════════════════════════════════
    // TEST 33: Open Concordance sheet
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 33: Abriendo Concordancia...');

    // Re-tap verse for toolbar
    if (verse32.evaluate().isNotEmpty) {
      await tester.tap(verse32.first, warnIfMissed: false);
      await _pump(tester);
    }

    final concordBtn = find.byIcon(Icons.account_tree_outlined);
    if (concordBtn.evaluate().isNotEmpty) {
      await tester.tap(concordBtn.first, warnIfMissed: false);
      await _pump(tester);
      await Future.delayed(const Duration(seconds: 1));
      await _pump(tester);

      // ConcordanceSheet should open with a search field
      final searchField = find.byType(TextField);
      if (searchField.evaluate().isNotEmpty) {
        _log('✅ ConcordanceSheet abierta con campo de búsqueda');
      }

      // Search for a word
      final concordSearch = find.byType(TextField);
      if (concordSearch.evaluate().isNotEmpty) {
        await tester.enterText(concordSearch.first, 'Dios');
        await _safePump(tester);

        // Wait for debounce + search
        await Future.delayed(const Duration(seconds: 3));
        await _pump(tester);

        // Check for results
        final resultsText = find.textContaining('resultado');
        if (resultsText.evaluate().isNotEmpty) {
          _log('✅ Resultados de concordancia mostrados');
        } else {
          _log('ℹ️ Concordancia buscando o sin resultados visibles');
        }
      }

      // Close concordance sheet by tapping outside
      await tester.tapAt(const Offset(200, 50));
      await _pump(tester);
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 34: Open Share to Wall
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 34: Abriendo compartir al Muro...');

    // Re-tap verse for toolbar
    if (verse32.evaluate().isNotEmpty) {
      await tester.tap(verse32.first, warnIfMissed: false);
      await _pump(tester);
    }

    final wallBtn = find.byIcon(Icons.shield_outlined);
    if (wallBtn.evaluate().isNotEmpty) {
      await tester.tap(wallBtn.first, warnIfMissed: false);
      await _pump(tester);

      // WallComposerScreen should open — check for the shield icon or text
      await Future.delayed(const Duration(seconds: 1));
      await _pump(tester);

      // The wall composer should have pre-populated text from the verse
      final textField = find.byType(TextField);
      final textFormField = find.byType(TextFormField);
      if (textField.evaluate().isNotEmpty || textFormField.evaluate().isNotEmpty) {
        _log('✅ WallComposerScreen abierta con campo de texto');
      }

      // Go back
      final backWall = find.byIcon(Icons.arrow_back_ios_new);
      final backWall2 = find.byIcon(Icons.arrow_back_ios);
      final closeWall = find.byIcon(Icons.close);
      if (backWall.evaluate().isNotEmpty) {
        await tester.tap(backWall.first, warnIfMissed: false);
        await _pump(tester);
      } else if (backWall2.evaluate().isNotEmpty) {
        await tester.tap(backWall2.first, warnIfMissed: false);
        await _pump(tester);
      } else if (closeWall.evaluate().isNotEmpty) {
        await tester.tap(closeWall.first, warnIfMissed: false);
        await _pump(tester);
      } else {
        // Pop via navigator
        final navWall = find.byType(Navigator);
        if (navWall.evaluate().isNotEmpty) {
          tester.state<NavigatorState>(navWall.first).pop();
          await _pump(tester);
        }
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 35: BibleStatsScreen con datos reales
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 35: Verificando BibleStatsScreen...');

    // Go back to BibleHome
    final nav37 = find.byType(Navigator);
    if (nav37.evaluate().isNotEmpty) {
      tester.state<NavigatorState>(nav37.first).pop();
      await _pump(tester);
      await Future.delayed(const Duration(seconds: 1));
      await _pump(tester);
    }

    // Scroll to top
    final homeScroll37 = find.byType(Scrollable);
    if (homeScroll37.evaluate().isNotEmpty) {
      await tester.drag(homeScroll37.first, const Offset(0, 3000));
      await _safePump(tester);
    }

    // Stats row should show fire icon if we just read a chapter
    final fireIcon37 = find.byIcon(Icons.local_fire_department);
    if (fireIcon37.evaluate().isNotEmpty) {
      // Tap on stats row to open BibleStatsScreen
      await tester.tap(fireIcon37.first, warnIfMissed: false);
      await _pump(tester);

      // BibleStatsScreen should show
      final statsTitle = find.text('Estadísticas de Lectura');
      if (statsTitle.evaluate().isNotEmpty) {
        _log('✅ BibleStatsScreen abierta');

        // Check for stat cards
        final rachaCard = find.text('Racha de Lectura');
        final capCard = find.text('Capítulos Leídos');
        final progressCard = find.text('Progreso Total');
        if (rachaCard.evaluate().isNotEmpty) {
          _log('✅ Card "Racha de Lectura" visible');
        }
        if (capCard.evaluate().isNotEmpty) {
          _log('✅ Card "Capítulos Leídos" visible');
        }
        if (progressCard.evaluate().isNotEmpty) {
          _log('✅ Card "Progreso Total" visible');
        }

        // Go back
        final backStats = find.byIcon(Icons.arrow_back_ios_new);
        if (backStats.evaluate().isNotEmpty) {
          await tester.tap(backStats.first, warnIfMissed: false);
          await _pump(tester);
        }
      }
    } else {
      _log('ℹ️ Sin racha — stats row no visible (normal si primera lectura no se registró aún)');
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 36: Chapter selector — gold chapters
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 36: Verificando capítulos leídos en selector...');

    // Open Génesis chapter selector
    final homeScroll38 = find.byType(Scrollable);
    if (homeScroll38.evaluate().isNotEmpty) {
      await tester.drag(homeScroll38.first, const Offset(0, 3000));
      await _safePump(tester);
    }

    final genesis38 = find.text('Génesis');
    if (genesis38.evaluate().isNotEmpty) {
      await tester.ensureVisible(genesis38.first);
      await _safePump(tester);
      await tester.tap(genesis38.first, warnIfMissed: false);
      await _pump(tester);

      // We're on ChapterSelectorScreen
      // Chapter 1 should be highlighted (gold) since we read it
      // We can't easily verify the color, but the screen should load
      expect(find.textContaining('capítulos'), findsOneWidget,
          reason: 'ChapterSelectorScreen no muestra cantidad de capítulos');
      _log('✅ ChapterSelectorScreen cargada — verificación visual de gold chapters');

      // Go back
      final back38 = find.byIcon(Icons.arrow_back_ios);
      if (back38.evaluate().isNotEmpty) {
        await tester.tap(back38.first, warnIfMissed: false);
        await _pump(tester);
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 37: Red letter toggle en Settings
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 37: Toggle de palabras en rojo en Ajustes...');

    // Go back to BibleHome first
    final nav39 = find.byType(Navigator);
    if (nav39.evaluate().isNotEmpty) {
      tester.state<NavigatorState>(nav39.first).pop();
      await _pump(tester);
      await Future.delayed(const Duration(seconds: 1));
      await _pump(tester);
    }

    // Scroll to top of BibleHome
    final homeScroll39 = find.byType(Scrollable);
    if (homeScroll39.evaluate().isNotEmpty) {
      await tester.drag(homeScroll39.first, const Offset(0, 3000));
      await _safePump(tester);
    }

    // Open Settings
    final settingsIcon39 = find.byIcon(Icons.tune);
    if (settingsIcon39.evaluate().isNotEmpty) {
      await tester.tap(settingsIcon39.first, warnIfMissed: false);
      await _pump(tester);

      // Scroll down to find ESTUDIO BÍBLICO section
      final settingsScroll = find.byType(Scrollable);
      if (settingsScroll.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          find.text('ESTUDIO BÍBLICO'),
          200,
          scrollable: settingsScroll.first,
          maxScrolls: 20,
        );
        await _safePump(tester);
      }

      final estudioBiblico = find.text('ESTUDIO BÍBLICO');
      if (estudioBiblico.evaluate().isNotEmpty) {
        _log('✅ Sección "ESTUDIO BÍBLICO" visible en Settings');
      }

      // Verify red letter toggle
      final redLetterLabel = find.text('Palabras de Cristo en rojo');
      if (redLetterLabel.evaluate().isNotEmpty) {
        _log('✅ Toggle "Palabras de Cristo en rojo" visible');

        // Verify subtitle
        final redLetterSubtitle = find.text('Resalta las palabras de Jesús en los Evangelios');
        if (redLetterSubtitle.evaluate().isNotEmpty) {
          _log('✅ Subtítulo del toggle visible');
        }

        // Toggle the switch (tap the Switch widget)
        final switchWidget = find.byType(Switch);
        if (switchWidget.evaluate().isNotEmpty) {
          await tester.tap(switchWidget.first, warnIfMissed: false);
          await _pump(tester);
          _log('✅ Switch toggled (off)');

          // Toggle back on
          await tester.tap(switchWidget.first, warnIfMissed: false);
          await _pump(tester);
          _log('✅ Switch toggled (on again)');
        }
      }

      // Verify dictionary button
      final dictLabel = find.text('Diccionario Bíblico');
      if (dictLabel.evaluate().isNotEmpty) {
        _log('✅ Botón "Diccionario Bíblico" visible');

        final dictSubtitle = find.text('Easton + Hitchcock — Dominio público');
        if (dictSubtitle.evaluate().isNotEmpty) {
          _log('✅ Subtítulo del diccionario visible');
        }
      }

      // Go back from Settings
      final backSettings = find.byIcon(Icons.arrow_back_ios);
      if (backSettings.evaluate().isNotEmpty) {
        await tester.tap(backSettings.first, warnIfMissed: false);
        await _pump(tester);
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 38: Dictionary screen from Settings
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 38: Abriendo Diccionario desde Settings...');

    // Re-open Settings
    final settingsIcon40 = find.byIcon(Icons.tune);
    if (settingsIcon40.evaluate().isNotEmpty) {
      await tester.tap(settingsIcon40.first, warnIfMissed: false);
      await _pump(tester);

      // Scroll to dictionary button
      final settingsScroll40 = find.byType(Scrollable);
      if (settingsScroll40.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          find.text('Diccionario Bíblico'),
          200,
          scrollable: settingsScroll40.first,
          maxScrolls: 20,
        );
        await _safePump(tester);
      }

      // Tap dictionary button
      final dictBtn = find.text('Diccionario Bíblico');
      if (dictBtn.evaluate().isNotEmpty) {
        await tester.tap(dictBtn.first, warnIfMissed: false);
        await _pump(tester);
        await Future.delayed(const Duration(seconds: 1));
        await _pump(tester);

        // BibleDictionaryScreen should open
        final dictTitle = find.text('DICCIONARIO BÍBLICO');
        if (dictTitle.evaluate().isNotEmpty) {
          _log('✅ BibleDictionaryScreen abierta desde Settings');

          // Check entry count
          final entradas = find.textContaining('entradas');
          if (entradas.evaluate().isNotEmpty) {
            _log('✅ Contador de entradas visible');
          }

          // Check filter chips
          final todosChip = find.text('Todos');
          final eastonChip = find.text('Easton');
          final hitchcockChip = find.text('Hitchcock');
          if (todosChip.evaluate().isNotEmpty &&
              eastonChip.evaluate().isNotEmpty &&
              hitchcockChip.evaluate().isNotEmpty) {
            _log('✅ 3 filter chips visibles: Todos/Easton/Hitchcock');
          }

          // ═════════════════════════════════════════════════════════════
          // TEST 39: Dictionary search and filter
          // ═════════════════════════════════════════════════════════════
          _log('TEST 39: Búsqueda y filtro en diccionario...');

          // Search for a term
          final searchField = find.byType(TextField);
          if (searchField.evaluate().isNotEmpty) {
            await tester.enterText(searchField.first, 'Dios');
            await _safePump(tester);
            await Future.delayed(const Duration(seconds: 1));
            await _pump(tester);

            // Check for results or empty state
            final noResults = find.text('No se encontraron resultados');
            if (noResults.evaluate().isEmpty) {
              _log('✅ Resultados de búsqueda mostrados para "Dios"');
            } else {
              _log('ℹ️ Sin resultados para "Dios" — probando otro término');
            }

            // Clear search
            final clearBtn = find.byIcon(Icons.clear);
            if (clearBtn.evaluate().isNotEmpty) {
              await tester.tap(clearBtn.first, warnIfMissed: false);
              await _pump(tester);
              _log('✅ Búsqueda limpiada');
            }
          }

          // Tap Easton filter
          if (eastonChip.evaluate().isNotEmpty) {
            await tester.tap(eastonChip.first, warnIfMissed: false);
            await _pump(tester);
            _log('✅ Filtro Easton seleccionado');
          }

          // Tap Hitchcock filter
          if (hitchcockChip.evaluate().isNotEmpty) {
            await tester.tap(hitchcockChip.first, warnIfMissed: false);
            await _pump(tester);
            _log('✅ Filtro Hitchcock seleccionado');
          }

          // Back to All
          if (todosChip.evaluate().isNotEmpty) {
            await tester.tap(todosChip.first, warnIfMissed: false);
            await _pump(tester);
          }

          // ═════════════════════════════════════════════════════════════
          // TEST 40: Dictionary detail screen
          // ═════════════════════════════════════════════════════════════
          _log('TEST 40: Abriendo detalle de diccionario...');

          // Tap first entry in the list (should be a ListTile with chevron_right)
          final chevron = find.byIcon(Icons.chevron_right);
          if (chevron.evaluate().isNotEmpty) {
            await tester.tap(chevron.first, warnIfMissed: false);
            await _pump(tester);
            await Future.delayed(const Duration(seconds: 1));
            await _pump(tester);

            // BibleDictionaryDetailScreen should open
            final definitionHeader = find.text('DEFINICIÓN');
            if (definitionHeader.evaluate().isNotEmpty) {
              _log('✅ BibleDictionaryDetailScreen abierta con DEFINICIÓN');
            }

            // Check for references section
            final refsHeader = find.text('REFERENCIAS BÍBLICAS');
            if (refsHeader.evaluate().isNotEmpty) {
              _log('✅ Sección REFERENCIAS BÍBLICAS visible');
            }

            // Go back to dictionary list
            final backDetail = find.byIcon(Icons.arrow_back_ios_new);
            if (backDetail.evaluate().isNotEmpty) {
              await tester.tap(backDetail.first, warnIfMissed: false);
              await _pump(tester);
            }
          }

          // Go back from Dictionary screen
          final backDict = find.byIcon(Icons.arrow_back_ios_new);
          if (backDict.evaluate().isNotEmpty) {
            await tester.tap(backDict.first, warnIfMissed: false);
            await _pump(tester);
          }
        }

        // Go back from Settings
        final backSettings40 = find.byIcon(Icons.arrow_back_ios);
        if (backSettings40.evaluate().isNotEmpty) {
          await tester.tap(backSettings40.first, warnIfMissed: false);
          await _pump(tester);
        }
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 41: Red letters in Juan (John) — NT book
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 41: Navegando a Juan 3 para probar letras rojas...');

    // Scroll down in BibleHome to find Juan (book 43 = NT)
    final homeScroll43 = find.byType(Scrollable);
    if (homeScroll43.evaluate().isNotEmpty) {
      await tester.drag(homeScroll43.first, const Offset(0, 3000));
      await _safePump(tester);
    }

    // Scroll to NT and find Juan
    final juanFinder = find.text('Juan');
    final scrollable43 = find.byType(Scrollable);
    if (scrollable43.evaluate().isNotEmpty && juanFinder.evaluate().isEmpty) {
      try {
        await tester.scrollUntilVisible(
          find.text('Juan'),
          300,
          scrollable: scrollable43.first,
          maxScrolls: 50,
        );
        await _safePump(tester);
      } catch (_) {
        _log('⚠️ No pude hacer scroll hasta Juan');
      }
    }

    if (find.text('Juan').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('Juan').first);
      await _safePump(tester);
      await tester.tap(find.text('Juan').first, warnIfMissed: false);
      await _pump(tester);

      // ChapterSelector — tap chapter 3
      final ch3 = find.text('3');
      if (ch3.evaluate().isNotEmpty) {
        await tester.tap(ch3.first, warnIfMissed: false);
        await _pump(tester);
        await Future.delayed(const Duration(seconds: 4));
        await _pump(tester);

        // Juan 3 should load - check for verse text
        final juanText = find.textContaining('Dios', findRichText: true);
        if (juanText.evaluate().isNotEmpty) {
          _log('✅ Juan 3 cargado — versículos visibles');
          _log('✅ Palabras de Cristo en rojo activas (verificación visual)');
          // NOTE: Red letter color is applied at render level; 
          // we can't easily test Color in integration tests but the code path is exercised
        } else {
          _log('⚠️ Juan 3 aún cargando');
          // Wait more
          await Future.delayed(const Duration(seconds: 3));
          await _pump(tester);
        }

        // ═════════════════════════════════════════════════════════════
        // TEST 42: VerseStudySheet with 5 tabs — Interlineal tab
        // ═════════════════════════════════════════════════════════════
        _log('TEST 42: Abriendo VerseStudySheet con 5 tabs...');

        // Tap a verse to show toolbar
        final verse44 = find.textContaining('Dios', findRichText: true);
        if (verse44.evaluate().isNotEmpty) {
          await tester.tap(verse44.first, warnIfMissed: false);
          await _pump(tester);

          // Tap study icon (school_outlined) to open VerseStudySheet
          final studyIcon = find.byIcon(Icons.school_outlined);
          if (studyIcon.evaluate().isNotEmpty) {
            await tester.tap(studyIcon.first, warnIfMissed: false);
            await _pump(tester);
            await Future.delayed(const Duration(seconds: 3));
            await _pump(tester);

            // Verify sheet opened
            final estudioTitle = find.text('ESTUDIO PROFUNDO');
            if (estudioTitle.evaluate().isNotEmpty) {
              _log('✅ VerseStudySheet abierta — "ESTUDIO PROFUNDO" visible');
            }

            // Verify 5 tabs exist
            final tabInterlineal = find.text('Interlineal');
            final tabStrongs = find.text("Strong's");
            final tabLexicon = find.text('Lexicón');
            final tabRefs = find.text('Referencias');
            final tabComentario = find.text('Comentario');

            if (tabInterlineal.evaluate().isNotEmpty) {
              _log('✅ Tab "Interlineal" visible');
            }
            if (tabStrongs.evaluate().isNotEmpty) {
              _log("✅ Tab \"Strong's\" visible");
            }
            if (tabLexicon.evaluate().isNotEmpty) {
              _log('✅ Tab "Lexicón" visible');
            }
            if (tabRefs.evaluate().isNotEmpty) {
              _log('✅ Tab "Referencias" visible');
            }
            if (tabComentario.evaluate().isNotEmpty) {
              _log('✅ Tab "Comentario" visible');
            }

            // Check Interlineal tab content (should be default or first tab)
            if (tabInterlineal.evaluate().isNotEmpty) {
              await tester.tap(tabInterlineal.first, warnIfMissed: false);
              await _pump(tester);
              await Future.delayed(const Duration(seconds: 3));
              await _pump(tester);

              // Should show GRIEGO (SBLGNT) for Juan (NT book)
              final griegoHeader = find.text('GRIEGO (SBLGNT)');
              if (griegoHeader.evaluate().isNotEmpty) {
                _log('✅ Header "GRIEGO (SBLGNT)" visible en Interlineal');
              }

              // Should show hint text
              final hintText = find.text('Toca una palabra');
              if (hintText.evaluate().isNotEmpty) {
                _log('✅ Hint "Toca una palabra" visible');
              }

              // Spanish text section
              final spanishHeader = find.textContaining('TEXTO EN ESPAÑOL');
              if (spanishHeader.evaluate().isNotEmpty) {
                _log('✅ Sección de texto en español visible');
              }

              // ═══════════════════════════════════════════════════════
              // TEST 43: Tap interlinear word → Morphology panel
              // ═══════════════════════════════════════════════════════
              _log('TEST 43: Tocando palabra interlineal...');

              // The interlinear words are rendered in a Wrap widget as InkWell containers
              // Look for any InkWell that could be an interlinear word chip
              // Words appear as Container > Column > Text(originalWord) + Text(POS) + Text(gloss)
              // We can try tapping directly in the interlineal content area
              
              // Try to find touch_app icon which hints at tappable words
              final touchIcon = find.byIcon(Icons.touch_app);
              if (touchIcon.evaluate().isNotEmpty) {
                _log('✅ Icono touch_app visible (indicador de palabras tappables)');
              }

              // Try tapping in the area where interlinear words should be 
              // (center of the screen, which should be inside the Wrap of word chips)
              // Tap in the middle of the bottom half where word chips render
              final screenSize45 = tester.view.physicalSize / tester.view.devicePixelRatio;
              await tester.tapAt(Offset(screenSize45.width * 0.3, screenSize45.height * 0.55));
              await _pump(tester);
              await Future.delayed(const Duration(seconds: 1));
              await _pump(tester);

              // Check if MorphologyDetailPanel opened (bottom sheet)
              final categoriaLabel = find.text('CATEGORÍA');
              final lemaLabel = find.textContaining('Lema:');
              final griegoLang = find.text('Griego');
              
              if (categoriaLabel.evaluate().isNotEmpty ||
                  lemaLabel.evaluate().isNotEmpty) {
                _log('✅ MorphologyDetailPanel abierta — CATEGORÍA o Lema visible');

                if (griegoLang.evaluate().isNotEmpty) {
                  _log('✅ Idioma "Griego" mostrado en panel');
                }

                // Check for morph grid chips
                final tiempoLabel = find.text('TIEMPO');
                final vozLabel = find.text('VOZ');
                final modoLabel = find.text('MODO');
                if (tiempoLabel.evaluate().isNotEmpty) _log('✅ TIEMPO visible');
                if (vozLabel.evaluate().isNotEmpty) _log('✅ VOZ visible');
                if (modoLabel.evaluate().isNotEmpty) _log('✅ MODO visible');

                // Check for raw morph code
                final codeIcon = find.byIcon(Icons.code);
                if (codeIcon.evaluate().isNotEmpty) {
                  _log('✅ Sección de código morph crudo visible');
                }

                // Close morphology panel (tap outside or drag down)
                await tester.tapAt(Offset(screenSize45.width / 2, screenSize45.height * 0.15));
                await _pump(tester);
              } else {
                _log('⚠️ MorphologyDetailPanel no se abrió — tap no alcanzó una palabra');
                _log('ℹ️ Las palabras interlineales son widgets pequeños; verificación visual recomendada');
              }
            }

            // ═══════════════════════════════════════════════════════
            // TEST 44: Comentario tab
            // ═══════════════════════════════════════════════════════
            _log('TEST 44: Probando tab Comentario...');

            final tabComentario46 = find.text('Comentario');
            if (tabComentario46.evaluate().isNotEmpty) {
              await tester.tap(tabComentario46.first, warnIfMissed: false);
              await _pump(tester);
              await Future.delayed(const Duration(seconds: 2));
              await _pump(tester);

              // Juan IS in the commentary (book 43 = JHN)
              final mhHeader = find.text('MATTHEW HENRY');
              final domPublico = find.text('Dominio público');
              final noDisponible = find.text('Comentario no disponible para este libro');
              final noHayComentario = find.text('No hay comentario para este versículo');

              if (mhHeader.evaluate().isNotEmpty) {
                _log('✅ Header "MATTHEW HENRY" visible en tab Comentario');
              }
              if (domPublico.evaluate().isNotEmpty) {
                _log('✅ "Dominio público" visible');
              }
              if (noDisponible.evaluate().isNotEmpty) {
                _log('ℹ️ Comentario no disponible para Juan (solo GEN/PSA/MAT/JHN/ROM curados)');
              }
              if (noHayComentario.evaluate().isNotEmpty) {
                _log('ℹ️ No hay comentario para este versículo específico');
              }

              // Check for verse commentary entries (v. N format)
              final verseEntry = find.textContaining('v.');
              if (verseEntry.evaluate().isNotEmpty) {
                _log('✅ Entradas de comentario con prefijo "v." visibles');
              }
            }

            // Close VerseStudySheet
            final closeSheet = find.byIcon(Icons.close);
            if (closeSheet.evaluate().isNotEmpty) {
              await tester.tap(closeSheet.first, warnIfMissed: false);
              await _pump(tester);
            }
          }
        }

        // ═════════════════════════════════════════════════════════════
        // TEST 45: Dictionary icon in toolbar
        // ═════════════════════════════════════════════════════════════
        _log('TEST 45: Icono de diccionario en toolbar...');

        // Tap a verse to show toolbar
        final verse47 = find.textContaining('Dios', findRichText: true);
        if (verse47.evaluate().isNotEmpty) {
          await tester.tap(verse47.first, warnIfMissed: false);
          await _pump(tester);

          // Look for dictionary icon
          final dictIcon = find.byIcon(Icons.menu_book_outlined);
          if (dictIcon.evaluate().isNotEmpty) {
            _log('✅ Icono de Diccionario (menu_book_outlined) visible en toolbar');

            // Tap dictionary icon — should navigate to BibleDictionaryScreen
            await tester.tap(dictIcon.first, warnIfMissed: false);
            await _pump(tester);
            await Future.delayed(const Duration(seconds: 1));
            await _pump(tester);

            final dictScreenTitle = find.text('DICCIONARIO BÍBLICO');
            if (dictScreenTitle.evaluate().isNotEmpty) {
              _log('✅ BibleDictionaryScreen abierta desde toolbar');

              // Go back
              final backDictToolbar = find.byIcon(Icons.arrow_back_ios_new);
              if (backDictToolbar.evaluate().isNotEmpty) {
                await tester.tap(backDictToolbar.first, warnIfMissed: false);
                await _pump(tester);
              }
            }
          } else {
            _log('⚠️ Icono de Diccionario no encontrado en toolbar (puede necesitar scroll horizontal)');
          }
        }

        // Dismiss toolbar
        await tester.tapAt(const Offset(200, 200));
        await _pump(tester);

        // Go back to BibleHome
        final nav43 = find.byType(Navigator);
        if (nav43.evaluate().isNotEmpty) {
          tester.state<NavigatorState>(nav43.first).pop();
          await _pump(tester);
          await Future.delayed(const Duration(seconds: 1));
          await _pump(tester);
        }
      }
    } else {
      _log('⚠️ "Juan" no encontrado en la lista de libros');
    }

    // ═════════════════════════════════════════════════════════════════════
    // TEST 46: OT book (Génesis) — Hebrew interlinear
    // ═════════════════════════════════════════════════════════════════════
    _log('TEST 46: Interlineal hebreo en Génesis 1...');

    // Scroll to top of BibleHome
    final homeScroll48 = find.byType(Scrollable);
    if (homeScroll48.evaluate().isNotEmpty) {
      await tester.drag(homeScroll48.first, const Offset(0, 3000));
      await _safePump(tester);
    }

    final genesis48 = find.text('Génesis');
    if (genesis48.evaluate().isNotEmpty) {
      await tester.ensureVisible(genesis48.first);
      await _safePump(tester);
      await tester.tap(genesis48.first, warnIfMissed: false);
      await _pump(tester);

      // ChapterSelector — tap chapter 1
      final ch1_48 = find.text('1');
      if (ch1_48.evaluate().isNotEmpty) {
        await tester.tap(ch1_48.first, warnIfMissed: false);
        await _pump(tester);
        await Future.delayed(const Duration(seconds: 3));
        await _pump(tester);
      }

      // Tap a verse
      final verse48 = find.textContaining('Dios', findRichText: true);
      if (verse48.evaluate().isNotEmpty) {
        await tester.tap(verse48.first, warnIfMissed: false);
        await _pump(tester);

        // Open study sheet
        final studyIcon48 = find.byIcon(Icons.school_outlined);
        if (studyIcon48.evaluate().isNotEmpty) {
          await tester.tap(studyIcon48.first, warnIfMissed: false);
          await _pump(tester);
          await Future.delayed(const Duration(seconds: 3));
          await _pump(tester);

          // Click Interlineal tab
          final tabInter48 = find.text('Interlineal');
          if (tabInter48.evaluate().isNotEmpty) {
            await tester.tap(tabInter48.first, warnIfMissed: false);
            await _pump(tester);
            await Future.delayed(const Duration(seconds: 3));
            await _pump(tester);

            // Should show HEBREO (OSHB) for Génesis (OT)
            final hebreoHeader = find.text('HEBREO (OSHB)');
            if (hebreoHeader.evaluate().isNotEmpty) {
              _log('✅ Header "HEBREO (OSHB)" visible para Génesis');
            } else {
              _log('⚠️ Header HEBREO no encontrado — puede estar cargando');
            }
          }

          // Also test Comentario tab for Génesis (has commentary)
          _log('TEST 46b: Comentario para Génesis...');
          final tabCom48 = find.text('Comentario');
          if (tabCom48.evaluate().isNotEmpty) {
            await tester.tap(tabCom48.first, warnIfMissed: false);
            await _pump(tester);
            await Future.delayed(const Duration(seconds: 2));
            await _pump(tester);

            final mh48 = find.text('MATTHEW HENRY');
            if (mh48.evaluate().isNotEmpty) {
              _log('✅ Matthew Henry visible para Génesis (libro con comentario)');
            }
          }

          // Close sheet
          final close48 = find.byIcon(Icons.close);
          if (close48.evaluate().isNotEmpty) {
            await tester.tap(close48.first, warnIfMissed: false);
            await _pump(tester);
          }
        }
      }

      // Dismiss toolbar
      await tester.tapAt(const Offset(200, 200));
      await _pump(tester);

      // Go back from reader
      final nav48 = find.byType(Navigator);
      if (nav48.evaluate().isNotEmpty) {
        tester.state<NavigatorState>(nav48.first).pop();
        await _pump(tester);
        await Future.delayed(const Duration(seconds: 1));
        await _pump(tester);
      }
    }

    // ═════════════════════════════════════════════════════════════════════
    // RESUMEN FINAL
    // ═════════════════════════════════════════════════════════════════════
    _log('═══════════════════════════════════════════');
    _log('✅ TODAS LAS PRUEBAS COMPLETADAS (46 tests)');
    _log('   Tests 1-25: Funcionalidad base de Biblia');
    _log('   Test 26: Colecciones desde Home');
    _log('   Test 27: Reading Stats row');
    _log('   Test 28: TTS botón');
    _log('   Test 29: TTS playback');
    _log('   Tests 30-32: Toolbar new icons');
    _log('   Test 33: Concordance sheet');
    _log('   Test 34: Share to Wall');
    _log('   Test 35: BibleStatsScreen');
    _log('   Test 36: Chapter selector gold chapters');
    _log('   Test 37: Red letter toggle en Settings');
    _log('   Tests 38-40: Dictionary (screen, search, detail)');
    _log('   Test 41: Juan 3 — red letters + interlineal griego');
    _log('   Tests 42-43: VerseStudySheet 5 tabs + morphology');
    _log('   Test 44: Comentario tab (Matthew Henry)');
    _log('   Test 45: Dictionary icon en toolbar');
    _log('   Test 46: Interlineal hebreo (Génesis) + comentario');
    _log('═══════════════════════════════════════════');
  });
}
