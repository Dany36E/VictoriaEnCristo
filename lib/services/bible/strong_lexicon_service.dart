import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/interlinear_word.dart';
import '../../models/bible/strong_lexicon_entry.dart';
import '../../utils/original_language_normalizer.dart';

/// Léxico Strong y concordancia por palabra original, completamente locales.
///
/// El servicio carga un idioma a la vez y conserva el JSON compacto en memoria.
/// Los datos léxicos proceden de Open Scriptures. El índice de apariciones se
/// genera en este proyecto a partir de los interlineales locales.
class StrongLexiconService {
  StrongLexiconService._();
  static final StrongLexiconService I = StrongLexiconService._();

  Future<_LanguageAssets>? _greekFuture;
  Future<_LanguageAssets>? _hebrewFuture;

  Future<StrongLexiconEntry?> lookupStrong(String strongNumber) async {
    final normalized = normalizeStrongNumber(strongNumber);
    if (normalized == null) return null;
    final assets = await _load(normalized.startsWith('H'));
    return assets.lexicon[normalized];
  }

  Future<List<StrongLexiconEntry>> resolveWord(
    InterlinearWord word, {
    required bool isHebrew,
  }) async {
    final assets = await _load(isHebrew);
    final direct = normalizeStrongNumber(word.strongNumber ?? '');
    final numbers = <String>{};
    if (direct != null) numbers.add(direct);

    for (final candidate in <String>[word.lemma ?? '', word.originalWord]) {
      final key = normalizeOriginalLanguageTerm(candidate);
      if (key.isEmpty) continue;
      final term = assets.terms[key];
      if (term == null) continue;
      numbers.addAll(_stringList(term['s']));
    }

    return numbers
        .map((number) => assets.lexicon[number])
        .whereType<StrongLexiconEntry>()
        .toList(growable: false);
  }

  Future<OriginalWordSearchResult> search(String query) async {
    final strong = normalizeStrongNumber(query);
    if (strong != null) {
      return _searchStrong(query, strong);
    }

    final normalized = normalizeOriginalLanguageTerm(query);
    if (normalized.isEmpty) return _empty(query);

    final languages = _languagesFor(query);
    for (final isHebrew in languages) {
      final assets = await _load(isHebrew);
      final term = assets.terms[normalized];
      if (term == null) continue;
      return _resultFromTerm(query, term, assets);
    }

    return _empty(query);
  }

  Future<List<String>> suggestions(String query, {int limit = 8}) async {
    final normalized = normalizeOriginalLanguageTerm(query);
    if (normalized.isEmpty) return const [];
    final results = <String>[];
    for (final isHebrew in _languagesFor(query)) {
      final assets = await _load(isHebrew);
      for (final entry in assets.terms.entries) {
        if (!entry.key.startsWith(normalized)) continue;
        final display = entry.value['d']?.toString() ?? '';
        if (display.isNotEmpty && !results.contains(display)) {
          results.add(display);
          if (results.length >= limit) return results;
        }
      }
    }
    return results;
  }

  Future<OriginalWordSearchResult> _searchStrong(
    String query,
    String strong,
  ) async {
    final assets = await _load(strong.startsWith('H'));
    final lexical = assets.lexicon[strong];
    final packed = _intList(assets.strongReferences[strong]);
    return OriginalWordSearchResult(
      query: query,
      displayWord: lexical?.lemma ?? strong,
      lemma: lexical?.lemma ?? '',
      strongNumbers: <String>[strong],
      lexiconEntries: lexical == null
          ? const []
          : <StrongLexiconEntry>[lexical],
      references: packed
          .map(OriginalWordReference.fromPacked)
          .toList(growable: false),
    );
  }

