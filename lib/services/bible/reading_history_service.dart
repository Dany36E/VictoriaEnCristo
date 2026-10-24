import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../user_pref_cloud_sync_service.dart';

/// Un pasaje visitado en el lector.
@immutable
class ReadingHistoryEntry {
  final int bookNumber;
  final String bookName;
  final int chapter;

  /// Versículo donde se quedó la persona (primer versículo visible).
  final int verse;
  final String versionId;
  final DateTime at;

  const ReadingHistoryEntry({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.versionId,
    required this.at,
  });

  /// «Juan 3» o «Juan 3:16» (si se quedó más allá del versículo 1).
  String get label =>
      verse > 1 ? '$bookName $chapter:$verse' : '$bookName $chapter';

  bool samePassage(ReadingHistoryEntry other) =>
      other.bookNumber == bookNumber && other.chapter == chapter;

  ReadingHistoryEntry copyWith({int? verse, String? versionId, DateTime? at}) =>
      ReadingHistoryEntry(
        bookNumber: bookNumber,
        bookName: bookName,
        chapter: chapter,
        verse: verse ?? this.verse,
        versionId: versionId ?? this.versionId,
        at: at ?? this.at,
      );

  Map<String, dynamic> toJson() => {
    'b': bookNumber,
    'n': bookName,
    'c': chapter,
    'v': verse,
    'ver': versionId,
    't': at.millisecondsSinceEpoch,
  };

