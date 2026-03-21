import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/dictionary_entry.dart';

/// Servicio para diccionario bíblico (Easton + Hitchcock).
/// Precarga ambos diccionarios al inicializar (~20KB total).
class BibleDictionaryService {
  BibleDictionaryService._();
  static final instance = BibleDictionaryService._();

  List<DictionaryEntry> _easton = [];
  List<DictionaryEntry> _hitchcock = [];
  List<DictionaryEntry> _all = [];

  bool _initialized = false;
  bool get isInitialized => _initialized;

  int get eastonCount => _easton.length;
  int get hitchcockCount => _hitchcock.length;
  int get totalCount => _all.length;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final results = await Future.wait([
        rootBundle.loadString('assets/bible/dictionary/easton.json'),
        rootBundle.loadString('assets/bible/dictionary/hitchcock.json'),
      ]);

      _easton = _parseEntries(results[0], 'Easton');
      _hitchcock = _parseEntries(results[1], 'Hitchcock');
      _all = [..._easton, ..._hitchcock]
        ..sort((a, b) => a.term.compareTo(b.term));
      _initialized = true;
    } catch (e) {
      debugPrint('BibleDictionaryService: Error cargando diccionarios: $e');
      _initialized = true;
    }
  }

  List<DictionaryEntry> _parseEntries(String json, String source) {
    final list = jsonDecode(json) as List;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return DictionaryEntry(
        term: m['term'] as String? ?? '',
        definition: m['definition'] as String? ?? '',
        references: (m['references'] as List?)
                ?.map((r) => r.toString())
                .toList() ??
            [],
        source: source,
      );
    }).toList();
  }

  /// Busca entradas por texto (term o definition contiene la query).
  List<DictionaryEntry> search(String query) {
    if (query.isEmpty) return _all;
    final lower = query.toLowerCase();
    return _all.where((e) {
      return e.term.toLowerCase().contains(lower) ||
          e.definition.toLowerCase().contains(lower);
    }).toList();
  }

  /// Busca por término exacto (case-insensitive).
  DictionaryEntry? lookupTerm(String term) {
    final lower = term.toLowerCase();
    try {
      return _all.firstWhere((e) => e.term.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  /// Retorna todas las entradas.
  List<DictionaryEntry> get allEntries => _all;

  /// Solo entradas de Easton.
  List<DictionaryEntry> get eastonEntries => _easton;

  /// Solo entradas de Hitchcock.
  List<DictionaryEntry> get hitchcockEntries => _hitchcock;
}
