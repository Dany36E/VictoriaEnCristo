import 'package:flutter/material.dart';
import 'package:app_quitar/services/theme_service.dart';
import 'package:app_quitar/theme/app_fonts.dart';
import 'package:app_quitar/theme/bible_reader_theme.dart';
import 'package:app_quitar/theme/contraste.dart';
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

  test('el texto tenue y atenuado del lector se lee en todos los temas', () {
    // Los papeles oscuros no están en la lista (el lector sigue al papel de
    // la app), pero también se revisan.
    for (final t in [
      ...BibleReaderThemeData.all,
      BibleReaderThemeData.paperKraft,
      BibleReaderThemeData.paperNoche,
    ]) {
      for (final alpha in [0.2, 0.4, 0.6, 0.95]) {
        expect(
          contrasteWcag(t.textoTenue(alpha), t.fondoVisible),
          greaterThanOrEqualTo(4.5),
          reason: '${t.id}: textoTenue($alpha)',
        );
      }
      expect(
        contrasteWcag(t.textoAtenuado(), t.fondoVisible),
        greaterThanOrEqualTo(4.5),
        reason: '${t.id}: textoAtenuado()',
      );
    }
    // Si el gris ya se lee (el lápiz del papel), se queda como está.
    final papel = BibleReaderThemeData.paper;
    expect(papel.textoTenue(1).toARGB32(), papel.textSecondary.toARGB32());
  });
}
