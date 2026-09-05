import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_quitar/screens/onboarding/giant_selection_screen.dart';
import 'package:app_quitar/services/onboarding_service.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

import 'access_matrix_test.dart' show platformFor;
import 'series_matrix_test.dart' show profiles;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    await OnboardingService().init();
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final entry in {
      'Manrope': 'google_fonts/Manrope-VariableFont_wght.ttf',
      'Cinzel': 'google_fonts/Cinzel-VariableFont_wght.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
      if (entry.key != 'MaterialIcons') {
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

  Future<void> capture(GlobalKey boundaryKey, String name) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  }

  for (final profile in profiles.entries) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('${profile.key} text $scale: onboarding selection flow', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platformFor(profile.key);
        try {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = profile.value;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData.dark(useMaterial3: true),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const GiantSelectionScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => capture(
              boundaryKey,
              'onboarding_selection_${profile.key}_$scale',
            ),
          );
          expect(tester.takeException(), isNull);

          final disabledContinue = find.text('SELECCIONA AL MENOS UNO');
          expect(disabledContinue, findsOneWidget);
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
          await tester.scrollUntilVisible(
            digital,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(digital),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          await tester.tap(digital);
          await tester.pumpAndSettle();
          expect(find.text('CONTINUAR (1)'), findsOneWidget);
          expect(find.byIcon(Icons.check_rounded), findsOneWidget);
          await tester.runAsync(
            () => capture(
              boundaryKey,
              'onboarding_selected_${profile.key}_$scale',
            ),
          );
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
