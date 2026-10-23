import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/vec/vec_tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../visual/theme_matrix.dart';

void main() {
  setUpThemeMatrix();

  Future<SharedPreferences> iniciar(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    await ThemeService().initialize();
    return SharedPreferences.getInstance();
  }

  group('migración de los temas de antes', () {
    for (final (antes, modo, papel) in [
      (<String, Object>{}, ModoTema.claro, 'papel'),
      ({'app_theme_id': 'night_pure'}, ModoTema.oscuro, 'papel_kraft'),
      ({'app_theme_id': 'charcoal_editorial'}, ModoTema.oscuro, 'papel_kraft'),
      ({'app_theme_id': 'sepia_night'}, ModoTema.oscuro, 'papel_kraft'),
      ({'app_theme_id': 'clean_page'}, ModoTema.claro, 'papel'),
      ({'app_theme_id': 'lavender'}, ModoTema.claro, 'papel'),
      ({'app_theme_id': 'papel'}, ModoTema.claro, 'papel'),
      ({'app_theme_id': 'papel_noche'}, ModoTema.oscuro, 'papel_noche'),
      ({'theme_mode': 2}, ModoTema.oscuro, 'papel_kraft'),
    ]) {
      testWidgets('$antes → ${modo.name} ($papel)', (tester) async {
        final prefs = (await tester.runAsync(() => iniciar(antes)))!;
        final ts = ThemeService();
        expect(ts.modo, modo);
        expect(ts.themeId, papel);
        expect(VecColores.actual, ts.currentTheme.paleta);
        // Queda guardado con las claves nuevas.
        expect(prefs.getString('tema_modo'), modo.name);
      });
    }

    testWidgets('el tema automático por hora pasa a seguir al teléfono', (
      tester,
    ) async {
      await tester.runAsync(
        () => iniciar({'app_theme_id': 'night_pure', 'auto_theme': true}),
      );
      expect(ThemeService().modo, ModoTema.automatico);
    });

    testWidgets('otra cuenta sin tema no hereda el papel de la anterior', (
      tester,
    ) async {
      await tester.runAsync(
        () => iniciar({
          'tema_modo': 'oscuro',
          'tema_papel_oscuro': 'papel_noche',
        }),
      );
      expect(ThemeService().themeId, 'papel_noche');
      // Cerrar sesión borra las claves; la cuenta nueva no trae tema.
      final prefs = (await tester.runAsync(() => iniciar({})))!;
      expect(ThemeService().modo, ModoTema.claro);
      expect(ThemeService().papelOscuro, 'papel_kraft');
      expect(prefs.getString('tema_papel_oscuro'), 'papel_kraft');
    });

    testWidgets('initialize varias veces no cambia la elección', (
      tester,
    ) async {
      await tester.runAsync(
        () => iniciar({
          'tema_modo': 'automatico',
          'tema_papel_oscuro': 'papel_noche',
        }),
      );
      await tester.runAsync(() => ThemeService().initialize());
      await tester.runAsync(() => ThemeService().initialize());
      expect(ThemeService().modo, ModoTema.automatico);
      expect(ThemeService().papelOscuro, 'papel_noche');
    });

    testWidgets('con las claves nuevas no se vuelve a migrar', (tester) async {
      await tester.runAsync(
        () => iniciar({
          'tema_modo': 'oscuro',
          'tema_papel_oscuro': 'papel_noche',
          'app_theme_id': 'clean_page',
        }),
      );
      expect(ThemeService().themeId, 'papel_noche');
    });
  });

  testWidgets('modo y papel oscuro se guardan y cambian el tema', (
    tester,
  ) async {
    final prefs = (await tester.runAsync(() => iniciar({})))!;
    final ts = ThemeService();
    await tester.runAsync(() => ts.setPapelOscuro('papel_noche'));
    // En claro, elegir el papel oscuro no cambia lo que se ve.
    expect(ts.themeId, 'papel');
    await tester.runAsync(() => ts.setModo(ModoTema.oscuro));
    expect(ts.themeId, 'papel_noche');
    expect(VecColores.actual, VecPaleta.nocheAzul);
    expect(prefs.getString('tema_modo'), 'oscuro');
    expect(prefs.getString('tema_papel_oscuro'), 'papel_noche');
    await tester.runAsync(() => ts.setModo(ModoTema.claro));
    expect(VecColores.actual, VecPaleta.claro);
  });

  testWidgets('automático sigue el modo del teléfono', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.runAsync(
      () => iniciar({
        'tema_modo': 'automatico',
        'tema_papel_oscuro': 'papel_kraft',
      }),
    );
    final ts = ThemeService();
    expect(ts.themeId, 'papel');

    var avisos = 0;
    void contar() => avisos++;
    ts.addListener(contar);
    addTearDown(() => ts.removeListener(contar));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    expect(ts.themeId, 'papel_kraft');
    expect(VecColores.actual, VecPaleta.kraftOscuro);
    expect(avisos, 1);

    // En claro u oscuro fijo, el teléfono no lo cambia.
    await tester.runAsync(() => ts.setModo(ModoTema.claro));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    expect(ts.themeId, 'papel');
  });
}
