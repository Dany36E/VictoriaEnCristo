import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/dictionary_entry.dart';

/// Servicio para el diccionario bíblico (Easton en español + Hitchcock).
///
/// Easton son ~3.900 entradas (~3,7 MB): se carga solo cuando se abre el
/// diccionario, y la decodificación del JSON y el índice de búsqueda se
/// construyen en otro isolate para no trabar la interfaz.
class BibleDictionaryService {
  BibleDictionaryService._();
  static final instance = BibleDictionaryService._();

  static const eastonAsset = 'assets/bible/dictionary/easton.json';
  static const hitchcockAsset = 'assets/bible/dictionary/hitchcock.json';

  /// Atribución obligatoria (UI y docs/ASSET_PROVENANCE_CHECKLIST.md).
  static const eastonAttribution =
      'Diccionario Bíblico de Easton (1897), dominio público. '
      'Traducción propia al español.';

  List<DictionaryEntry> _easton = const [];
  List<DictionaryEntry> _hitchcock = const [];
  List<DictionaryEntry> _all = const [];
  Map<String, DictionaryEntry> _byId = const {};
  List<_Keys> _keys = const [];

  Future<void>? _loading;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  int get eastonCount => _easton.length;
  int get hitchcockCount => _hitchcock.length;
  int get totalCount => _all.length;

  /// Carga perezosa; llamadas repetidas comparten la misma carga.
  Future<void> init() => _loading ??= _load();

  Future<void> _load() async {
    try {
      // Secuencial: en pruebas, Future.wait sobre rootBundle.load devolvía
      // una lista vacía.
      final bytes = <Uint8List>[];
      for (final asset in [eastonAsset, hitchcockAsset]) {
        final d = await rootBundle.load(asset);
        bytes.add(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
      }
      final parsed = await compute(parseDictionaries, bytes);
      _easton = parsed.easton;
      _hitchcock = parsed.hitchcock;
      _all = parsed.all;
      _keys = [
        for (var i = 0; i < _all.length; i++)
          _Keys(parsed.terms[i], parsed.termsEn[i], parsed.texts[i]),
      ];
      _byId = {for (final e in _all) e.id: e};
    } catch (e) {
      debugPrint('BibleDictionaryService: Error cargando diccionarios: $e');
      _loading = null; // permitir reintento
    }
    _initialized = true;
  }

  /// Minúsculas, sin tildes, sin guiones ni apóstrofos («En-ganim» → «enganim»).
  static String fold(String input) {
    final sb = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final r = _foldMap[rune];
      if (r == null) {
        sb.writeCharCode(rune);
      } else if (r.isNotEmpty) {
        sb.write(r);
      }
    }
    return sb.toString();
  }

  static const Map<int, String> _foldMap = {
    0xE1: 'a', 0xE0: 'a', 0xE4: 'a', 0xE2: 'a', //
    0xE9: 'e', 0xE8: 'e', 0xEB: 'e', 0xEA: 'e',
    0xED: 'i', 0xEC: 'i', 0xEF: 'i', 0xEE: 'i',
    0xF3: 'o', 0xF2: 'o', 0xF6: 'o', 0xF4: 'o',
    0xFA: 'u', 0xF9: 'u', 0xFC: 'u', 0xFB: 'u',
    0xF1: 'n', 0xE7: 'c',
    0x2D: '', 0x27: '', 0x2018: '', 0x2019: '', 0x2010: '', 0x2011: '',
  };

  /// Busca sin distinguir tildes ni mayúsculas. Orden: término exacto,
  /// término (español o inglés) que empieza por la búsqueda, término que la
  /// contiene y, desde 3 letras, definiciones que la contienen.
  List<DictionaryEntry> search(String query) {
    final q = fold(query.trim());
    if (q.isEmpty) return _all;
    final exact = <DictionaryEntry>[];
    final prefix = <DictionaryEntry>[];
    final contains = <DictionaryEntry>[];
    final inText = <DictionaryEntry>[];
    for (var i = 0; i < _all.length; i++) {
      final k = _keys[i];
      if (k.term == q || k.termEn == q) {
        exact.add(_all[i]);
      } else if (k.term.startsWith(q) || k.termEn.startsWith(q)) {
        prefix.add(_all[i]);
      } else if (k.term.contains(q) || k.termEn.contains(q)) {
        contains.add(_all[i]);
      } else if (q.length >= 3 && k.text.contains(q)) {
        inText.add(_all[i]);
      }
    }
    return [...exact, ...prefix, ...contains, ...inText];
  }

  /// Busca por término exacto (sin tildes ni mayúsculas), en español o inglés.
  DictionaryEntry? lookupTerm(String term) {
    final q = fold(term.trim());
    for (var i = 0; i < _all.length; i++) {
      if (_keys[i].term == q || _keys[i].termEn == q) return _all[i];
    }
    return null;
  }

  /// Entrada por id («e0054»), para los enlaces «Véase».
  DictionaryEntry? byId(String id) => _byId[id];

  /// Retorna todas las entradas.
  List<DictionaryEntry> get allEntries => _all;

  /// Solo entradas de Easton.
  List<DictionaryEntry> get eastonEntries => _easton;

  /// Solo entradas de Hitchcock.
  List<DictionaryEntry> get hitchcockEntries => _hitchcock;
}

class _Keys {
  final String term;
  final String termEn;
  final String text;
  const _Keys(this.term, this.termEn, this.text);
}

/// Resultado de [parseDictionaries] (se envía de vuelta desde el isolate).
class ParsedDictionaries {
  final List<DictionaryEntry> easton;
  final List<DictionaryEntry> hitchcock;
  final List<DictionaryEntry> all;
  final List<String> terms;
  final List<String> termsEn;
  final List<String> texts;
  const ParsedDictionaries(
    this.easton,
    this.hitchcock,
    this.all,
    this.terms,
    this.termsEn,
    this.texts,
  );
}

/// Decodifica [Easton, Hitchcock] y arma el índice. Pública para `compute`
/// y para las pruebas.
ParsedDictionaries parseDictionaries(List<Uint8List> bytes) {
  List<DictionaryEntry> parse(Uint8List data, String source, String prefix) {
    final list = jsonDecode(utf8.decode(data)) as List;
    var i = 0;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      i++;
      List<String> strings(Object? v) =>
          (v as List?)?.map((r) => r.toString()).toList() ?? const [];
      return DictionaryEntry(
        id: m['id'] as String? ?? '$prefix$i',
        term: m['term'] as String? ?? '',
        termEn: m['term_en'] as String? ?? '',
        definition: m['definition'] as String? ?? '',
        references: strings(m['references']),
        see: strings(m['see']),
        source: source,
      );
    }).toList();
  }

  final easton = parse(bytes[0], 'Easton', 'e');
  final hitchcock = parse(bytes[1], 'Hitchcock', 'h');
  final folded = [
    for (final e in [...easton, ...hitchcock])
      (e, BibleDictionaryService.fold(e.term)),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  final all = [for (final p in folded) p.$1];
  return ParsedDictionaries(
    easton,
    hitchcock,
    all,
    [for (final p in folded) p.$2],
    [for (final e in all) BibleDictionaryService.fold(e.termEn)],
    [for (final e in all) BibleDictionaryService.fold(e.plainDefinition)],
  );
}
