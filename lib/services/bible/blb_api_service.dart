import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../models/bible/blb_models.dart';
import '../../utils/blb_translator.dart';

/// Servicio para consultar la API de Blue Letter Bible.
///
/// Funcionalidades:
/// - Búsqueda de versículos con números Strong
/// - Consulta de lexicón (definiciones griego/hebreo)
/// - Referencias cruzadas
/// - Caché local (lexicón permanente, cross-refs 30 días)
/// - Rate limiting (~500 peticiones/día)
class BlbApiService {
  BlbApiService._();
  static final BlbApiService instance = BlbApiService._();

  static const String _baseUrl =
      'https://api.blueletterbible.org/BibleSearch/rest/1';
  static const String _dailyCountKey = 'blb_daily_count';
  static const String _dailyDateKey = 'blb_daily_date';
  static const int _dailyLimit = 480; // margen bajo el límite de 500

  SharedPreferences? _prefs;
  String? _apiKey;

  static const String _apiKeyPrefKey = 'blb_api_key_user';

  final ValueNotifier<bool> hasApiKey = ValueNotifier(false);
  final ValueNotifier<int> dailyRequestCount = ValueNotifier(0);

  /// Inicializa el servicio cargando la API key y preferencias.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Prioridad: key guardada por el usuario > key hardcodeada en ApiConfig
    final userKey = _prefs?.getString(_apiKeyPrefKey);
    if (userKey != null && userKey.isNotEmpty) {
      _apiKey = userKey;
    } else {
      _apiKey = ApiConfig.blbKey.isNotEmpty ? ApiConfig.blbKey : null;
    }
    hasApiKey.value = _apiKey != null;
    _loadDailyCount();
  }

  /// Guarda una API key proporcionada por el usuario y la activa.
  Future<void> setApiKey(String key) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_apiKeyPrefKey, key);
    _apiKey = key;
    hasApiKey.value = true;
  }

  /// Verifica que la API key actual funcione con una petición de prueba.
  /// Retorna true si la key es válida.
  Future<bool> verifyApiKey() async {
    if (_apiKey == null || _apiKey!.isEmpty) return false;
    try {
      // Hacer una búsqueda simple para verificar que la key funciona
      final uri = Uri.parse(
        '$_baseUrl/search/search?type=verseSearch'
        '&verseRange=Jhn.3.16&version=KJV'
        '&output=json&apiKey=$_apiKey',
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── VERSE + STRONG'S ───────────────────────────────────────

  /// Obtiene las palabras de un versículo con números Strong (KJV).
  Future<BLBResult<List<BLBWord>>> getVerseWithStrongs({
    required int bookNumber,
    required int chapter,
    required int verse,
  }) async {
    final keyCheck = _checkApiKey();
    if (keyCheck != null) return keyCheck as BLBResult<List<BLBWord>>;

    final rateCheck = _checkRateLimit<List<BLBWord>>();
    if (rateCheck != null) return rateCheck;

    final blbCode = BlbTranslator.bookNumberToBLBCode[bookNumber];
    if (blbCode == null) {
      return const BLBResult(
        status: BLBResultStatus.noData,
        message: 'Libro no encontrado en el mapa BLB',
      );
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl/search/search?type=verseSearch'
        '&verseRange=$blbCode.$chapter.$verse&version=KJV'
        '&output=json&apiKey=$_apiKey',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));
      _incrementDailyCount();

      if (response.statusCode != 200) {
        return BLBResult(
          status: BLBResultStatus.networkError,
          message: 'HTTP ${response.statusCode}',
        );
      }

      final words = _parseVerseSearchResponse(response.body);
      return BLBResult(status: BLBResultStatus.success, data: words);
    } catch (e) {
      return BLBResult(
        status: BLBResultStatus.networkError,
        message: e.toString(),
      );
    }
  }

  // ─── LEXICON ────────────────────────────────────────────────

  /// Obtiene la entrada del lexicón para un número Strong.
  /// Cachea permanentemente en SharedPreferences.
  Future<BLBResult<BLBLexiconEntry>> getLexiconEntry(
      String strongNumber) async {
    // Intentar caché primero
    final cacheKey = 'blb_lex_$strongNumber';
    final cached = _prefs?.getString(cacheKey);
    if (cached != null) {
      try {
        final entry =
            BLBLexiconEntry.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        return BLBResult(
          status: BLBResultStatus.success,
          data: entry,
          fromCache: true,
        );
      } catch (_) {
        // caché corrupta, continuar con API
      }
    }

    final keyCheck = _checkApiKey();
    if (keyCheck != null) return keyCheck as BLBResult<BLBLexiconEntry>;

    final rateCheck = _checkRateLimit<BLBLexiconEntry>();
    if (rateCheck != null) return rateCheck;

    try {
      // BLB usa /hash/hash?strongs=H430 para consultar el lexicón.
      final uri = Uri.parse(
        '$_baseUrl/hash/hash?strongs=$strongNumber&output=json&apiKey=$_apiKey',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));
      _incrementDailyCount();

      if (response.statusCode != 200) {
        return BLBResult(
          status: BLBResultStatus.networkError,
          message: 'HTTP ${response.statusCode}',
        );
      }

      final entry = _parseLexiconResponse(response.body, strongNumber);
      if (entry == null) {
        return const BLBResult(
          status: BLBResultStatus.noData,
          message: 'No se encontró entrada de lexicón',
        );
      }

      // Guardar en caché permanente
      await _prefs?.setString(cacheKey, jsonEncode(entry.toJson()));

      return BLBResult(status: BLBResultStatus.success, data: entry);
    } catch (e) {
      return BLBResult(
        status: BLBResultStatus.networkError,
        message: e.toString(),
      );
    }
  }

  // ─── CROSS REFERENCES ──────────────────────────────────────

  /// BLB REST API v1 no expone un endpoint de referencias cruzadas.
  /// Las cross-refs se obtienen vía TreasuryService (TSK local, 340k+ refs).
  /// Este método existe solo por compatibilidad de interfaz.
  Future<BLBResult<List<BLBCrossReference>>> getCrossReferences({
    required int bookNumber,
    required int chapter,
    required int verse,
  }) async {
    return const BLBResult(
      status: BLBResultStatus.noData,
      data: [],
      message: 'Usar TreasuryService.instance.getCrossReferences() para cross-refs (TSK, 340k+ refs)',
    );
  }

  /// Prefetch: carga Strong's para el versículo.
  /// Cross-refs se obtienen vía TreasuryService, no vía BLB API.
  Future<BLBResult<List<BLBWord>>> prefetchVerseStrongs({
    required int bookNumber,
    required int chapter,
    required int verse,
  }) async {
    return getVerseWithStrongs(
        bookNumber: bookNumber, chapter: chapter, verse: verse);
  }

  // ─── RATE LIMITING ──────────────────────────────────────────

  void _loadDailyCount() {
    if (_prefs == null) return;
    final today = _todayString();
    final savedDate = _prefs?.getString(_dailyDateKey);
    if (savedDate != today) {
      // Nuevo día: reiniciar contador
      _prefs?.setString(_dailyDateKey, today);
      _prefs?.setInt(_dailyCountKey, 0);
      dailyRequestCount.value = 0;
    } else {
      dailyRequestCount.value = _prefs?.getInt(_dailyCountKey) ?? 0;
    }
  }

  void _incrementDailyCount() {
    final today = _todayString();
    final savedDate = _prefs?.getString(_dailyDateKey);
    if (savedDate != today) {
      _prefs?.setString(_dailyDateKey, today);
      _prefs?.setInt(_dailyCountKey, 1);
      dailyRequestCount.value = 1;
    } else {
      final count = (dailyRequestCount.value) + 1;
      _prefs?.setInt(_dailyCountKey, count);
      dailyRequestCount.value = count;
    }
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  BLBResult<T>? _checkApiKey<T>() {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return const BLBResult(
        status: BLBResultStatus.noApiKey,
        message: 'API key no configurada',
      );
    }
    return null;
  }

  BLBResult<T>? _checkRateLimit<T>() {
    if (dailyRequestCount.value >= _dailyLimit) {
      return BLBResult(
        status: BLBResultStatus.rateLimited,
        message: 'Límite diario alcanzado (${dailyRequestCount.value}/$_dailyLimit)',
      );
    }
    return null;
  }

  // ─── RESPONSE PARSERS ──────────────────────────────────────

  /// Parsea la respuesta de verseSearch con Strong's numbers.
  List<BLBWord> _parseVerseSearchResponse(String body) {
    final words = <BLBWord>[];
    try {
      final json = jsonDecode(body);
      // La estructura de BLB verseSearch varía, manejar formatos conocidos
      final results = _extractResults(json);
      if (results == null) return words;

      for (final item in results) {
        if (item is Map<String, dynamic>) {
          final wordList = item['words'] ?? item['word'];
          if (wordList is List) {
            for (final w in wordList) {
              if (w is Map<String, dynamic>) {
                words.add(BLBWord(
                  text: (w['text'] ?? w['word'] ?? '').toString(),
                  strongNumber: (w['strongs'] ?? w['strongNumber'] ?? w['sn'])
                      ?.toString(),
                  originalWord: w['originalWord']?.toString(),
                  transliteration: w['transliteration']?.toString(),
                  partOfSpeech: w['partOfSpeech']?.toString(),
                  shortDefinition: w['definition']?.toString(),
                ));
              }
            }
          } else {
            // Formato simple: el item es la palabra
            words.add(BLBWord(
              text: (item['text'] ?? item['word'] ?? '').toString(),
              strongNumber:
                  (item['strongs'] ?? item['strongNumber'] ?? item['sn'])
                      ?.toString(),
              originalWord: item['originalWord']?.toString(),
              transliteration: item['transliteration']?.toString(),
              partOfSpeech: item['partOfSpeech']?.toString(),
              shortDefinition: item['definition']?.toString(),
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('BLB parse error (verseSearch): $e');
    }
    return words;
  }

  /// Intenta extraer la lista de resultados del JSON de BLB.
  List<dynamic>? _extractResults(dynamic json) {
    if (json is List) return json;
    if (json is Map<String, dynamic>) {
      // Probar paths comunes de BLB API
      final candidates = [
        json['searchResults'],
        json['results'],
        json['data'],
        json['verses'],
        json['response']?['searchResults'],
      ];
      for (final c in candidates) {
        if (c is List) return c;
        if (c is Map && c['resultList'] is List) {
          return c['resultList'] as List;
        }
      }
    }
    return null;
  }

  /// Parsea una respuesta del lexicón.
  BLBLexiconEntry? _parseLexiconResponse(String body, String strongNumber) {
    try {
      final json = jsonDecode(body);
      Map<String, dynamic>? data;

      if (json is Map<String, dynamic>) {
        data = json['data'] as Map<String, dynamic>? ??
            json['lexicon'] as Map<String, dynamic>? ??
            json;
      }
      if (data == null) return null;

      return BLBLexiconEntry(
        strongNumber: strongNumber,
        originalWord: (data['originalWord'] ?? data['unicode'] ?? '').toString(),
        transliteration:
            (data['transliteration'] ?? data['translit'] ?? '').toString(),
        pronunciation: (data['pronunciation'] ?? '').toString(),
        partOfSpeech: (data['partOfSpeech'] ?? data['pos'] ?? '').toString(),
        language: strongNumber.startsWith('H') ? 'hebrew' : 'greek',
        shortDefinition:
            (data['shortDefinition'] ?? data['kjvDef'] ?? data['definition'] ?? '')
                .toString(),
        fullDefinition: (data['fullDefinition'] ?? data['outline'] ?? '')
            .toString(),
        occurrences: (data['occurrences'] ?? data['count'] ?? 0) is int
            ? (data['occurrences'] ?? data['count'] ?? 0) as int
            : int.tryParse(
                    (data['occurrences'] ?? data['count'] ?? '0').toString()) ??
                0,
        kjvTranslations: data['kjvTranslations'] is List
            ? (data['kjvTranslations'] as List).cast<String>()
            : <String>[],
      );
    } catch (e) {
      debugPrint('BLB parse error (lexicon): $e');
      return null;
    }
  }
}