  static ReadingHistoryEntry? fromJson(dynamic raw) {
    try {
      final m = Map<String, dynamic>.from(raw as Map);
      return ReadingHistoryEntry(
        bookNumber: (m['b'] as num).toInt(),
        bookName: m['n'] as String? ?? '',
        chapter: (m['c'] as num).toInt(),
        verse: (m['v'] as num?)?.toInt() ?? 1,
        versionId: m['ver'] as String? ?? 'RVR1960',
        at: DateTime.fromMillisecondsSinceEpoch((m['t'] as num).toInt()),
      );
    } catch (_) {
      return null;
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// READING HISTORY SERVICE
///   - Posición exacta por versión/libro/capítulo (último versículo visible),
///     para volver a ese punto al reabrir el capítulo.
///   - «Continuar leyendo»: última lectura con versículo y versión
///     ([lastReadNotifier], se actualiza solo y la Biblia se refresca al volver).
///   - Historial de pasajes visitados (más reciente primero, sin repetir
///     visitas consecutivas al mismo capítulo).
///
/// Se guarda en SharedPreferences y viaja a la nube con
/// UserPrefCloudSyncService (claves listadas allí).
/// ═══════════════════════════════════════════════════════════════════════════
class ReadingHistoryService {
  ReadingHistoryService._();
  static final ReadingHistoryService I = ReadingHistoryService._();

  // Claves antiguas (las sigue usando el resto de la app).
  static const kLastBook = 'lastReadBookNumber';
  static const kLastBookName = 'lastReadBookName';
  static const kLastChapter = 'lastReadChapter';
  // Claves nuevas.
  static const kLastVerse = 'lastReadVerse';
  static const kLastVersion = 'lastReadVersion';
  static const kHistory = 'bible_reading_history_v1';
  static const kPositions = 'bible_reading_positions_v1';

  static const int maxHistory = 100;
  static const int maxPositions = 300;

  SharedPreferences? _prefs;
  bool _loaded = false;
  Future<void>? _loading;

  /// Posiciones: 'VERSION:libro:capítulo' → versículo. El orden de inserción
  /// es el de uso (el más reciente al final) para recortar los viejos.
  final Map<String, int> _positions = {};

  final ValueNotifier<ReadingHistoryEntry?> lastReadNotifier = ValueNotifier(
    null,
  );
  final ValueNotifier<List<ReadingHistoryEntry>> historyNotifier =
      ValueNotifier(const []);

  Timer? _persistDebounce;

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  /// Vuelve a leer de disco (p. ej. tras restaurar preferencias de la nube).
  Future<void> reload() {
    _loaded = false;
    _loading = null;
    return ensureLoaded();
  }

  Future<void> _load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs!;
      _positions
        ..clear()
        ..addAll(decodePositions(prefs.getString(kPositions)));
      historyNotifier.value = List.unmodifiable(
        decodeHistory(prefs.getString(kHistory)),
      );
      final bn = prefs.getInt(kLastBook);
      final name = prefs.getString(kLastBookName);
      final ch = prefs.getInt(kLastChapter);
      if (bn != null && name != null && ch != null) {
        final head = historyNotifier.value.firstOrNull;
        lastReadNotifier.value = ReadingHistoryEntry(
          bookNumber: bn,
          bookName: name,
          chapter: ch,
          verse: prefs.getInt(kLastVerse) ?? 1,
          versionId: prefs.getString(kLastVersion) ?? 'RVR1960',
          at: head?.at ?? DateTime.now(),
        );
      } else {
        lastReadNotifier.value = historyNotifier.value.firstOrNull;
      }
    } catch (e) {
      debugPrint('📖 [HISTORY] Error cargando historial: $e');
    }
    _loaded = true;
  }

  static String positionKey(String versionId, int book, int chapter) =>
      '$versionId:$book:$chapter';

  /// Versículo donde se quedó la persona en ese capítulo (null = no hay).
  int? positionFor(String versionId, int book, int chapter) =>
      _positions[positionKey(versionId, book, chapter)];

  /// Registra la apertura de un capítulo: historial + «Continuar leyendo».
  Future<void> recordVisit({
    required int bookNumber,
    required String bookName,
    required int chapter,
    required String versionId,
    int verse = 1,
    DateTime? at,
  }) async {
    await ensureLoaded();
    final entry = ReadingHistoryEntry(
      bookNumber: bookNumber,
      bookName: bookName,
      chapter: chapter,
      verse: verse,
      versionId: versionId,
      at: at ?? DateTime.now(),
    );
    historyNotifier.value = List.unmodifiable(
      pushEntry(historyNotifier.value, entry),
    );
    lastReadNotifier.value = entry;
    await _persistNow();
  }

  /// Actualiza el versículo visible (se llama al dejar de desplazarse).
  /// Escribe a disco con un pequeño retraso para no hacerlo en cada scroll.
  void updatePosition({
    required int bookNumber,
    required String bookName,
    required int chapter,
    required String versionId,
    required int verse,
  }) {
    final key = positionKey(versionId, bookNumber, chapter);
    _positions.remove(key);
    if (verse > 1) _positions[key] = verse;
    _trimPositions();

    final head = historyNotifier.value.firstOrNull;
    if (head != null &&
        head.bookNumber == bookNumber &&
        head.chapter == chapter) {
      historyNotifier.value = List.unmodifiable([
        head.copyWith(verse: verse, versionId: versionId),
        ...historyNotifier.value.skip(1),
      ]);
    }
    final last = lastReadNotifier.value;
    if (last == null ||
        last.bookNumber != bookNumber ||
        last.chapter != chapter) {
      lastReadNotifier.value = ReadingHistoryEntry(
        bookNumber: bookNumber,
        bookName: bookName,
        chapter: chapter,
        verse: verse,
        versionId: versionId,
        at: DateTime.now(),
      );
    } else {
      lastReadNotifier.value = last.copyWith(
        verse: verse,
        versionId: versionId,
      );
    }
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 800), _persistNow);
  }

  /// Olvida la posición de un capítulo terminado (al pasar al siguiente), para
  /// que al volver a abrirlo empiece desde arriba.
  void clearPosition(String versionId, int book, int chapter) {
    if (_positions.remove(positionKey(versionId, book, chapter)) != null) {
      _persistDebounce?.cancel();
      _persistDebounce = Timer(const Duration(milliseconds: 800), _persistNow);
    }
  }

  Future<void> clearHistory() async {
    await ensureLoaded();
    historyNotifier.value = const [];
    await _prefs?.remove(kHistory);
    UserPrefCloudSyncService.I.markDirty();
  }

  /// Guarda ya lo pendiente (al salir del lector).
  Future<void> flush() async {
    if (_persistDebounce?.isActive ?? false) {
      _persistDebounce!.cancel();
      await _persistNow();
    }
  }

  Future<void> _persistNow() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs!;
      final last = lastReadNotifier.value;
      await Future.wait([
        prefs.setString(kHistory, encodeHistory(historyNotifier.value)),
        prefs.setString(kPositions, jsonEncode(_positions)),
        if (last != null) ...[
          prefs.setInt(kLastBook, last.bookNumber),
          prefs.setString(kLastBookName, last.bookName),
          prefs.setInt(kLastChapter, last.chapter),
          prefs.setInt(kLastVerse, last.verse),
          prefs.setString(kLastVersion, last.versionId),
        ],
      ]);
      UserPrefCloudSyncService.I.markDirty();
    } catch (e) {
      debugPrint('📖 [HISTORY] Error guardando historial: $e');
    }
  }

  void _trimPositions() {
    while (_positions.length > maxPositions) {
      _positions.remove(_positions.keys.first);
    }
  }

  // ── Lógica pura (probada en test/reading_history_service_test.dart) ──

  /// Agrega [entry] al frente. Si la visita anterior fue al mismo capítulo,
  /// se actualiza en vez de repetirse. Recorta a [max] elementos.
  static List<ReadingHistoryEntry> pushEntry(
    List<ReadingHistoryEntry> history,
    ReadingHistoryEntry entry, {
    int max = maxHistory,
  }) {
    final rest = history.isNotEmpty && history.first.samePassage(entry)
        ? history.skip(1)
        : history;
    return [entry, ...rest].take(max).toList(growable: false);
  }

  static String encodeHistory(List<ReadingHistoryEntry> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<ReadingHistoryEntry> decodeHistory(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .map(ReadingHistoryEntry.fromJson)
          .whereType<ReadingHistoryEntry>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Map<String, int> decodePositions(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return {};
      return {
        for (final e in map.entries)
          if (e.value is num) e.key.toString(): (e.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  @visibleForTesting
  void resetForTest() {
    _persistDebounce?.cancel();
    _positions.clear();
    _loaded = false;
    _loading = null;
    _prefs = null;
    historyNotifier.value = const [];
    lastReadNotifier.value = null;
  }
}
