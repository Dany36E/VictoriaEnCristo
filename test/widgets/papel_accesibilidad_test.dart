import 'dart:io';

import 'package:app_quitar/screens/emotional_verse_jar_screen.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:app_quitar/vec/vec_widgets.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase's own test transport; no calls reach a remote backend.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _papel(Widget child) => MaterialApp(
  theme: AppTheme.paperTheme,
  builder: (context, c) =>
      AppThemeData.provider(theme: AppThemeData.paper, child: c!),
  home: child,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'app_theme_id': 'papel'});
    await ThemeService().initialize();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });

  testWidgets('BotonVec se puede activar con TalkBack/VoiceOver', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var toques = 0;
    await tester.pumpWidget(
      _papel(
        Scaffold(
          body: Center(
            child: BotonVec(texto: 'Guardar', onPressed: () => toques++),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(BotonVec)),
      isSemantics(label: 'Guardar', isButton: true, hasTapAction: true),
    );
    tester.semantics.tap(find.semantics.byLabel('Guardar'));
    await tester.pump();
    expect(toques, 1);
    semantics.dispose();
  });

  testWidgets('BotonVec deshabilitado no ofrece la acción de tocar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _papel(
        const Scaffold(
          body: Center(child: BotonVec(texto: 'Guardar', onPressed: null)),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(BotonVec)),
      isSemantics(label: 'Guardar', isEnabled: false, hasTapAction: false),
    );
    semantics.dispose();
  });

  testWidgets('el versículo del frasco se ve mientras se desdobla', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_papel(const EmotionalVerseJarScreen()));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Feliz'));
    // 400 ms de espera + mitad del despliegue (800 ms)
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TarjetaVersiculo), findsOneWidget);

    // el frasco brilla en bucle: no hay pumpAndSettle posible
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
