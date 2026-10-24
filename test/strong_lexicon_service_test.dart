import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/services/bible/advanced_search_service.dart';
import 'package:app_quitar/services/bible/interlinear_service.dart';
import 'package:app_quitar/services/bible/strong_lexicon_service.dart';
import 'package:app_quitar/utils/original_language_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('original-language normalization', () {
    test('removes Hebrew points and Greek accents', () {
      expect(normalizeOriginalLanguageTerm('אֱלֹהִים'), 'אלהים');
      expect(normalizeOriginalLanguageTerm('Θεός'), 'θεοσ');
      expect(normalizeOriginalLanguageTerm('θεος'), 'θεοσ');
    });

    test('normalizes Strong numbers without duplicate prefixes', () {
      expect(StrongLexiconService.normalizeStrongNumber('H0430'), 'H430');
      expect(StrongLexiconService.normalizeStrongNumber('g02316'), 'G2316');
      expect(StrongLexiconService.normalizeStrongNumber('HH430'), isNull);
    });
  });

  group('local Strong lexicon', () {
    test(
      'loads complete Hebrew and Greek entries from bundled assets',
      () async {
        final hebrew = await StrongLexiconService.I.lookupStrong('H430');
        final greek = await StrongLexiconService.I.lookupStrong('G2316');

        expect(hebrew, isNotNull);
        expect(hebrew!.lemma, isNotEmpty);
        expect(hebrew.definition, isNotEmpty);
        expect(greek, isNotNull);
        expect(greek!.lemma, isNotEmpty);
        expect(greek.definition, isNotEmpty);
      },
    );

    test('finds verse references from a pointed Hebrew word', () async {
      final result = await StrongLexiconService.I.search('אֱלֹהִים');

      expect(result.hasData, isTrue);
      expect(result.references, isNotEmpty);
      expect(result.strongNumbers, contains('H430'));
      expect(result.references.first.bookNumber, inInclusiveRange(1, 39));
    });

    test(
      'finds Greek forms even when the interlinear lacks Strong tags',
      () async {
        final result = await StrongLexiconService.I.search('θεός');

        expect(result.hasData, isTrue);
        expect(result.references, isNotEmpty);
        expect(result.references.first.bookNumber, inInclusiveRange(40, 66));
      },
    );

    test(
      'does not duplicate the Hebrew prefix from interlinear data',
      () async {
        final verse = await InterlinearService.instance.getVerse(1, 1, 1);
        final tagged = verse!.words.where((word) => word.hasStrong).first;

        expect(tagged.strongNumber, startsWith('H'));
        expect(tagged.strongNumber, isNot(startsWith('HH')));
      },
    );

    test('known entries are in Spanish', () async {
      final agape = await StrongLexiconService.I.lookupStrong('G26');
      final elohim = await StrongLexiconService.I.lookupStrong('H430');
      final logos = await StrongLexiconService.I.lookupStrong('G3056');

      expect(agape!.transliteration, 'agápē');
      expect(agape.definition, contains('amor'));
      expect(agape.biblicalUsage, contains('amor'));
      expect(elohim!.transliteration, 'ʼĕlôhîym');
      expect(elohim.definition, contains('Dios supremo'));
      expect(elohim.biblicalUsage, contains('Dios'));
      expect(logos!.biblicalUsage, contains('Verbo'));
      expect(logos.definition, contains('Verbo'));
      for (final entry in [agape, elohim, logos]) {
        expect(entry.definition, isNot(contains(' the ')));
      }
    });

    test('Strong-number search accepts G26, 26 and H430', () async {
      final g26 = await StrongLexiconService.I.lookupStrongNumber('G26');
      expect(g26.map((e) => e.strongNumber), ['G26']);

      final bare = await StrongLexiconService.I.lookupStrongNumber('26');
      expect(bare.map((e) => e.strongNumber), containsAll(['G26', 'H26']));

      final h430 = await StrongLexiconService.I.lookupStrongNumber('h0430');
      expect(h430.single.strongNumber, 'H430');

      expect(StrongLexiconService.isStrongNumberQuery('26'), isTrue);
      expect(StrongLexiconService.isStrongNumberQuery('G26'), isTrue);
      expect(StrongLexiconService.isStrongNumberQuery('amor'), isFalse);

      final concordance = await StrongLexiconService.I.search('26');
      expect(concordance.strongNumbers, containsAll(['G26', 'H26']));
      expect(concordance.references, isNotEmpty);
    });

    test('searches Spanish definitions and transliterations', () async {
      final amor = await StrongLexiconService.I.searchDefinitions('amor');
      expect(amor.map((e) => e.strongNumber), contains('G26'));

      final verbo = await StrongLexiconService.I.searchDefinitions('Verbo');
      expect(verbo.map((e) => e.strongNumber), contains('G3056'));

      final agape = await StrongLexiconService.I.searchDefinitions('agape');
      expect(agape.first.strongNumber, 'G26');

      final menfis = await StrongLexiconService.I.searchDefinitions('menfis');
      expect(
        menfis.map((e) => e.strongNumber),
        containsAll(['H4644', 'H5297']),
      );
    });

    test(
      'hydrates global Strong results with the selected Bible text',
      () async {
        final result = await AdvancedSearchService.I.searchByStrong(
          'H430',
          BibleVersion.rvr1960,
        );

        expect(result.verses, isNotEmpty);
        expect(result.verses.first.text, isNotEmpty);
        expect(result.subtitle, contains('versículo'));
      },
    );
  });
}
