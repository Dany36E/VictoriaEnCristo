import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../connectivity_service.dart';

/// Servicio para IQ Bible API (via RapidAPI).
/// Reemplaza BlbApiService como fuente principal de estudio bíblico.
///
/// Endpoints: GetVerse, GetChapter, GetStrongsNumber,
/// GetOriginalVerseByVerseId, GetCrossReferences, GetChapterAudio,
/// GetBook, GetRandomVerse.
class IqBibleService {
  IqBibleService._();
  static final IqBibleService instance = IqBibleService._();

  static const String _baseUrl = 'https://iq-bible.p.rapidapi.com';
  static const String _host = 'iq-bible.p.rapidapi.com';
  static const String _monthCountKey = 'iqb_requests_month';
  static const String _monthDateKey = 'iqb_requests_month_date';

  SharedPreferences? _prefs;
  String? _apiKey;

  final ValueNotifier<bool> hasApiKey = ValueNotifier(false);
  final ValueNotifier<int> monthlyRequestCount = ValueNotifier(0);

  // ─── INIT ───────────────────────────────────────────────────

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _apiKey = ApiConfig.iqBibleKey.isNotEmpty ? ApiConfig.iqBibleKey : null;
    hasApiKey.value = _apiKey != null;
    _loadMonthlyCount();
  }

  // ─── VERSE ID HELPERS ───────────────────────────────────────

  /// Construye el verseId para IQ Bible: {book}{chapter 3-pad}{verse 3-pad}
  static String buildVerseId(int bookNumber, int chapter, int verse) {
    return '$bookNumber'
        '${chapter.toString().padLeft(3, '0')}'
        '${verse.toString().padLeft(3, '0')}';
  }

  /// Construye chapterId: {book}{chapter 3-pad}
  static String buildChapterId(int bookNumber, int chapter) {
    return '$bookNumber${chapter.toString().padLeft(3, '0')}';
  }

  // ─── ENDPOINTS ──────────────────────────────────────────────

  /// A) Versículo con Strong's numbers.
  Future<IqResult<Map<String, dynamic>>> getVerse(
    int bookNumber, int chapter, int verse, {
    String versionId = 'rvr60',
  }) async {
    final vid = buildVerseId(bookNumber, chapter, verse);
    final cacheKey = 'iqb_verse_${vid}_$versionId';
    final cached = _readCache(cacheKey);
    if (cached != null) {
      return IqResult(status: IqStatus.success, data: cached, fromCache: true);
    }
    return _get('/GetVerse', {'verseId': vid, 'versionId': versionId}, cacheKey);
  }

  /// B) Capítulo completo.
  Future<IqResult<Map<String, dynamic>>> getChapter(
    int bookNumber, int chapter, {
    String versionId = 'rvr60',
  }) async {
    final cid = buildChapterId(bookNumber, chapter);
    final cacheKey = 'iqb_chapter_${cid}_$versionId';
    final cached = _readCache(cacheKey);
    if (cached != null) {
      return IqResult(status: IqStatus.success, data: cached, fromCache: true);
    }
    return _get('/GetChapter', {'chapterId': cid, 'versionId': versionId}, cacheKey);
  }

  /// C) Strong's concordance por número.
  Future<IqResult<Map<String, dynamic>>> getStrongsNumber(String strongsId) async {
    final cacheKey = 'iqb_strong_$strongsId';
    final cached = _readCache(cacheKey);
    if (cached != null) {
      return IqResult(status: IqStatus.success, data: cached, fromCache: true);
    }
    return _get('/GetStrongsNumber', {'strongsId': strongsId}, cacheKey);
  }

  /// D) Texto original griego/hebreo por versículo.
  Future<IqResult<Map<String, dynamic>>> getOriginalVerse(
    int bookNumber, int chapter, int verse,
  ) async {
    final vid = buildVerseId(bookNumber, chapter, verse);
    final cacheKey = 'iqb_orig_$vid';
    final cached = _readCache(cacheKey);
    if (cached != null) {
      return IqResult(status: IqStatus.success, data: cached, fromCache: true);
    }
    return _get('/GetOriginalVerseByVerseId', {'verseId': vid}, cacheKey);
  }

  /// E) Referencias cruzadas.
  Future<IqResult<Map<String, dynamic>>> getCrossReferences(
    int bookNumber, int chapter, int verse,
  ) async {
    final vid = buildVerseId(bookNumber, chapter, verse);
    final cacheKey = 'iqb_xref_$vid';
    final cached = _readCache(cacheKey, maxDays: 30);
    if (cached != null) {
      return IqResult(status: IqStatus.success, data: cached, fromCache: true);
    }
    return _get('/GetCrossReferences', {'verseId': vid}, cacheKey);
  }

  /// F) Audio del capítulo (narración de voz humana).
  Future<IqResult<Map<String, dynamic>>> getChapterAudio(
    int bookNumber, int chapter, {
    String versionId = 'kjv',
  }) async {
    final cid = buildChapterId(bookNumber, chapter);
    final cacheKey = 'iqb_audio_${cid}_$versionId';
    final cached = _readCache(cacheKey, maxDays: 7);
    if (cached != null) {
      return IqResult(status: IqStatus.success, data: cached, fromCache: true);
    }
    return _get('/GetChapterAudio', {'chapterId': cid, 'versionId': versionId}, cacheKey);
  }

  /// G) Info del libro (autor, fecha, contexto en español).
  Future<IqResult<Map<String, dynamic>>> getBook(int bookId) async {
    final cacheKey = 'iqb_book_$bookId';
    final cached = _readCache(cacheKey);
    if (cached != null) {
      return IqResult(status: IqStatus.success, data: cached, fromCache: true);
    }
    return _get('/GetBook', {'bookId': '$bookId', 'language': 'spanish'}, cacheKey);
  }

  /// H) Versículo aleatorio.
  Future<IqResult<Map<String, dynamic>>> getRandomVerse({
    String versionId = 'rvr60',
  }) async {
    // No cache — cada llamada debe ser fresca.
    return _get('/GetRandomVerse', {'versionId': versionId}, null);
  }

  // ─── HTTP CORE ──────────────────────────────────────────────

  Future<IqResult<Map<String, dynamic>>> _get(
    String endpoint,
    Map<String, String> params,
    String? cacheKey,
  ) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return const IqResult(status: IqStatus.noApiKey);
    }

    if (!ConnectivityService.I.hasInternet) {
      return const IqResult(status: IqStatus.networkError, message: 'offline');
    }

    try {
      final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: params);
      final resp = await http.get(uri, headers: {
        'x-rapidapi-host': _host,
        'x-rapidapi-key': _apiKey!,
      }).timeout(const Duration(seconds: 8));

      _incrementMonthlyCount();

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return const IqResult(status: IqStatus.invalidKey);
      }
      if (resp.statusCode == 429) {
        return const IqResult(status: IqStatus.rateLimited);
      }
      if (resp.statusCode != 200) {
        return IqResult(status: IqStatus.networkError, message: '${resp.statusCode}');
      }

      final data = json.decode(resp.body) as Map<String, dynamic>;

      if (cacheKey != null) {
        _writeCache(cacheKey, data);
      }

      return IqResult(status: IqStatus.success, data: data);
    } on TimeoutException {
      return const IqResult(status: IqStatus.networkError, message: 'timeout');
    } catch (e) {
      return IqResult(status: IqStatus.networkError, message: e.toString());
    }
  }

  // ─── CACHE (SharedPreferences) ──────────────────────────────

  Map<String, dynamic>? _readCache(String key, {int? maxDays}) {
    final raw = _prefs?.getString(key);
    if (raw == null) return null;

    if (maxDays != null) {
      final ts = _prefs?.getInt('${key}_ts') ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > maxDays * 86400000) return null;
    }

    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('📚 [IQ] JSON decode cache error: $e');
      return null;
    }
  }

  void _writeCache(String key, Map<String, dynamic> data) {
    _prefs?.setString(key, json.encode(data));
    _prefs?.setInt('${key}_ts', DateTime.now().millisecondsSinceEpoch);
  }

  // ─── RATE LIMITING ──────────────────────────────────────────

  void _loadMonthlyCount() {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final storedMonth = _prefs?.getString(_monthDateKey) ?? '';

    if (storedMonth != currentMonth) {
      _prefs?.setString(_monthDateKey, currentMonth);
      _prefs?.setInt(_monthCountKey, 0);
      monthlyRequestCount.value = 0;
    } else {
      monthlyRequestCount.value = _prefs?.getInt(_monthCountKey) ?? 0;
    }
  }

  void _incrementMonthlyCount() {
    final count = (_prefs?.getInt(_monthCountKey) ?? 0) + 1;
    _prefs?.setInt(_monthCountKey, count);
    monthlyRequestCount.value = count;
  }

  /// Versiones soportadas por IQ Bible en español.
  static const Map<String, String> supportedVersions = {
    'rvr60': 'Reina Valera 1960',
    'nvi': 'Nueva Versión Internacional',
    'lbla': 'La Biblia de las Américas',
    'kjv': 'King James (Strong\'s)',
  };
}

// ─── RESULT TYPE ────────────────────────────────────────────

enum IqStatus { success, noApiKey, invalidKey, rateLimited, networkError }

class IqResult<T> {
  final IqStatus status;
  final T? data;
  final String? message;
  final bool fromCache;

  const IqResult({
    required this.status,
    this.data,
    this.message,
    this.fromCache = false,
  });

  bool get isSuccess => status == IqStatus.success;
}
