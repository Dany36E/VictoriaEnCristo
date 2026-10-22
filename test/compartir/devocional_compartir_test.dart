import 'package:app_quitar/screens/devotional_screen.dart';
import 'package:app_quitar/services/bible/bible_user_data_service.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:app_quitar/widgets/compartir/tarjeta_compartir_papel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual/theme_matrix.dart';

/// La imagen del Devocional se captura de una tarjeta que está en el árbol
/// pero fuera de la vista. Con Opacity(0) no se pintaba y «Compartir → Como
/// imagen» fallaba en silencio.
void main() {
  setUpThemeMatrix();

  for (final tema in ['papel', 'papel_kraft']) {
    testWidgets('el Devocional se puede capturar como imagen ($tema)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      BibleUserDataService.I.readerThemeNotifier.value = tema;
      await tester.runAsync(() => ThemeService().setTheme(tema));
      final theme = AppThemeData.all.firstWhere((t) => t.id == tema);
      await tester.pumpWidget(
        MaterialApp(
          home: AppThemeData.provider(
            theme: theme,
            child: const DevotionalScreen(),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      final tarjeta = find.byType(TarjetaCompartirPapel);
      expect(tarjeta, findsOneWidget);
      final limite = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(of: tarjeta, matching: find.byType(RepaintBoundary))
            .first,
      );
      expect(limite.debugNeedsPaint, isFalse);
      final (ancho, alto) = (await tester.runAsync(() async {
        final imagen = await limite.toImage(pixelRatio: 3);
        final medidas = (imagen.width, imagen.height);
        imagen.dispose();
        return medidas;
      }))!;
      // 360×450 lógicos a 3x, aunque la pantalla sea más chica.
      expect((ancho, alto), (1080, 1350));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    });
  }
}
