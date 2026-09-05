import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_quitar/screens/login_screen.dart';
import 'package:app_quitar/screens/onboarding/onboarding_welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase's own test transport; no calls reach a remote backend.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'series_matrix_test.dart' show profiles;

TargetPlatform platformFor(String profile) => switch (profile) {
  'iphone_large' || 'ipad_portrait' || 'ipad_landscape' => TargetPlatform.iOS,
  'windows' => TargetPlatform.windows,
  _ => TargetPlatform.android,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
    for (final entry in {
      'Manrope': 'google_fonts/Manrope-VariableFont_wght.ttf',
      'Cinzel': 'google_fonts/Cinzel-VariableFont_wght.ttf',
      'Lato': 'google_fonts/Lato-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
      if (entry.key != 'MaterialIcons' && entry.key != 'Lato') {
        for (final weight in FontWeight.values) {
          final family = GoogleFonts.getFont(
            entry.key,
            fontWeight: weight,
          ).fontFamily!;
          await (FontLoader(
            family,
          )..addFont(rootBundle.load(entry.value))).load();
        }
      }
    }
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  Future<void> capture(
    WidgetTester tester,
    GlobalKey boundaryKey,
    String name,
  ) async {
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final profile in profiles.entries) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('${profile.key} text $scale: access and welcome layout', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platformFor(profile.key);
        try {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = profile.value;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final boundaryKey = GlobalKey();
          Widget wrap(Widget screen) => RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark(useMaterial3: true).copyWith(
                textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: 'Manrope',
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: screen,
            ),
          );

          await tester.pumpWidget(wrap(const LoginScreen()));
          await tester.pumpAndSettle();
          await capture(
            tester,
            boundaryKey,
            'access_login_${profile.key}_$scale',
          );
          expect(tester.takeException(), isNull);

          final submit = find.text('INICIAR SESIÓN');
          await tester.ensureVisible(submit);
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(find.text('Ingresa tu correo'), findsOneWidget);
          expect(find.text('Ingresa tu contraseña'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(wrap(const OnboardingWelcomeScreen()));
          await tester.pump(const Duration(milliseconds: 1600));
          await tester.pumpAndSettle();
          final audioToggle = find.byWidgetPredicate(
            (widget) =>
                widget is Icon &&
                (widget.icon == Icons.music_note_rounded ||
                    widget.icon == Icons.music_off_rounded),
          );
          expect(audioToggle, findsOneWidget);
          final audioButton = find
              .ancestor(
                of: audioToggle,
                matching: find.byType(AnimatedContainer),
              )
              .first;
          final audioBounds = tester.getRect(audioButton);
          final scrollBounds = tester.getRect(
            find.byType(SingleChildScrollView),
          );
          expect(
            scrollBounds.top,
            greaterThanOrEqualTo(audioBounds.bottom),
            reason:
                'Scrollable content must stay below the floating audio toggle',
          );
          final start = find.text('ELEGIR MIS GIGANTES');
          await Scrollable.ensureVisible(tester.element(start), alignment: 0.5);
          await tester.pumpAndSettle();
          expect(start.hitTestable(), findsOneWidget);
          await capture(
            tester,
            boundaryKey,
            'access_welcome_${profile.key}_$scale',
          );
          expect(tester.takeException(), isNull);
        } finally {
          // CachedNetworkImage's test cache schedules a one-shot cleanup.
          // Dispose the screens and advance fake time so it cannot leak into
          // the test binding's timer invariant.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 11));
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
