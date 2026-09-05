import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app_quitar/screens/series/series_home_screen.dart';
import 'package:app_quitar/screens/series/series_detail_screen.dart';
import 'package:app_quitar/services/series_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native series catalog, all seasons, back navigation', (
    tester,
  ) async {
    final catalog = await SeriesService.I.loadSeries();
    expect(catalog, isNotEmpty);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const SeriesHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot('series_native_catalog');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(catalog.first.title));
    await tester.pumpAndSettle();
    expect(find.byType(SeriesDetailScreen), findsOneWidget);
    await binding.takeScreenshot('series_native_detail');
    for (final season in catalog.first.seasons) {
      final title = find.text(season.title);
      await tester.scrollUntilVisible(
        title,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(title), alignment: 0.5);
      await tester.pumpAndSettle();
      if (season != catalog.first.seasons.first) {
        await tester.tap(title);
        await tester.pumpAndSettle();
      }
      expect(find.text(season.episodes.first.title), findsOneWidget);
      await binding.takeScreenshot('series_native_season_${season.number}');
      expect(tester.takeException(), isNull);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.text(season.episodes.first.title), findsNothing);
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SeriesHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
