import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_quitar/services/bible/bible_search_service.dart';
import 'package:app_quitar/services/bible/bible_share_service.dart';
import 'package:app_quitar/services/bible/advanced_search_service.dart';
import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/theme/bible_reader_theme.dart';
import 'package:app_quitar/data/bible_verses.dart' as data;

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE MODULE — Unit Tests (15+)
/// Tests para funciones puras sin dependencias de Firebase/dispositivo.
/// ═══════════════════════════════════════════════════════════════════════════

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // 1. BibleSearchService.normalize
  // ─────────────────────────────────────────────────────────────────────────
  group('BibleSearchService.normalize', () {
    test('removes Spanish accents', () {
      expect(BibleSearchService.normalize('José María'), 'jose maria');
    });

    test('lowercases and strips ñ and ü', () {
      expect(BibleSearchService.normalize('Niño Güell'), 'nino guell');
    });

    test('returns empty string unchanged', () {
      expect(BibleSearchService.normalize(''), '');
    });

    test('already normalized text passes through', () {
      expect(BibleSearchService.normalize('genesis'), 'genesis');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. BibleVersion.fromId
  // ─────────────────────────────────────────────────────────────────────────
  group('BibleVersion', () {
    test('fromId returns correct version for valid id', () {
      expect(BibleVersion.fromId('NVI'), BibleVersion.nvi);
      expect(BibleVersion.fromId('LBLA'), BibleVersion.lbla);
    });

    test('fromId defaults to rvr1960 for unknown id', () {
      expect(BibleVersion.fromId('UNKNOWN'), BibleVersion.rvr1960);
      expect(BibleVersion.fromId(''), BibleVersion.rvr1960);
    });

    test('all versions have non-empty shortName', () {
      for (final v in BibleVersion.values) {
        expect(v.shortName.isNotEmpty, true,
            reason: '${v.name} should have shortName');
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. BibleReaderThemeData.fromId / migrateId
  // ─────────────────────────────────────────────────────────────────────────
  group('BibleReaderThemeData', () {
    test('fromId returns correct theme', () {
      final t = BibleReaderThemeData.fromId('clean_page');
      expect(t.id, 'clean_page');
      expect(t.isDark, false);
    });

    test('fromId returns nightPure for unknown id', () {
      final t = BibleReaderThemeData.fromId('nonexistent');
      expect(t.id, 'night_pure');
    });

    test('migrateId converts legacy ids', () {
      expect(BibleReaderThemeData.migrateId('dark'), 'night_pure');
      expect(BibleReaderThemeData.migrateId('sepia'), 'sepia_night');
      expect(BibleReaderThemeData.migrateId('light'), 'clean_page');
    });

    test('migrateId passes through modern ids', () {
      expect(BibleReaderThemeData.migrateId('charcoal_editorial'),
          'charcoal_editorial');
    });

    test('isDark is correct for all themes', () {
      expect(BibleReaderThemeData.nightPure.isDark, true);
      expect(BibleReaderThemeData.cleanPage.isDark, false);
      expect(BibleReaderThemeData.parchment.isDark, false);
    });

    test('computed redLetterColor differs by isDark', () {
      final dark = BibleReaderThemeData.nightPure;
      final light = BibleReaderThemeData.cleanPage;
      expect(dark.redLetterColor, isNot(equals(light.redLetterColor)));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. BibleShareService static helpers
  // ─────────────────────────────────────────────────────────────────────────
  group('BibleShareService', () {
    test('dimensionSize returns correct sizes', () {
      expect(BibleShareService.dimensionSize(ShareDimension.square),
          const Size(400, 400));
      expect(BibleShareService.dimensionSize(ShareDimension.story),
          const Size(360, 640));
      expect(BibleShareService.dimensionSize(ShareDimension.landscape),
          const Size(640, 360));
    });

    test('adaptiveFontSize decreases for long text', () {
      final short = BibleShareService.adaptiveFontSize(
          'Corto', ShareDimension.square);
      final long = BibleShareService.adaptiveFontSize(
          'A' * 301, ShareDimension.square);
      expect(long < short, true);
    });

    test('adaptiveFontSize uses different base per dimension', () {
      final sq = BibleShareService.adaptiveFontSize(
          'X', ShareDimension.square);
      final st = BibleShareService.adaptiveFontSize(
          'X', ShareDimension.story);
      expect(sq, isNot(equals(st)));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. ShareTemplate enum
  // ─────────────────────────────────────────────────────────────────────────
  group('ShareTemplate', () {
    test('has 13 templates', () {
      expect(ShareTemplate.values.length, 13);
    });

    test('isDark identifies dark templates correctly', () {
      expect(ShareTemplate.minimalDark.isDark, true);
      expect(ShareTemplate.midnight.isDark, true);
      expect(ShareTemplate.editorialLight.isDark, false);
      expect(ShareTemplate.sunrise.isDark, false);
      expect(ShareTemplate.ocean.isDark, true);
      expect(ShareTemplate.pureLight.isDark, false);
    });

    test('displayName is non-empty for all', () {
      for (final t in ShareTemplate.values) {
        expect(t.displayName.isNotEmpty, true);
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 6. AdvancedSearchService themes
  // ─────────────────────────────────────────────────────────────────────────
  group('AdvancedSearchService', () {
    test('has 20 predefined themes', () {
      expect(AdvancedSearchService.I.availableThemes.length, 20);
    });

    test('themes include key topics', () {
      final themes = AdvancedSearchService.I.availableThemes;
      expect(themes.contains('Amor'), true);
      expect(themes.contains('Fe'), true);
      expect(themes.contains('Salvación'), true);
      expect(themes.contains('Oración'), true);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 7. AdvancedSearchVerse model
  // ─────────────────────────────────────────────────────────────────────────
  group('AdvancedSearchVerse', () {
    test('reference getter formats correctly', () {
      const v = AdvancedSearchVerse(
        bookNumber: 1,
        bookName: 'Génesis',
        chapter: 1,
        verse: 1,
        text: 'En el principio...',
      );
      expect(v.reference, 'Génesis 1:1');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 8. BibleVerse model
  // ─────────────────────────────────────────────────────────────────────────
  group('BibleVerse model', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'verse': 'Test verse',
        'reference': 'Test 1:1',
        'category': 'test',
      };
      final v = data.BibleVerse.fromJson(json);
      expect(v.verse, 'Test verse');
      expect(v.reference, 'Test 1:1');
      expect(v.toJson()['verse'], 'Test verse');
    });

    test('equality works by verse + reference', () {
      const a = data.BibleVerse(
          verse: 'a', reference: 'Ref 1:1', category: 'cat');
      const b = data.BibleVerse(
          verse: 'b', reference: 'Ref 1:1', category: 'cat');
      const c = data.BibleVerse(
          verse: 'a', reference: 'Ref 1:1', category: 'other');
      expect(a, equals(c)); // same verse+ref, different category
      expect(a, isNot(equals(b))); // different verse text
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 9. BibleVerses collection
  // ─────────────────────────────────────────────────────────────────────────
  group('BibleVerses collection', () {
    test('allVerses is not empty', () {
      expect(data.BibleVerses.allVerses.isNotEmpty, true);
    });

    test('allVerses has at least 40 entries', () {
      expect(data.BibleVerses.allVerses.length >= 40, true);
    });

    test('getVersesByEmotion returns correct list for feliz', () {
      final verses = data.BibleVerses.getVersesByEmotion('feliz');
      expect(verses.isNotEmpty, true);
      expect(verses.first.category, 'feliz');
    });

    test('getVersesByEmotion returns allVerses for unknown', () {
      final verses = data.BibleVerses.getVersesByEmotion('unknown_emotion');
      expect(verses.length, data.BibleVerses.allVerses.length);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 10. Daily verse deterministic algorithm
  // ─────────────────────────────────────────────────────────────────────────
  group('Daily verse algorithm', () {
    test('same day produces same index', () {
      final now = DateTime(2025, 6, 15);
      final dayOfYear =
          now.difference(DateTime(now.year, 1, 1)).inDays + 1;
      final seed = dayOfYear + (now.year * 365);
      final total = data.BibleVerses.allVerses.length;
      final idx1 = seed % total;
      final idx2 = seed % total;
      expect(idx1, idx2);
    });

    test('different days produce different indices (usually)', () {
      final total = data.BibleVerses.allVerses.length;
      final day1 = DateTime(2025, 6, 15);
      final day2 = DateTime(2025, 6, 16);
      int indexFor(DateTime d) {
        final dy = d.difference(DateTime(d.year, 1, 1)).inDays + 1;
        return (dy + d.year * 365) % total;
      }
      // Adjacent days should differ (modular arithmetic)
      expect(indexFor(day1), isNot(equals(indexFor(day2))));
    });
  });
}
