import 'dart:convert';

import 'package:app_quitar/data/bible_verses.dart';
import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/services/daily_verse_service.dart';
import 'package:app_quitar/services/widget_snapshot_renderer.dart';
import 'package:app_quitar/services/widget_sync_service.dart';
import 'package:app_quitar/utils/time_utils.dart';
import 'package:app_quitar/vec/vec_tema.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Datos para los widgets nativos', () {
    test('la lista de versículos lleva el texto completo y la cita', () {
      const largo =
          'Porque de tal manera amó Dios al mundo, que ha dado a su Hijo '
          'unigénito, para que todo aquel que en él cree, no se pierda, mas '
          'tenga vida eterna.';
      final json = WidgetSyncService.jsonVersiculos([
        (
          fecha: '2026-10-24',
          verse: const BibleVerse(
            verse: largo,
            reference: 'Juan 3:16',
            category: 'amor',
            version: 'RVR1960',
          ),
        ),
      ]);
      final lista = jsonDecode(json) as List;
      expect(lista, hasLength(1));
      final d = lista.first as Map;
      expect(d['f'], '2026-10-24');
      expect(d['t'], largo); // sin recortar
      expect(d['r'], 'Juan 3:16');
      expect(d['v'], 'RVR1960');
    });

    test('la paleta usa los colores del papel activo', () {
      final claro = WidgetSyncService.datosPaleta(VecPaleta.claro);
      expect(claro['vec_oscuro'], false);
      expect(claro['vec_papel'], '#FFFBF7EE');
      expect(claro['vec_terracota'], '#FFA8452F');
      final kraft = WidgetSyncService.datosPaleta(VecPaleta.kraftOscuro);
      expect(kraft['vec_oscuro'], true);
      expect(kraft['vec_papel'], '#FF3A2E24');
      expect(kraft['vec_tinta'], '#FFF3ECDF');
    });
  });

  group('Versículos de los próximos días', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() {
      TimeUtils.relojParaPruebas = null;
      DailyVerseService.I.configurarParaPruebas();
    });

    test('da un versículo completo por día, igual que el de la app', () async {
      final hoy = DateTime(2026, 10, 24, 9);
      TimeUtils.relojParaPruebas = () => hoy;
      DailyVerseService.I.configurarParaPruebas(
        versionActiva: () => BibleVersion.rvr1960,
      );
      final dias = await DailyVerseService.I.proximosDias(14);
      expect(dias, hasLength(14));
      expect(dias.first.fecha, '2026-10-24');
      expect(dias[8].fecha, '2026-11-01');
      final deHoy = await DailyVerseService.I.getForToday();
      expect(dias.first.verse.verse, deHoy.verse);
      expect(dias.first.verse.reference, deHoy.reference);
      for (final d in dias) {
        expect(d.verse.verse, isNotEmpty);
        expect(d.verse.reference, isNotEmpty);
        expect(
          d.verse.reference,
          DailyVerseService.referenciaParaFecha(
            DateTime.parse(d.fecha),
          ).referencia,
        );
      }
    });
  });

  group('Imagen de la tarjeta de racha', () {
    testWidgets('se dibuja a PNG en sus dos formas', (tester) async {
      // La letra de pruebas desborda la fila de la racha: no importa aquí.
      final onError = FlutterError.onError;
      FlutterError.onError = (_) {};
      addTearDown(() => FlutterError.onError = onError);
      await tester.runAsync(() async {
        for (final ancha in [true, false]) {
          final png = await WidgetSnapshotRenderer.renderPng(
            WidgetSyncService.tarjetaRachaParaWidget(
              apaisada: ancha,
              streakDays: 7,
              completedToday: true,
              victoryToday: true,
              isNewUser: false,
              checkinDone: false,
              puedeRegistrar: false,
              mensaje: 'Sigue firme.',
            ),
            logicalSize: ancha
                ? WidgetSyncService.tamanoRachaAncha
                : WidgetSyncService.tamanoRachaAlta,
            pixelRatio: 1,
            pasadas: 2,
          );
          expect(png, isNotNull);
          // Firma PNG.
          expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
          expect(png.length, greaterThan(1000));
        }
      });
    });

    // La letra de pruebas (cuadros de 1 em) es mucho más ancha que Lilita
    // One: aquí solo se revisa que la tarjeta ancha se achique para caber.
    testWidgets('la tarjeta ancha cabe sin desbordarse', (tester) async {
      for (final ancha in [true]) {
        final size = ancha
            ? WidgetSyncService.tamanoRachaAncha
            : WidgetSyncService.tamanoRachaAlta;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox.fromSize(
                size: size,
                child: WidgetSyncService.tarjetaRachaParaWidget(
                  apaisada: ancha,
                  streakDays: 123,
                  completedToday: false,
                  victoryToday: false,
                  isNewUser: false,
                  checkinDone: false,
                  puedeRegistrar: true,
                  mensaje:
                      'Un mensaje largo de ánimo para ver que la tarjeta '
                      'recorta el texto en vez de desbordarse del widget.',
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Registrar día'), findsOneWidget);
      }
    });
  });
}
