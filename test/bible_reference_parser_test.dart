import 'package:app_quitar/utils/bible_reference_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BibleReference? p(String s) => BibleReferenceParser.parse(s);

  group('BibleReferenceParser.parse', () {
    test('nombres completos con y sin acentos', () {
      expect(p('Génesis 1:1')!.bookNumber, 1);
      expect(p('Genesis 1:1')!.bookNumber, 1);
      expect(p('Exodo 20:3')!.bookNumber, 2);
      expect(p('Isaias 53:5')!.bookNumber, 23);
      expect(p('Apocalipsis 21:4')!.bookNumber, 66);
      expect(p('Nahum 1:7')!.bookName, 'Nahúm');
    });

    test('«Salmo» en singular (devocionales) y plural', () {
      final r = p('Salmo 103:12')!;
      expect(r.bookNumber, 19);
      expect(r.bookName, 'Salmos');
      expect(r.chapter, 103);
      expect(r.verse, 12);
      expect(p('Salmos 23')!.verse, isNull);
      expect(p('Salmos 23')!.chapter, 23);
    });

    test('abreviaturas comunes', () {
      expect(p('Sal 23:1')!.bookNumber, 19);
      expect(p('Gn 1:1')!.bookNumber, 1);
      expect(p('Jn 3:16')!.bookNumber, 43);
      expect(p('1 Co 13:4')!.bookNumber, 46);
      expect(p('1Co 13:4')!.bookNumber, 46);
      expect(p('2 Co 5:17')!.bookNumber, 47);
      expect(p('Flp 4:13')!.bookNumber, 50);
      expect(p('Fil 4:13')!.bookNumber, 50);
      expect(p('Flm 1:6')!.bookNumber, 57);
      expect(p('Ap. 21:4')!.bookNumber, 66);
      expect(p('Mt 5:9')!.bookNumber, 40);
      expect(p('Mr 1:1')!.bookNumber, 41);
      expect(p('Lc 2:11')!.bookNumber, 42);
      expect(p('Hch 2:38')!.bookNumber, 44);
      expect(p('Ro 8:28')!.bookNumber, 45);
      expect(p('Stg 1:5')!.bookNumber, 59);
      expect(p('He 11:1')!.bookNumber, 58);
      expect(p('1 Jn 4:8')!.bookNumber, 62);
      expect(p('Pr 3:5')!.bookNumber, 20);
      expect(p('Is 41:10')!.bookNumber, 23);
    });

    test('ordinales y «San»', () {
      expect(p('1ra Juan 4:8')!.bookNumber, 62);
      expect(p('Primera de Pedro 5:7')!.bookNumber, 60);
      expect(p('Segunda Timoteo 1:7')!.bookNumber, 55);
      expect(p('II Corintios 12:9')!.bookNumber, 47);
      expect(p('San Juan 3:16')!.bookNumber, 43);
      expect(p('Santiago 1:2')!.bookNumber, 59);
    });

    test('códigos OSIS/USFM', () {
      final r = p('JHN.3.16')!;
      expect(r.bookNumber, 43);
      expect(r.chapter, 3);
      expect(r.verse, 16);
      expect(p('PSA 23')!.bookNumber, 19);
      expect(p('1CO 13:4')!.bookNumber, 46);
      expect(BibleReferenceParser.parseOsis('ROM.5.8')!.label, 'Romanos 5:8');
      expect(BibleReferenceParser.parseOsis('GEN.2.7')!.bookName, 'Génesis');
    });

    test('rangos y separadores', () {
      final r = p('1 Tesalonicenses 5:16-18')!;
      expect(r.bookNumber, 52);
      expect(r.verse, 16);
      expect(r.endVerse, 18);
      expect(r.label, '1 Tesalonicenses 5:16-18');
      expect(p('Juan 3,16')!.verse, 16);
      expect(p('Juan 3.16')!.verse, 16);
      expect(p('Juan 3 16')!.verse, 16);
      // Rango entre capítulos: se queda con el inicio.
      final cruzado = p('Juan 3:16-4:2')!;
      expect(cruzado.verse, 16);
      expect(cruzado.endVerse, isNull);
    });

    test('libros de un capítulo', () {
      final r = p('Judas 24')!;
      expect(r.bookNumber, 65);
      expect(r.chapter, 1);
      expect(r.verse, 24);
      expect(p('Judas 1:24')!.verse, 24);
      expect(p('Abdías 1')!.chapter, 1);
    });

    test('mayúsculas, espacios y texto extra', () {
      expect(p('  juan   3:16  ')!.verse, 16);
      expect(p('JUAN 3:16 (RVR1960)')!.verse, 16);
    });

    test('no reconoce lo que no es referencia', () {
      expect(p(''), isNull);
      expect(p('amor'), isNull);
      expect(p('Juan'), isNull); // sin capítulo
      expect(p('Xyz 3:16'), isNull);
      expect(p('Jo 3:16'), isNull); // ambiguo: Job, Joel, Jonás, Josué…
    });
  });

  group('BibleReferenceParser.resolveBook', () {
    test('prefijo único y nombre canónico', () {
      expect(BibleReferenceParser.resolveBook('filip'), 50);
      expect(BibleReferenceParser.resolveBook('ecle'), 21);
      expect(BibleReferenceParser.resolveBook('Ecclesiastes'), 21);
      expect(BibleReferenceParser.resolveBook('Cantar de los Cantares'), 22);
      expect(BibleReferenceParser.resolveBook('Hechos de los Apóstoles'), 44);
      expect(BibleReferenceParser.bookName(19), 'Salmos');
      expect(BibleReferenceParser.bookName(46), '1 Corintios');
    });

    test('los 66 nombres canónicos y códigos se resuelven a sí mismos', () {
      for (var i = 0; i < 66; i++) {
        expect(
          BibleReferenceParser.resolveBook(BibleReferenceParser.bookNames[i]),
          i + 1,
          reason: BibleReferenceParser.bookNames[i],
        );
        expect(
          BibleReferenceParser.resolveBook(BibleReferenceParser.usfmCodes[i]),
          i + 1,
          reason: BibleReferenceParser.usfmCodes[i],
        );
      }
    });
  });
}
