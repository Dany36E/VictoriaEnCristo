import 'dart:convert';
import 'dart:io';

// ignore: avoid_relative_lib_imports
import '../lib/utils/original_language_normalizer.dart';

/// Genera los activos compactos del léxico Strong y el índice de apariciones.
///
/// Uso:
/// dart run tool/generate_strong_assets.dart <greek-js> <hebrew-js>
///
/// Los archivos de entrada son las versiones JSON/JS de Open Scriptures:
/// https://github.com/openscriptures/strongs
void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Uso: dart run tool/generate_strong_assets.dart '
      '<strongs-greek-dictionary.js> <strongs-hebrew-dictionary.js>',
    );
    exitCode = 64;
    return;
  }

  final greek = _readDictionary(File(args[0]), 'G');
  final hebrew = _readDictionary(File(args[1]), 'H');
  final output = Directory('assets/bible/lexicon')..createSync(recursive: true);

  _writeJson(
    File('${output.path}/strong_greek.json'),
    _lexiconPayload(greek, 'griego'),
  );
  _writeJson(
    File('${output.path}/strong_hebrew.json'),
    _lexiconPayload(hebrew, 'hebreo'),
  );

  final greekIndex = _buildOccurrenceIndex(
    Directory('assets/bible/interlinear/greek'),
    greek,
    isHebrew: false,
  );
  final hebrewIndex = _buildOccurrenceIndex(
    Directory('assets/bible/interlinear/hebrew'),
    hebrew,
    isHebrew: true,
  );

  _writeJson(File('${output.path}/original_greek.json'), greekIndex.payload);
  _writeJson(File('${output.path}/original_hebrew.json'), hebrewIndex.payload);

  stdout.writeln(
    'Greek: ${greek.length} lexical entries, '
    '${greekIndex.termCount} searchable terms, '
    '${greekIndex.strongMatches}/${greekIndex.wordsWithLemma} words linked '
    'to Strong.',
  );
  stdout.writeln(
    'Hebrew: ${hebrew.length} lexical entries, '
    '${hebrewIndex.termCount} searchable terms. Aramaic tokens excluded.',
  );
}

Map<String, dynamic> _readDictionary(File file, String prefix) {
  final source = file.readAsStringSync();
  final start = source.indexOf('{');
  final end = source.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw FormatException('No se encontró el objeto JSON en ${file.path}');
  }
  final decoded = jsonDecode(source.substring(start, end + 1));
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Formato inesperado en ${file.path}');
  }
  return Map.fromEntries(
    decoded.entries.where((entry) => entry.key.startsWith(prefix)),
  );
}

Map<String, dynamic> _lexiconPayload(
  Map<String, dynamic> dictionary,
  String language,
) {
  final entries = <String, dynamic>{};
  final sortedKeys = dictionary.keys.toList()
    ..sort((a, b) => _strongValue(a).compareTo(_strongValue(b)));

  for (final key in sortedKeys) {
    final raw = Map<String, dynamic>.from(dictionary[key] as Map);
    entries[key] = <String, dynamic>{
      'w': raw['lemma'] ?? '',
      'x': raw['translit'] ?? raw['xlit'] ?? '',
      'p': raw['pron'] ?? '',
      'o': _cleanText(raw['derivation']?.toString() ?? ''),
      'd': _cleanText(raw['strongs_def']?.toString() ?? ''),
      'u': _cleanText(raw['kjv_def']?.toString() ?? ''),
    };
  }

  return <String, dynamic>{
    'meta': <String, dynamic>{
      'language': language,
      'source': 'Open Scriptures — Strong’s Dictionaries',
      'sourceUrl': 'https://github.com/openscriptures/strongs',
      'license': 'CC BY-SA (JSON derivado de XML de dominio público)',
    },
    'entries': entries,
  };
}

