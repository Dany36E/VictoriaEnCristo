import 'dart:io';
import 'dart:math';

import 'package:app_quitar/data/bible_verses.dart';
import 'package:app_quitar/data/versiculos_diarios.dart';
import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/services/daily_verse_service.dart';
import 'package:app_quitar/utils/bible_navigation_helper.dart';
import 'package:app_quitar/utils/time_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

/// Índice (libro, capítulo, versículo) → texto de la RVR1960 incluida.
Map<String, String> _cargarRvr() {
  final doc = XmlDocument.parse(
    File('assets/bible/Reina Valera 1960.xml').readAsStringSync(),
  );
  final textos = <String, String>{};
  for (final libro in doc.findAllElements('book')) {
    final b = libro.getAttribute('number');
    for (final cap in libro.findElements('chapter')) {
      final c = cap.getAttribute('number');
      for (final v in cap.findElements('verse')) {
        textos['$b:$c:${v.getAttribute('number')}'] = v.innerText.trim();
      }
    }
  }
  return textos;
}

String _mayuscula(String t) => t[0].toUpperCase() + t.substring(1);

void main() {
  late Map<String, String> rvr;

  setUpAll(() => rvr = _cargarRvr());

  group('Lista de versículos del día', () {
    test('tiene al menos 366 referencias', () {
      expect(versiculosDiarios.length, greaterThanOrEqualTo(366));
    });

    test('cada referencia existe en la RVR1960 y su texto coincide', () {
      for (final v in versiculosDiarios) {
        expect(v.libro, inInclusiveRange(1, 66), reason: v.referencia);
        expect(v.versoFin, greaterThanOrEqualTo(v.versoInicio));
        final partes = <String>[];
        for (var n = v.versoInicio; n <= v.versoFin; n++) {
          final texto = rvr['${v.libro}:${v.capitulo}:$n'];
          expect(texto, isNotNull, reason: '${v.referencia} no existe');
          expect(texto, isNotEmpty, reason: '${v.referencia} vacío');
          partes.add(texto!);
        }
        expect(
          v.textoRvr,
          _mayuscula(partes.join(' ')),
          reason: 'Texto de respaldo de ${v.referencia}',
        );
      }
    });

    test('no repite versículos', () {
      final vistos = <String>{};
      for (final v in versiculosDiarios) {
        for (var n = v.versoInicio; n <= v.versoFin; n++) {
          expect(
            vistos.add('${v.libro}:${v.capitulo}:$n'),
            isTrue,
            reason: '${v.referencia} repetido',
          );
        }
      }
    });

    test('cubre todos los temas de forma pareja', () {
      final porTema = <TemaVersiculo, int>{};
      for (final v in versiculosDiarios) {
        porTema[v.tema] = (porTema[v.tema] ?? 0) + 1;
      }
      expect(porTema.keys.toSet(), TemaVersiculo.values.toSet());
      for (final n in porTema.values) {
        expect(n, greaterThanOrEqualTo(20));
      }
    });

    test('dos entradas seguidas nunca comparten tema (con vuelta)', () {
      final n = versiculosDiarios.length;
      for (var i = 0; i < n; i++) {
        expect(
          versiculosDiarios[i].tema,
          isNot(versiculosDiarios[(i + 1) % n].tema),
          reason: 'Posiciones $i y ${(i + 1) % n}',
        );
      }
    });

    test('la referencia la entiende el lector de la Biblia', () {
      for (final v in versiculosDiarios) {
        final r = BibleNavigationHelper.parseSpanishRef(v.referencia);
        expect(r, isNotNull, reason: v.referencia);
        expect(r!.bookNumber, v.libro, reason: v.referencia);
        expect(r.chapter, v.capitulo, reason: v.referencia);
      }
    });
  });

  group('Selección por fecha', () {
    test('es determinística y cambia de tema cada día (2 años, DST incl.)', () {
      var dia = DateTime(2025, 1, 1, 12);
      VersiculoDiario? anterior;
      for (var i = 0; i < 731; i++) {
        final ref = DailyVerseService.referenciaParaFecha(dia);
        // Misma fecha a otra hora → mismo versículo (widget/notificación).
        expect(
          DailyVerseService.referenciaParaFecha(
            DateTime(dia.year, dia.month, dia.day, 0, 1),
          ),
          same(ref),
        );
        expect(
          DailyVerseService.referenciaParaFecha(
            DateTime(dia.year, dia.month, dia.day, 23, 59),
          ),
          same(ref),
        );
        if (anterior != null) {
          expect(ref.tema, isNot(anterior.tema), reason: '$dia');
        }
        anterior = ref;
        dia = DateTime(dia.year, dia.month, dia.day + 1, 12);
      }
    });

    test('no se repite el versículo dentro de un año', () {
      final vistos = <String>{};
      var dia = DateTime(2026, 1, 1);
      for (var i = 0; i < 366; i++) {
        final ref = DailyVerseService.referenciaParaFecha(dia).referencia;
        expect(vistos.add(ref), isTrue, reason: '$ref repetido el $dia');
        dia = DateTime(dia.year, dia.month, dia.day + 1);
      }
    });
  });

  group('DailyVerseService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      TimeUtils.relojParaPruebas = null;
      DailyVerseService.I.configurarParaPruebas();
    });

    test('sin otra versión usa el texto RVR1960 de respaldo', () async {
      final fecha = DateTime(2026, 3, 10, 9);
      TimeUtils.relojParaPruebas = () => fecha;
      DailyVerseService.I.configurarParaPruebas(
        versionActiva: () => BibleVersion.rvr1960,
      );
      final v = await DailyVerseService.I.getForToday();
      final ref = DailyVerseService.referenciaParaFecha(fecha);
      expect(v.reference, ref.referencia);
      expect(v.verse, ref.textoRvr);
      expect(v.version, BibleVersion.rvr1960.shortName);
    });

    test('carga el texto de la versión activa y lo cachea', () async {
      final fecha = DateTime(2026, 3, 10, 9);
      TimeUtils.relojParaPruebas = () => fecha;
      var llamadas = 0;
      DailyVerseService.I.configurarParaPruebas(
        versionActiva: () => BibleVersion.nvi,
        cargador: (ref, version) async {
          llamadas++;
          return 'texto ${version.id} de ${ref.referencia}';
        },
      );
      final ref = DailyVerseService.referenciaParaFecha(fecha);
      final v = await DailyVerseService.I.getForToday();
      expect(v.verse, 'Texto NVI de ${ref.referencia}');
      expect(v.version, 'NVI');
      // Ya en caché: la versión síncrona lo da al instante.
      expect(DailyVerseService.I.getForTodaySync().verse, v.verse);
      await DailyVerseService.I.getForToday();
      expect(llamadas, 1);
    });

    test('si la versión activa falla, cae al RVR1960', () async {
      final fecha = DateTime(2026, 3, 11, 9);
      TimeUtils.relojParaPruebas = () => fecha;
      DailyVerseService.I.configurarParaPruebas(
        versionActiva: () => BibleVersion.nvi,
        cargador: (ref, version) async => throw StateError('sin archivo'),
      );
      final v = await DailyVerseService.I.getForToday();
      expect(v.verse, DailyVerseService.referenciaParaFecha(fecha).textoRvr);
    });

    test('al cambiar de día da el versículo nuevo', () async {
      var ahora = DateTime(2026, 5, 1, 23, 59);
      TimeUtils.relojParaPruebas = () => ahora;
      DailyVerseService.I.configurarParaPruebas(
        versionActiva: () => BibleVersion.rvr1960,
      );
      final ayer = DailyVerseService.I.getForTodaySync();
      ahora = DateTime(2026, 5, 2, 0, 1);
      DailyVerseService.I.refreshToday();
      final hoy = await DailyVerseService.I.getForToday();
      expect(hoy.reference, isNot(ayer.reference));
      expect(hoy.category, isNot(ayer.category));
      expect(
        hoy.reference,
        DailyVerseService.referenciaParaFecha(ahora).referencia,
      );
    });
  });

  group('Frasco de emociones', () {
    tearDown(BibleVerses.reiniciarUltimosMostrados);

    test('nunca repite el último versículo de la misma emoción', () {
      final rnd = Random(7);
      for (final emocion in [
        'feliz',
        'ansioso',
        'agradecido',
        'solo',
        'enojado',
        'triste',
      ]) {
        var ultimo = BibleVerses.getRandomVerseByCategory(emocion, random: rnd);
        for (var i = 0; i < 200; i++) {
          final v = BibleVerses.getRandomVerseByCategory(emocion, random: rnd);
          expect(v, isNot(ultimo), reason: emocion);
          expect(v.category, emocion);
          ultimo = v;
        }
      }
    });

    test('cada emoción tiene al menos 10 versículos y existen en RVR1960', () {
      for (final emocion in [
        'feliz',
        'ansioso',
        'agradecido',
        'solo',
        'enojado',
        'triste',
      ]) {
        final lista = BibleVerses.getVersesByEmotion(emocion);
        expect(lista.length, greaterThanOrEqualTo(10), reason: emocion);
        for (final v in lista) {
          final r = BibleNavigationHelper.parseSpanishRef(v.reference);
          expect(r, isNotNull, reason: v.reference);
          final m = RegExp(r':(\d+)').firstMatch(v.reference)!;
          expect(
            rvr['${r!.bookNumber}:${r.chapter}:${m.group(1)}'],
            isNotNull,
            reason: v.reference,
          );
        }
      }
    });
  });
}
