import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_quitar/screens/journal_screen.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'visual_checks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
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
  });

  for (final theme in AppThemeData.all) {
    testWidgets('diario en tema ${theme.id}: botones y contraste', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) =>
              AppThemeData.provider(theme: theme, child: child!),
          home: RepaintBoundary(key: boundaryKey, child: const JournalScreen()),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Guardar la captura antes de las comprobaciones, aunque fallen.
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/qa/journal_${theme.id}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });

      expect(
        tester.takeException(),
        isNull,
        reason: 'La pantalla no debe desbordarse',
      );
      expectButtonBackgroundsCoverContent(tester);
      await expectReadableText(tester);
    });
  }
}
