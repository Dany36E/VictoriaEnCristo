import 'package:app_quitar/models/bible/dictionary_entry.dart';
import 'package:app_quitar/services/bible/bible_dictionary_service.dart';
import 'package:app_quitar/screens/bible/bible_dictionary_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dict = BibleDictionaryService.instance;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await dict.init();
  });

  testWidgets('el detalle muestra citas formateadas y enlaces «Véase»', (
    tester,
  ) async {
    final adino = dict.lookupTerm('Adino')!;
    await tester.pumpWidget(
      MaterialApp(home: BibleDictionaryDetailScreen(entry: adino)),
    );
    await tester.pump();
    // Cita en el texto como «2 S 23:8», ficha como «2 Samuel 23:8».
    expect(find.textContaining('2 S 23:8', findRichText: true), findsWidgets);
    expect(find.text('2 Samuel 23:8'), findsOneWidget);
    expect(find.textContaining('GEN.', findRichText: true), findsNothing);
    expect(find.textContaining('[[', findRichText: true), findsNothing);
    expect(find.textContaining('JASOBEAM', findRichText: true), findsOneWidget);
    expect(find.text(BibleDictionaryService.eastonAttribution), findsOneWidget);
  });

  test('carga el Easton completo en español y conserva Hitchcock', () {
    expect(dict.eastonCount, greaterThanOrEqualTo(3900));
    expect(dict.hitchcockCount, greaterThan(0));
    final ids = dict.eastonEntries.map((e) => e.id).toSet();
    expect(ids.length, dict.eastonCount, reason: 'ids únicos');
    for (final e in dict.eastonEntries.take(50)) {
      expect(e.term, isNotEmpty);
      expect(e.termEn, isNotEmpty);
      expect(e.definition, isNotEmpty);
    }
  });

  test('entradas conocidas en español', () {
    final abraham = dict.lookupTerm('Abraham')!;
    expect(abraham.source, 'Easton');
    expect(abraham.plainDefinition, contains('hijo de Taré'));

    final expiacion = dict.lookupTerm('Atonement')!;
    expect(expiacion.term, 'Expiación');
    expect(expiacion.plainDefinition, contains('expiación'));

    final getsemani = dict.lookupTerm('Gethsemane')!;
    expect(getsemani.term, 'Getsemaní');
    expect(getsemani.plainDefinition, contains('monte de los Olivos'));
  });

  test('búsqueda sin tildes, por término en español o en inglés', () {
    expect(dict.search('getsemani').first.term, 'Getsemaní');
    expect(dict.search('GETSEMANÍ').first.term, 'Getsemaní');
    expect(dict.search('expiacion').first.term, 'Expiación');
    expect(dict.search('atonement').first.term, 'Expiación');
    expect(dict.search('en-ganim').first.term, 'En-ganim');
    expect(
      dict.search('génesis').map((e) => e.id).toList(),
      dict.search('genesis').map((e) => e.id).toList(),
    );
    // Desde 3 letras también busca dentro de las definiciones.
    expect(dict.search('hijo de Taré'), contains(dict.lookupTerm('Abraham')));
    expect(dict.search('').length, dict.totalCount);
  });

  test('todas las referencias se interpretan y se muestran formateadas', () {
    var total = 0;
    for (final e in dict.eastonEntries) {
      for (final raw in e.references) {
        final ref = DictionaryRef.parse(raw);
        expect(ref, isNotNull, reason: '${e.id}: $raw');
        expect(ref!.start.bookNumber, inInclusiveRange(1, 66));
        expect(ref.label, isNot(contains('.')), reason: raw);
        total++;
      }
      for (final m in DictionaryEntry.markerPattern.allMatches(e.definition)) {
        final target = m.group(1)!;
        if (target.startsWith('VER:')) continue;
        expect(
          DictionaryRef.parse(target),
          isNotNull,
          reason: '${e.id}: $target',
        );
      }
    }
    expect(total, greaterThan(20000));
    expect(DictionaryRef.parse('GEN.2.7')!.label, 'Génesis 2:7');
    expect(DictionaryRef.parse('ROM.5.12-14')!.label, 'Romanos 5:12-14');
    expect(DictionaryRef.parse('GEN.2-3')!.label, 'Génesis 2–3');
    expect(DictionaryRef.parse('JDG.8.33-9.6')!.label, 'Jueces 8:33–9:6');
    expect(DictionaryRef.parse('1CO.13')!.label, '1 Corintios 13');
    expect(DictionaryRef.parse('XYZ.1.1'), isNull);
  });

  test('ningún «Véase» apunta a una entrada inexistente', () {
    var links = 0;
    for (final e in dict.eastonEntries) {
      for (final id in e.see) {
        expect(dict.byId(id), isNotNull, reason: '${e.id} -> $id');
        links++;
      }
      for (final m in DictionaryEntry.markerPattern.allMatches(e.definition)) {
        final target = m.group(1)!;
        if (!target.startsWith('VER:')) continue;
        expect(
          dict.byId(target.substring(4)),
          isNotNull,
          reason: '${e.id} -> $target',
        );
      }
    }
    expect(links, greaterThan(500));
  });

  test('correcciones revisadas con la RVR1960', () {
    expect(dict.lookupTerm('Dehavites')!.term, 'Dehaveos');
    expect(
      dict.lookupTerm('En-gannim')!.plainDefinition,
      contains('límite de Isacar'),
    );
    expect(
      dict.lookupTerm('Nebuchadrezzar')!.term,
      startsWith('Nabucodonosor'),
    );
    expect(dict.lookupTerm('Siloam, Pool of')!.term, 'Siloé, estanque de');
    expect(
      dict.lookupTerm('Shechem')!.plainDefinition,
      isNot(contains('Sychem (')),
    );
    expect(
      dict.eastonEntries.where((e) => e.term.contains('Nabucodorosor')),
      isEmpty,
    );
    // Títulos de obras citadas en su inglés original.
    final scrip = dict.eastonEntries.firstWhere((e) => e.id == 'e3026');
    expect(scrip.plainDefinition, contains('Land and the Book'));
  });

  test('atribución de la traducción', () {
    expect(
      BibleDictionaryService.eastonAttribution,
      'Diccionario Bíblico de Easton (1897), dominio público. '
      'Traducción propia al español.',
    );
  });
}
