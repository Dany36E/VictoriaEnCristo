import 'package:app_quitar/screens/home_screen.dart';
import 'package:app_quitar/services/daily_practice_service.dart';
import 'package:app_quitar/services/daily_verse_service.dart';
import 'package:app_quitar/services/day_change_service.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:app_quitar/utils/time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual/theme_matrix.dart';

/// Inicio abierto (o en segundo plano) al pasar la medianoche: debe mostrar
/// el versículo y las prácticas del día nuevo, no los de ayer.
void main() {
  setUpThemeMatrix();

  tearDown(() => TimeUtils.relojParaPruebas = null);

  testWidgets('Inicio refresca versículo y prácticas al cambiar de día', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Antes de las 5:00 para que no se abra el check-in matutino.
    var ahora = DateTime(2026, 10, 22, 21, 0);
    TimeUtils.relojParaPruebas = () => ahora;
    final ayer = DailyVerseService.referenciaParaFecha(ahora);
    final manana = DailyVerseService.referenciaParaFecha(
      DateTime(2026, 10, 23),
    );
    expect(manana.referencia, isNot(ayer.referencia));

    await tester.runAsync(() async {
      await DailyPracticeService.I.init();
      await DailyPracticeService.I.mark(DailyPractice.devotional);
    });
    // El servicio de cambio de día toma la fecha «de ayer» como referencia.
    DayChangeService.I.comprobar();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.paperTheme,
        builder: (context, child) =>
            AppThemeData.provider(theme: AppThemeData.paper, child: child!),
        home: const HomeScreen(),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(
      find.textContaining(ayer.referencia, findRichText: true),
      findsWidgets,
    );
    expect(DailyPracticeService.I.snapshotNotifier.value.devotional, isTrue);

    // Pasa la medianoche (la app vuelve del fondo o el temporizador dispara).
    ahora = DateTime(2026, 10, 23, 2, 0);
    expect(DayChangeService.I.comprobar(), isTrue);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(
      find.textContaining(manana.referencia, findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining(ayer.referencia, findRichText: true),
      findsNothing,
    );
    // El devocional de ayer ya no aparece como completado hoy.
    expect(DailyPracticeService.I.snapshotNotifier.value.devotional, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });
}
