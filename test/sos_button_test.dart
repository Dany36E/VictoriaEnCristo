import 'package:app_quitar/vec/vec_widgets.dart';
import 'package:app_quitar/widgets/home/sos_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BreathingSosButton renders with accessible emergency label', (tester) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BreathingSosButton())),
      ),
    );
    // Aparece con PopIn después de 300 ms.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('¡Necesito ayuda!'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(BotonVec)),
      isSemantics(label: '¡Necesito ayuda!', isButton: true, hasTapAction: true),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    semantica.dispose();
  });
}
