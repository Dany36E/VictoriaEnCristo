import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Referencia ligera a un pasaje (libro + capítulo + versículo opcional).
/// Se usa para "Recientes" y "Favoritos" en el selector de capítulo/versículo.
class PassageRef {
  final int bookNumber;
  final String bookName;
  final String abbreviation;
  final int chapter;
  final int? verse;

  const PassageRef({
    required this.bookNumber,
    required this.bookName,
    required this.abbreviation,
    required this.chapter,
    this.verse,
  });

  /// Etiqueta corta para el chip: "Sal 23" o "Jn 3:16".
  String get label =>
      verse == null ? '$abbreviation $chapter' : '$abbreviation $chapter:$verse';

  /// Clave de identidad (ignora el nombre para deduplicar).
  String get key => '$bookNumber:$chapter:${verse ?? 0}';

  Map<String, dynamic> toJson() => {
        'b': bookNumber,
        'n': bookName,
        'a': abbreviation,
        'c': chapter,
        if (verse != null) 'v': verse,
      };

  static PassageRef? fromJson(dynamic raw) {
    try {
      final m = Map<String, dynamic>.from(raw as Map);
      return PassageRef(
        bookNumber: (m['b'] as num).toInt(),
        bookName: m['n'] as String? ?? '',
        abbreviation: m['a'] as String? ?? '',
        chapter: (m['c'] as num).toInt(),
        verse: m['v'] == null ? null : (m['v'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Historial local (SharedPreferences) de pasajes recientes y favoritos.
/// Es intencionalmente local y global (no por-usuario): es una comodidad de
/// navegación, no datos sensibles.
class PassageHistoryService {
  PassageHistoryService._();
  static final PassageHistoryService I = PassageHistoryService._();

  static const _kRecents = 'passage_history_recents_v1';
  static const _kFavorites = 'passage_history_favorites_v1';
  static const _maxRecents = 12;
  static const _maxFavorites = 24;

  SharedPreferences? _prefs;
  bool _loaded = false;

  final ValueNotifier<List<PassageRef>> recentsNotifier = ValueNotifier([]);
  final ValueNotifier<List<PassageRef>> favoritesNotifier = ValueNotifier([]);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _prefs ??= await SharedPreferences.getInstance();
    recentsNotifier.value = _decode(_kRecents);
    favoritesNotifier.value = _decode(_kFavorites);
    _loaded = true;
  }

  List<PassageRef> _decode(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .map(PassageRef.fromJson)
          .whereType<PassageRef>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist(String key, List<PassageRef> list) async {
    await _prefs?.setString(
      key,
      jsonEncode(list.map((p) => p.toJson()).toList()),
    );
  }

  /// Registra un pasaje como reciente (lo mueve al frente, sin duplicados).
  Future<void> recordRecent(PassageRef ref) async {
    await ensureLoaded();
    final next = [
      ref,
      ...recentsNotifier.value.where((p) => p.key != ref.key),
    ].take(_maxRecents).toList(growable: false);
    recentsNotifier.value = next;
    await _persist(_kRecents, next);
  }

  bool isFavorite(PassageRef ref) =>
      favoritesNotifier.value.any((p) => p.key == ref.key);

  /// Alterna favorito. Devuelve true si quedó marcado como favorito.
  Future<bool> toggleFavorite(PassageRef ref) async {
    await ensureLoaded();
    final exists = isFavorite(ref);
    final List<PassageRef> next;
    if (exists) {
      next = favoritesNotifier.value
          .where((p) => p.key != ref.key)
          .toList(growable: false);
    } else {
      next = [ref, ...favoritesNotifier.value].take(_maxFavorites).toList(
            growable: false,
          );
    }
    favoritesNotifier.value = next;
    await _persist(_kFavorites, next);
    return !exists;
  }
}
