/// ═══════════════════════════════════════════════════════════════════════════
/// DEVOTIONAL REPOSITORY (RFC-001)
///
/// Carga el pool unificado de devocionales. Estrategia:
/// 1. Intenta `assets/content/devotional_pool.json` (formato nuevo).
/// 2. Cae a `assets/content/devotionals.json` (legacy plano) y lo
///    convierte vía [DevotionalEntry.fromLegacyJson].
/// 3. Cae al fallback hardcoded de [Devotionals._fallbackDevotionals]
///    (vía [Devotionals.allDevotionals]).
///
/// Singleton `.I`. Carga lazy. Cache en memoria.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/devotionals.dart';
import '../models/content_enums.dart';
import '../models/devotional_entry.dart';
import '../models/plan_metadata.dart';

class DevotionalRepository {
  DevotionalRepository._();
  static final DevotionalRepository I = DevotionalRepository._();

  static const _newPoolPath = 'assets/content/devotional_pool.json';
  static const _legacyPath = 'assets/content/devotionals.json';

  List<DevotionalEntry> _entries = const <DevotionalEntry>[];
  bool _loaded = false;
  Future<void>? _loading;

  /// Total de entradas cargadas
  int get count => _entries.length;
  List<DevotionalEntry> get all => List.unmodifiable(_entries);
  bool get isLoaded => _loaded;

  /// Garantiza que el pool está cargado.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      // 1. Intentar pool nuevo
      try {
        final raw = await rootBundle.loadString(_newPoolPath);
        final data = jsonDecode(raw);
        final list = data is List
            ? data
            : (data is Map<String, dynamic> && data['entries'] is List)
                ? data['entries'] as List
                : null;
        if (list != null && list.isNotEmpty) {
          _entries = list
              .whereType<Map<String, dynamic>>()
              .map(DevotionalEntry.fromJson)
              .toList(growable: false);
          _loaded = true;
          if (kDebugMode) {
            debugPrint('[DevotionalRepo] pool nuevo cargado: ${_entries.length}');
          }
          return;
        }
      } catch (_) {
        // continuar con legacy
      }

      // 2. Legacy JSON plano
      try {
        final raw = await rootBundle.loadString(_legacyPath);
        final data = jsonDecode(raw) as List<dynamic>;
        _entries = data
            .whereType<Map<String, dynamic>>()
            .map(DevotionalEntry.fromLegacyJson)
            .toList(growable: false);
        if (_entries.isNotEmpty) {
          _loaded = true;
          if (kDebugMode) {
            debugPrint('[DevotionalRepo] legacy cargado: ${_entries.length}');
          }
          return;
        }
      } catch (_) {
        // continuar con fallback
      }

      // 3. Fallback hardcoded
      await Devotionals.init();
      _entries = Devotionals.allDevotionals
          .map((d) => DevotionalEntry.fromLegacyJson(<String, dynamic>{
                'day': d.day,
                'title': d.title,
                'verse': d.verse,
                'verseReference': d.verseReference,
                'reflection': d.reflection,
                'challenge': d.challenge,
                'prayer': d.prayer,
              }))
          .toList(growable: false);
      _loaded = true;
      if (kDebugMode) {
        debugPrint('[DevotionalRepo] fallback hardcoded: ${_entries.length}');
      }
    } catch (e, st) {
      debugPrint('[DevotionalRepo] error cargando pool: $e\n$st');
      _entries = const <DevotionalEntry>[];
      _loaded = true;
    }
  }

  /// Devuelve la entrada por ID, o null.
  DevotionalEntry? byId(String id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Devuelve la entrada legacy por día (1-N). Compat con
  /// `Devotionals.getDevotionalForDay`.
  DevotionalEntry? byLegacyDay(int day) {
    if (_entries.isEmpty) return null;
    final byField = _entries.where((e) => e.legacyDay == day).toList();
    if (byField.isNotEmpty) return byField.first;
    final idx = (day - 1) % _entries.length;
    return _entries[idx.clamp(0, _entries.length - 1)];
  }

  /// Filtra por gigante y/o etapa. No lanza, devuelve lista (puede ser vacía).
  List<DevotionalEntry> byFilter({
    GiantId? giant,
    ContentStage? stage,
    bool requireApproved = false,
  }) {
    return _entries.where((e) {
      if (requireApproved && e.metadata.reviewLevel != PlanReviewLevel.approved) {
        return false;
      }
      if (stage != null && e.metadata.stage != stage) return false;
      if (giant != null) {
        // Si la entrada tiene giants explícitos, debe contener el giant.
        // Si no tiene giants (general), también aplica.
        if (e.metadata.giants.isNotEmpty &&
            !e.metadata.giants.contains(giant)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  /// Forzar recarga (testing / hot-reload de contenido).
  @visibleForTesting
  void resetForTesting() {
    _entries = const <DevotionalEntry>[];
    _loaded = false;
    _loading = null;
  }

  /// Inyectar entradas directamente (tests).
  @visibleForTesting
  void seedForTesting(List<DevotionalEntry> entries) {
    _entries = List.unmodifiable(entries);
    _loaded = true;
    _loading = Future.value();
  }
}
