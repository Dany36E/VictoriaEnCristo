import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_quitar/models/series.dart';
import 'package:app_quitar/screens/series/series_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Logical viewports, not claims of native-device execution.
const profiles = <String, Size>{
  'phone_small': Size(320, 568),
  'android_compact': Size(360, 800),
  'iphone_large': Size(430, 932),
  'ipad_portrait': Size(768, 1024),
  'ipad_landscape': Size(1024, 768),
  'windows': Size(1366, 768),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('google_fonts/Manrope-VariableFont_wght.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  final json = jsonDecode(File('assets/content/series.json').readAsStringSync())
      as Map<String, dynamic>;
  final series = VideoSeries.fromJson(
    (json['series'] as List).first as Map<String, dynamic>,
  );
  for (final profile in profiles.entries) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('${profile.key} text $scale: series layout and seasons',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = profile.value;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark(useMaterial3: true).copyWith(
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Manrope'),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundaryKey,
            child: SeriesDetailScreen(series: series),
          ),
        ));
        await tester.pumpAndSettle();
        // Always save the rendering before asserting, including failed layouts.
        await tester.runAsync(() async {
          final boundary = boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/qa/series_${profile.key}_$scale.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull,
            reason: 'Initial screen must not overflow');
        for (final season in series.seasons) {
          final title = find.text(season.title);
          await tester.scrollUntilVisible(title, 250,
              scrollable: find.byType(Scrollable).first);
          await Scrollable.ensureVisible(tester.element(title), alignment: 0.5);
          await tester.pumpAndSettle();
          if (season.number != series.seasons.first.number) {
            await tester.tap(title);
            await tester.pumpAndSettle();
          }
          expect(find.text(season.episodes.first.title), findsOneWidget,
              reason: 'Expanded season must actually expose its episodes');
          expect(tester.takeException(), isNull,
              reason: 'Season ${season.number} must open without layout errors');
          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(find.text(season.episodes.first.title), findsNothing,
              reason: 'Collapsed season must hide its episodes');
        }
      });
    }
  }
}
