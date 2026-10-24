import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/interlinear_word.dart';
import '../../models/bible/strong_lexicon_entry.dart';
import '../../utils/original_language_normalizer.dart';

/// Léxico Strong y concordancia por palabra original, completamente locales.
///
/// El servicio carga un idioma a la vez y conserva el JSON compacto en memoria;
/// la decodificación se hace en un isolate (`compute`) para no bloquear la UI.
/// Las definiciones son la traducción propia al español del diccionario de
/// James Strong (1890, dominio público); véase `docs/STRONG_LEXICON_SOURCE.md`.
/// El índice de apariciones se genera a partir de los interlineales locales.
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

  /// Entradas para un número Strong con o sin prefijo: «G26» o «H430»
  /// devuelven una entrada; un número sin prefijo («26») devuelve la griega
  /// y la hebrea que existan con ese número.
  Future<List<StrongLexiconEntry>> lookupStrongNumber(String query) async {
    final normalized = normalizeStrongNumber(query);
    if (normalized != null) {
      final entry = await lookupStrong(normalized);
      return entry == null ? const [] : <StrongLexiconEntry>[entry];
    }
    final bare = bareStrongNumber(query);
    if (bare == null) return const [];
    final out = <StrongLexiconEntry>[];
    for (final prefix in const <String>['G', 'H']) {
      final entry = await lookupStrong('$prefix$bare');
      if (entry != null) out.add(entry);
    }
    return out;
  }

  /// Busca en las definiciones en español, los equivalentes de la KJV y la
  /// transliteración (sin distinguir mayúsculas ni tildes). Devuelve primero
  /// las coincidencias en la transliteración, luego en los equivalentes y
  /// por último en la definición.
  Future<List<StrongLexiconEntry>> searchDefinitions(
    String query, {
    int limit = 40,
  }) async {
    final tokens = foldSpanishText(
      query,
    ).split(' ').where((token) => token.isNotEmpty).toList(growable: false);
    if (tokens.isEmpty || tokens.join().length < 2) return const [];
    final scored = <(int, int, StrongLexiconEntry)>[];
    for (final isHebrew in const <bool>[false, true]) {
      final assets = await _load(isHebrew);
      for (final indexed in assets.searchIndex) {
        final score = indexed.score(tokens);
        if (score == null) continue;
        scored.add((score, isHebrew ? 1 : 0, indexed.entry));
      }
    }
    scored.sort((a, b) {
      final byScore = a.$1.compareTo(b.$1);
      if (byScore != 0) return byScore;
      final byLanguage = a.$2.compareTo(b.$2);
      if (byLanguage != 0) return byLanguage;
      return _strongValue(
        a.$3.strongNumber,
      ).compareTo(_strongValue(b.$3.strongNumber));
    });
    return scored.take(limit).map((item) => item.$3).toList(growable: false);
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
    final bare = bareStrongNumber(query);
    if (bare != null) {
      return _searchBareStrong(query, bare);
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

  /// Número sin prefijo: reúne la entrada hebrea (AT) y la griega (NT).
  Future<OriginalWordSearchResult> _searchBareStrong(
    String query,
    int number,
  ) async {
    final hebrew = await _searchStrong(query, 'H$number');
    final greek = await _searchStrong(query, 'G$number');
    final parts = <OriginalWordSearchResult>[
      hebrew,
      greek,
    ].where((part) => part.hasData).toList(growable: false);
    return OriginalWordSearchResult(
      query: query,
      displayWord: parts.length == 1
          ? parts.first.displayWord
          : 'Strong $number',
      lemma: parts.length == 1 ? parts.first.lemma : '',
      strongNumbers: <String>[for (final part in parts) ...part.strongNumbers],
      lexiconEntries: <StrongLexiconEntry>[
        for (final part in parts) ...part.lexiconEntries,
      ],
      references: <OriginalWordReference>[
        for (final part in parts) ...part.references,
      ],
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
      searchIndex: lexicon.values
          .map(_IndexedEntry.new)
          .toList(growable: false),
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

  /// Número Strong sin prefijo («26», «0430»), o null.
  @visibleForTesting
  static int? bareStrongNumber(String value) {
    final match = RegExp(r'^\s*0*(\d{1,5})\s*$').firstMatch(value);
    if (match == null) return null;
    final number = int.parse(match.group(1)!);
    return number == 0 ? null : number;
  }

  /// true si [value] es un número Strong, con o sin prefijo G/H.
  static bool isStrongNumberQuery(String value) =>
      normalizeStrongNumber(value) != null || bareStrongNumber(value) != null;

  /// Minúsculas, sin tildes ni signos de transliteración, para buscar en
  /// las definiciones en español y en las transliteraciones.
  @visibleForTesting
  static String foldSpanishText(String value) {
    final buffer = StringBuffer();
    var lastWasSpace = true;
    for (final rune in value.toLowerCase().runes) {
      final character = String.fromCharCode(rune);
      if (_ignoredMarks.contains(character)) continue;
      final folded = _latinFold[character];
      final isPlain =
          (rune >= 0x61 && rune <= 0x7a) || (rune >= 0x30 && rune <= 0x39);
      if (folded != null || isPlain) {
        buffer.write(folded ?? character);
        lastWasSpace = false;
      } else if (!lastWasSpace) {
        buffer.write(' ');
        lastWasSpace = true;
      }
    }
    return buffer.toString().trim();
  }
}

int _strongValue(String strongNumber) =>
    int.tryParse(strongNumber.substring(1)) ?? 0;

const Set<String> _ignoredMarks = {'ʼ', 'ʻ', "'", '’', '`', 'ʾ', 'ʿ'};

const Map<String, String> _latinFold = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ā': 'a', 'ă': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ᵉ': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'ō': 'o', 'ŏ': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', //
  'ñ': 'n', 'ç': 'c', 'ṭ': 't', 'ṣ': 's', 'ḥ': 'h', 'ẓ': 'z', //
  'ḕ': 'e', 'ḗ': 'e', 'ḯ': 'i', 'ṑ': 'o', 'ṓ': 'o', 'ý': 'y', 'ÿ': 'y',
  'ŷ': 'y', 'ˢ': 's',
};

/// Textos plegados de una entrada, calculados una sola vez al cargar.
class _IndexedEntry {
  _IndexedEntry(this.entry)
    : transliteration = StrongLexiconService.foldSpanishText(
        entry.transliteration,
      ),
      usage = ' ${StrongLexiconService.foldSpanishText(entry.biblicalUsage)} ',
      definition =
          ' ${StrongLexiconService.foldSpanishText(entry.definition)} ';

  final StrongLexiconEntry entry;
  final String transliteration;
  final String usage;
  final String definition;

  /// 0 = transliteración, 1-2 = equivalentes, 3-4 = definición, 5 = prefijo
  /// de la transliteración; null si no aparecen todos los términos. La
  /// palabra completa puntúa mejor que el prefijo.
  int? score(List<String> tokens) {
    final joined = tokens.join(' ');
    if (transliteration == joined) return 0;
    if (_all(usage, tokens, wholeWord: true)) return 1;
    if (_all(usage, tokens, wholeWord: false)) return 2;
    if (_all(definition, tokens, wholeWord: true)) return 3;
    if (_all(definition, tokens, wholeWord: false)) return 4;
    if (transliteration.startsWith(joined)) return 5;
    return null;
  }

  static bool _all(
    String text,
    List<String> tokens, {
    required bool wholeWord,
  }) {
    for (final token in tokens) {
      if (!text.contains(wholeWord ? ' $token ' : ' $token')) return false;
    }
    return true;
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
  final List<_IndexedEntry> searchIndex;
  final Map<String, Map<String, dynamic>> terms;
  final Map<String, dynamic> strongReferences;

  const _LanguageAssets({
    required this.lexicon,
    required this.searchIndex,
    required this.terms,
    required this.strongReferences,
  });
}
