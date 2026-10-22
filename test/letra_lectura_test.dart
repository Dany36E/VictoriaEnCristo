import 'package:flutter/material.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_fonts.dart';
import 'package:app_quitar/theme/bible_reader_theme.dart';
import 'package:app_quitar/vec/vec_tema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app_theme_id': 'papel'});
    await ThemeService().initialize();
  });

  tearDown(() async {
    await ThemeService().setLecturaManuscrita(false);
  });

  test('en el tema papel los versículos se leen en Lora por defecto', () {
    expect(ThemeService().lecturaManuscrita.value, isFalse);
    expect(AppFonts.lora(fontSize: 16).fontFamily, startsWith('Lora'));
    expect(AppFonts.crimsonPro(fontSize: 16).fontFamily, startsWith('CrimsonPro'));
    // Títulos y botones siguen con la letra del kit.
    expect(
      AppFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700).fontFamily,
      VecFuentes.titulo,
    );
  });

  test('con la letra manuscrita elegida se usa la del kit y se recuerda', () async {
    await ThemeService().setLecturaManuscrita(true);
    final estilo = AppFonts.lora(fontSize: 16);
    expect(estilo.fontFamily, VecFuentes.texto);
    expect(estilo.fontSize, closeTo(16 * 1.15, 0.01));

    await ThemeService().initialize();
    expect(ThemeService().lecturaManuscrita.value, isTrue);
  });

  test('las letras del kit caen en Manrope para las flechas', () {
    expect(
      AppFonts.cinzel(fontSize: 14).fontFamilyFallback,
      contains('Manrope'),
    );
  });

  test('el texto tenue del lector no se pierde sobre el papel', () {
    const papel = BibleReaderThemeData.paper;
    expect(papel.textoTenue(0.3).a, closeTo(0.85, 0.01));
    expect(papel.textoTenue(0.95).a, closeTo(0.95, 0.01));
    expect(BibleReaderThemeData.nightPure.textoTenue(0.3).a, closeTo(0.3, 0.01));
  });
}
