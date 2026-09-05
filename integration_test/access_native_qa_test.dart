import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app_quitar/screens/login_screen.dart';
import 'package:app_quitar/screens/onboarding/onboarding_welcome_screen.dart';
import 'package:app_quitar/screens/onboarding/giant_selection_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  bool converted = false;
  Future<void> capture(WidgetTester tester, String name) async {
    if (Platform.isAndroid && !converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot(name);
    expect(tester.takeException(), isNull);
  }

  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  for (final scale in [1.0, 1.6]) {
    testWidgets('Native access and welcome text $scale', (tester) async {
      converted = false;
      Widget wrap(Widget screen) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      );
      await tester.pumpWidget(wrap(const LoginScreen()));
      await tester.pumpAndSettle();
      await capture(tester, 'login_$scale');
      final submit = find.text('INICIAR SESIÓN');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Ingresa tu correo'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
      await capture(tester, 'login_validation_$scale');
      final email = find.widgetWithText(TextFormField, 'Correo electrónico');
      await tester.ensureVisible(email);
      await tester.tap(email);
      await tester.enterText(email, 'correo-invalido');
      await tester.pumpAndSettle();
      await capture(tester, 'login_editing_$scale');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.pumpWidget(wrap(const OnboardingWelcomeScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await capture(tester, 'welcome_$scale');
      final audioToggle = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            (widget.icon == Icons.music_note_rounded ||
                widget.icon == Icons.music_off_rounded),
      );
      expect(audioToggle, findsOneWidget);
      final audioButton = find
          .ancestor(of: audioToggle, matching: find.byType(AnimatedContainer))
          .first;
      final audioBounds = tester.getRect(audioButton);
      final scrollBounds = tester.getRect(find.byType(SingleChildScrollView));
      expect(
        scrollBounds.top,
        greaterThanOrEqualTo(audioBounds.bottom),
        reason: 'Scrollable content must stay below the floating audio toggle',
      );
      final start = find.text('ELEGIR MIS GIGANTES');
      await Scrollable.ensureVisible(tester.element(start), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(start.hitTestable(), findsOneWidget);
      await capture(tester, 'welcome_action_$scale');
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('¿CUÁL ES TU GIGANTE?'), findsOneWidget);
      await capture(tester, 'giant_selection_$scale');

      final disabledContinue = find.text('SELECCIONA AL MENOS UNO');
      await tester.tap(disabledContinue);
      await tester.pumpAndSettle();
      expect(
        find.text('Selecciona al menos un área de batalla'),
        findsOneWidget,
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(GiantSelectionScreen)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      final digital = find.text('MUNDO DIGITAL');
      final giantList = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        digital,
        200,
        scrollable: giantList,
      );
      await tester.pumpAndSettle();
      expect(digital.hitTestable(), findsOneWidget);
      await tester.tap(digital);
      await tester.pumpAndSettle();
      final continueButton = find.text('CONTINUAR (1)');
      expect(continueButton, findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      expect(continueButton.hitTestable(), findsOneWidget);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('¿CON QUÉ FRECUENCIA LUCHAS?'), findsOneWidget);
      final daily = find.text('Diario');
      await Scrollable.ensureVisible(tester.element(daily), alignment: 0.35);
      await tester.pumpAndSettle();
      expect(daily.hitTestable(), findsOneWidget);
      await tester.tap(daily);
      await tester.pumpAndSettle();
      expect(find.text('1 de 1 configurados'), findsOneWidget);
      expect(find.text('GUARDAR Y CONTINUAR'), findsOneWidget);
      await capture(tester, 'giant_frequency_$scale');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
