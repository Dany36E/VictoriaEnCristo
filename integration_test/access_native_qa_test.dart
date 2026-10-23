import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app_quitar/screens/login_screen.dart';
import 'package:app_quitar/screens/onboarding/onboarding_welcome_screen.dart';
import 'package:app_quitar/screens/onboarding/giant_selection_screen.dart';
import 'package:app_quitar/screens/onboarding/onboarding_papel.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:app_quitar/vec/vec_widgets.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  bool converted = false;
  // Host environment variables are not forwarded into Android/iOS app
  // processes. CI passes QA_TEXT_SCALE with --dart-define so each emulator
  // job really executes only its assigned scale. Keep Platform.environment as
  // a local desktop fallback.
  const definedScale = String.fromEnvironment('QA_TEXT_SCALE');
  final requestedScale = double.tryParse(
    definedScale.isNotEmpty
        ? definedScale
        : (Platform.environment['QA_TEXT_SCALE'] ?? ''),
  );
  final scales = requestedScale == null ? const [1.0, 1.6] : [requestedScale];
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
  for (final scale in scales) {
    testWidgets('Native access and welcome text $scale', (tester) async {
      converted = false;
      Widget wrap(Widget screen) => MaterialApp(
        debugShowCheckedModeBanner: false,
        // Como la app: tema papel y la hoja con textura detrás.
        theme: AppTheme.paperTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: AppThemeData.provider(
            theme: AppThemeData.paper,
            child: FondoPapel(child: child!),
          ),
        ),
        home: screen,
      );
      await tester.pumpWidget(wrap(const LoginScreen()));
      await tester.pumpAndSettle();
      await capture(tester, 'login_$scale');
      final submit = find.text('Iniciar sesión');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Ingresa tu correo'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
      await capture(tester, 'login_validation_$scale');
      // Android's software-rendered CI emulator can disconnect when the IME
      // animates while the Flutter surface is converted for screenshots. The
      // editing state remains covered by widget matrices and Apple simulators;
      // keep this native Android suite focused on layout and navigation.
      if (!Platform.isAndroid) {
        final email = find.widgetWithText(TextFormField, 'Correo electrónico');
        await tester.ensureVisible(email);
        await tester.tap(email);
        await tester.enterText(email, 'correo-invalido');
        await tester.pumpAndSettle();
        await capture(tester, 'login_editing_$scale');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
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
      final audioBounds = tester.getRect(find.byType(BotonAudioPapel));
      // Al abrir, el letrero empieza debajo del botón de música. Al
      // desplazar, la hoja pasa por detrás del botón (es a propósito).
      final letreroBounds = tester.getRect(find.byType(Letrero));
      expect(
        letreroBounds.top,
        greaterThanOrEqualTo(audioBounds.bottom),
        reason: 'El letrero empieza debajo del botón de música',
      );
      final start = find.text('Elegir mis gigantes');
      await Scrollable.ensureVisible(tester.element(start), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(start.hitTestable(), findsOneWidget);
      await capture(tester, 'welcome_action_$scale');
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('¿Cuál es tu gigante?'), findsOneWidget);
      await capture(tester, 'giant_selection_$scale');

      // Sin elegir, el botón está apagado: tocarlo no avanza.
      final disabledContinue = find.text('Selecciona al menos uno');
      await tester.tap(disabledContinue);
      await tester.pumpAndSettle();
      expect(find.byType(GiantSelectionScreen), findsOneWidget);

      final digital = find.text('MUNDO DIGITAL');
      final giantList = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(digital, 200, scrollable: giantList);
      await tester.pumpAndSettle();
      expect(digital.hitTestable(), findsOneWidget);
      await tester.tap(digital);
      await tester.pumpAndSettle();
      final continueButton = find.text('Continuar (1)');
      expect(continueButton, findsOneWidget);
      // La tarjeta elegida lleva la palomita del kit.
      expect(
        find.byWidgetPredicate(
          (w) => w is CirculoIcono && w.iconoVec == 'palomita',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      expect(continueButton.hitTestable(), findsOneWidget);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('¿Con qué frecuencia luchas?'), findsOneWidget);
      // Con letra grande y pantalla chica, «Diario» puede no estar
      // construido todavía en la lista: se baja hasta encontrarlo.
      final daily = find.text('Diario');
      await tester.scrollUntilVisible(
        daily,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(daily), alignment: 0.35);
      await tester.pumpAndSettle();
      expect(daily.hitTestable(), findsOneWidget);
      await tester.tap(daily);
      await tester.pumpAndSettle();
      // Con letra grande el contador queda arriba, fuera de la lista
      // construida: se vuelve a subir para verlo.
      await tester.scrollUntilVisible(
        find.text('1 de 1 configurados'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1 de 1 configurados'), findsOneWidget);
      expect(find.text('Guardar y continuar'), findsOneWidget);
      await capture(tester, 'giant_frequency_$scale');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