_IndexBuildResult _buildOccurrenceIndex(
  Directory directory,
  Map<String, dynamic> dictionary, {
  required bool isHebrew,
}) {
  final lemmaToStrong = <String, Set<String>>{};
  for (final entry in dictionary.entries) {
    final raw = Map<String, dynamic>.from(entry.value as Map);
    final lemma = normalizeOriginalLanguageTerm(raw['lemma']?.toString() ?? '');
    if (lemma.isNotEmpty) {
      lemmaToStrong.putIfAbsent(lemma, () => <String>{}).add(entry.key);
    }
  }

  final terms = <String, _MutableTerm>{};
  final strongRefs = <String, Set<int>>{};
  var strongMatches = 0;
  var wordsWithLemma = 0;

  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final code = file.uri.pathSegments.last.replaceAll('.json', '');
    final bookNumber = _bookCodeToNumber[code];
    if (bookNumber == null) continue;
    final verses = jsonDecode(file.readAsStringSync()) as List<dynamic>;

    for (final verseRaw in verses) {
      final verse = Map<String, dynamic>.from(verseRaw as Map);
      final chapter = verse['c'] as int;
      final verseNumber = verse['v'] as int;
      final packed = bookNumber * 1000000 + chapter * 1000 + verseNumber;

      for (final wordRaw in verse['w'] as List<dynamic>) {
        final word = Map<String, dynamic>.from(wordRaw as Map);
        final morph = word['m']?.toString() ?? '';
        if (isHebrew && morph.startsWith('A')) continue;

        final original = word['o']?.toString() ?? '';
        final lemma = word['l']?.toString() ?? '';
        final normalizedOriginal = normalizeOriginalLanguageTerm(original);
        final normalizedLemma = normalizeOriginalLanguageTerm(lemma);

        final strongNumbers = <String>{};
        final rawStrong = word['s']?.toString() ?? '';
        if (rawStrong.isNotEmpty) {
          strongNumbers.add(_normalizeStrong(rawStrong, isHebrew));
        } else if (normalizedLemma.isNotEmpty) {
          wordsWithLemma++;
          strongNumbers.addAll(lemmaToStrong[normalizedLemma] ?? const {});
          if (strongNumbers.isNotEmpty) strongMatches++;
        }

        void addTerm(String normalized, String display) {
          if (normalized.isEmpty) return;
          final term = terms.putIfAbsent(
            normalized,
            () => _MutableTerm(display: display, lemma: lemma),
          );
          term.references.add(packed);
          term.strongNumbers.addAll(strongNumbers);
          if (term.lemma.isEmpty && lemma.isNotEmpty) term.lemma = lemma;
        }

        addTerm(normalizedOriginal, original);
        addTerm(normalizedLemma, lemma.isEmpty ? original : lemma);

        for (final strong in strongNumbers) {
          strongRefs.putIfAbsent(strong, () => <int>{}).add(packed);
        }
      }
    }
  }

  final sortedTermKeys = terms.keys.toList()..sort();
  final termPayload = <String, dynamic>{};
  for (final key in sortedTermKeys) {
    final term = terms[key]!;
    final refs = term.references.toList()..sort();
    final strong = term.strongNumbers.toList()
      ..sort((a, b) => _strongValue(a).compareTo(_strongValue(b)));
    termPayload[key] = <String, dynamic>{
      'd': term.display,
      'l': term.lemma,
      's': strong,
      'r': refs,
    };
  }

  final sortedStrongKeys = strongRefs.keys.toList()
    ..sort((a, b) => _strongValue(a).compareTo(_strongValue(b)));
  final strongPayload = <String, dynamic>{};
  for (final key in sortedStrongKeys) {
    final refs = strongRefs[key]!.toList()..sort();
    strongPayload[key] = refs;
  }

  return _IndexBuildResult(
    payload: <String, dynamic>{
      'meta': <String, dynamic>{
        'language': isHebrew ? 'hebreo' : 'griego',
        'aramaicIncluded': false,
        'referenceEncoding': 'book*1000000 + chapter*1000 + verse',
      },
      'terms': termPayload,
      'strong': strongPayload,
    },
    termCount: terms.length,
    strongMatches: strongMatches,
    wordsWithLemma: wordsWithLemma,
  );
}

String _normalizeStrong(String value, bool isHebrew) {
  final trimmed = value.trim().toUpperCase();
  if (trimmed.startsWith('H') || trimmed.startsWith('G')) return trimmed;
  return '${isHebrew ? 'H' : 'G'}$trimmed';
}

int _strongValue(String value) =>
    int.tryParse(value.replaceAll(RegExp('[^0-9]'), '')) ?? 999999;

String _cleanText(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

void _writeJson(File file, Map<String, dynamic> payload) {
  file.writeAsStringSync(jsonEncode(payload));
  stdout.writeln('${file.path}: ${file.lengthSync()} bytes');
}

class _MutableTerm {
  final String display;
  String lemma;
  final Set<String> strongNumbers = <String>{};
  final Set<int> references = <int>{};

  _MutableTerm({required this.display, required this.lemma});
}

class _IndexBuildResult {
  final Map<String, dynamic> payload;
  final int termCount;
  final int strongMatches;
  final int wordsWithLemma;

  const _IndexBuildResult({
    required this.payload,
    required this.termCount,
    required this.strongMatches,
    required this.wordsWithLemma,
  });
}

const Map<String, int> _bookCodeToNumber = <String, int>{
  'GEN': 1,
  'EXO': 2,
  'LEV': 3,
  'NUM': 4,
  'DEU': 5,
  'JOS': 6,
  'JDG': 7,
  'RUT': 8,
  '1SA': 9,
  '2SA': 10,
  '1KI': 11,
  '2KI': 12,
  '1CH': 13,
  '2CH': 14,
  'EZR': 15,
  'NEH': 16,
  'EST': 17,
  'JOB': 18,
  'PSA': 19,
  'PRO': 20,
  'ECC': 21,
  'SNG': 22,
  'ISA': 23,
  'JER': 24,
  'LAM': 25,
  'EZK': 26,
  'DAN': 27,
  'HOS': 28,
  'JOL': 29,
  'AMO': 30,
  'OBA': 31,
  'JON': 32,
  'MIC': 33,
  'NAM': 34,
  'HAB': 35,
  'ZEP': 36,
  'HAG': 37,
  'ZEC': 38,
  'MAL': 39,
  'MAT': 40,
  'MRK': 41,
  'LUK': 42,
  'JHN': 43,
  'ACT': 44,
  'ROM': 45,
  '1CO': 46,
  '2CO': 47,
  'GAL': 48,
  'EPH': 49,
  'PHP': 50,
  'COL': 51,
  '1TH': 52,
  '2TH': 53,
  '1TI': 54,
  '2TI': 55,
  'TIT': 56,
  'PHM': 57,
  'HEB': 58,
  'JAS': 59,
  '1PE': 60,
  '2PE': 61,
  '1JN': 62,
  '2JN': 63,
  '3JN': 64,
  'JUD': 65,
  'REV': 66,
};
