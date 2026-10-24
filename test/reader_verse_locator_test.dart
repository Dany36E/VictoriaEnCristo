import 'package:app_quitar/widgets/bible/reader/reader_verse_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimateOffset', () {
    test('interpola entre versículos medidos', () {
      final r = ReaderVerseLocator.estimateOffset(15, {10: 1000, 20: 2000});
      expect(r, 1500);
    });

    test('extrapola con la altura media medida', () {
      final r = ReaderVerseLocator.estimateOffset(40, {10: 1000, 20: 2000});
      expect(r, 4000);
      final up = ReaderVerseLocator.estimateOffset(5, {10: 1000, 20: 2000});
      expect(up, 500);
    });

    test('un solo punto usa la altura de respaldo', () {
      final r = ReaderVerseLocator.estimateOffset(12, {
        10: 1000,
      }, fallbackPerVerse: 50);
      expect(r, 1100);
      expect(ReaderVerseLocator.estimateOffset(3, {}), isNull);
    });
  });

  test('firstVisibleFrom elige el primero que se ve bajo la cabecera', () {
    final m = {
      1: (top: 0.0, height: 100.0),
      2: (top: 100.0, height: 100.0),
      3: (top: 200.0, height: 100.0),
    };
    expect(ReaderVerseLocator.firstVisibleFrom(m, 64), 1);
    expect(ReaderVerseLocator.firstVisibleFrom(m, 150), 2);
    // El 2 apenas asoma (4 px): se considera el 3.
    expect(ReaderVerseLocator.firstVisibleFrom(m, 196), 3);
  });

  testWidgets('lleva exactamente al versículo pedido en una lista perezosa', (
    tester,
  ) async {
    final locator = ReaderVerseLocator();
    final controller = ScrollController();
    // Alturas muy distintas (versículos cortos y largos, títulos).
    double heightOf(int v) => 40.0 + (v * 37 % 160);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: controller,
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final verse = i + 1;
                  return KeyedSubtree(
                    key: locator.keyFor(verse),
                    child: SizedBox(
                      height: heightOf(verse),
                      child: Text('v$verse'),
                    ),
                  );
                }, childCount: 176),
              ),
            ],
          ),
        ),
      ),
    );

    for (final target in [150, 40, 176, 2]) {
      final done = locator.scrollToVerse(controller, target, topInset: 64);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(await done, isTrue, reason: 'versículo $target');
      final measured = locator.measureBuilt()[target]!;
      final expected = (measured.top - 64).clamp(
        0.0,
        controller.position.maxScrollExtent,
      );
      expect(
        controller.offset,
        moreOrLessEquals(expected, epsilon: 1),
        reason: 'versículo $target',
      );
      expect(find.text('v$target'), findsOneWidget);
    }
  });
}
