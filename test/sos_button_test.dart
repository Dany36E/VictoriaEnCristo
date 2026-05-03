import 'package:app_quitar/widgets/home/sos_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BreathingSosButton renders with accessible emergency label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BreathingSosButton())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final sosSemantics = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Botón de emergencia, necesito ayuda ahora',
    );
    final semanticsWidget = tester.widget<Semantics>(sosSemantics);

    expect(find.text('¡NECESITO AYUDA!'), findsOneWidget);
    expect(sosSemantics, findsOneWidget);
    expect(semanticsWidget.properties.label, 'Botón de emergencia, necesito ayuda ahora');
    expect(semanticsWidget.properties.button, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