  OriginalWordSearchResult _resultFromTerm(
    String query,
    Map<String, dynamic> term,
    _LanguageAssets assets,
  ) {
    final numbers = _stringList(term['s']);
    return OriginalWordSearchResult(
      query: query,
      displayWord: term['d']?.toString() ?? query,
      lemma: term['l']?.toString() ?? '',
      strongNumbers: numbers,
      lexiconEntries: numbers
          .map((number) => assets.lexicon[number])
          .whereType<StrongLexiconEntry>()
          .toList(growable: false),
      references: _intList(
        term['r'],
      ).map(OriginalWordReference.fromPacked).toList(growable: false),
    );
  }

  OriginalWordSearchResult _empty(String query) => OriginalWordSearchResult(
    query: query,
    displayWord: query,
    lemma: '',
    strongNumbers: const [],
    lexiconEntries: const [],
    references: const [],
  );

  List<bool> _languagesFor(String query) {
    final hasHebrew = RegExp(r'[\u0590-\u05ff\ufb1d-\ufb4f]').hasMatch(query);
    final hasGreek = RegExp(r'[\u0370-\u03ff\u1f00-\u1fff]').hasMatch(query);
    if (hasHebrew) return const <bool>[true];
    if (hasGreek) return const <bool>[false];
    return const <bool>[false, true];
  }

  Future<_LanguageAssets> _load(bool isHebrew) {
    if (isHebrew) {
      return _hebrewFuture ??= _loadLanguage(true);
    }
    return _greekFuture ??= _loadLanguage(false);
  }

  Future<_LanguageAssets> _loadLanguage(bool isHebrew) async {
    final language = isHebrew ? 'hebrew' : 'greek';
    final rawResults = await Future.wait(<Future<String>>[
      rootBundle.loadString('assets/bible/lexicon/strong_$language.json'),
      rootBundle.loadString('assets/bible/lexicon/original_$language.json'),
    ]);
    final decoded = await Future.wait(<Future<Map<String, dynamic>>>[
      compute(_decodeJsonMap, rawResults[0]),
      compute(_decodeJsonMap, rawResults[1]),
    ]);
    final lexiconRaw = Map<String, dynamic>.from(
      decoded[0]['entries'] as Map<dynamic, dynamic>,
    );
    final indexRaw = decoded[1];
    final lexicon = <String, StrongLexiconEntry>{};
    for (final entry in lexiconRaw.entries) {
      lexicon[entry.key] = StrongLexiconEntry.fromCompactJson(
        entry.key,
        Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>),
      );
    }
    return _LanguageAssets(
      lexicon: lexicon,
      terms: _nestedMap(indexRaw['terms']),
      strongReferences: Map<String, dynamic>.from(
        indexRaw['strong'] as Map<dynamic, dynamic>,
      ),
    );
  }

  @visibleForTesting
  static String? normalizeStrongNumber(String value) {
    final match = RegExp(
      r'^\s*([gGhH])0*(\d+)(?:[a-zA-Z]*)?\s*$',
    ).firstMatch(value);
    if (match == null) return null;
    return '${match.group(1)!.toUpperCase()}${int.parse(match.group(2)!)}';
  }
}

Map<String, dynamic> _decodeJsonMap(String raw) =>
    Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>);

Map<String, Map<String, dynamic>> _nestedMap(dynamic raw) {
  final source = Map<String, dynamic>.from(raw as Map<dynamic, dynamic>);
  return source.map(
    (key, value) => MapEntry(
      key,
      Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
    ),
  );
}

List<String> _stringList(dynamic raw) =>
    (raw as List<dynamic>? ?? const <dynamic>[])
        .map((value) => value.toString())
        .toList(growable: false);

List<int> _intList(dynamic raw) => (raw as List<dynamic>? ?? const <dynamic>[])
    .map((value) => value as int)
    .toList(growable: false);

class _LanguageAssets {
  final Map<String, StrongLexiconEntry> lexicon;
  final Map<String, Map<String, dynamic>> terms;
  final Map<String, dynamic> strongReferences;

  const _LanguageAssets({
    required this.lexicon,
    required this.terms,
    required this.strongReferences,
  });
}
