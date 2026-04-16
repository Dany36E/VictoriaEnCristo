import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../connectivity_service.dart';

/// Estado del audio bíblico real.
enum AudioBibleState { idle, buffering, playing, paused }

/// Timestamp de un versículo dentro del audio del capítulo.
class VerseTimestamp {
  final int verse;
  final int startMs;
  const VerseTimestamp({required this.verse, required this.startMs});
}

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE AUDIO SERVICE — Audio bíblico real (voz humana) via Bible Brain API.
///
/// Fuente: Faith Comes By Hearing (https://4.dbt.io/api)
/// Soporta: RVR1960 (AT+NT dramatizado en español)
/// Fallback: retorna false para que el caller use TTS.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleAudioService {
  static final BibleAudioService I = BibleAudioService._();
  BibleAudioService._();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  // ─── Stream subscriptions ───
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferedSub;
  StreamSubscription? _playerStateSub;

  // ─── Estado público (reactivo) ───
  final ValueNotifier<AudioBibleState> state =
      ValueNotifier(AudioBibleState.idle);
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<double> bufferedProgress = ValueNotifier(0.0);
  final ValueNotifier<int?> currentVerse = ValueNotifier(null);

  // ─── Timestamps de versículos ───
  List<VerseTimestamp> _verseTimestamps = [];

  static const String _baseUrl = 'https://4.dbt.io/api';

  // ─── Filesets verificados para español ───
  // Cada versión tiene un fileset NT y uno AT.
  // Se prueban en orden de preferencia hasta encontrar uno que funcione.
  static const _kFilesets = <Map<String, String>>[
    // RVR1960 dramatizada (Faith Comes By Hearing)
    {'label': 'RVR1960', 'nt': 'SPNRVRN2DA', 'ot': 'SPNRVRN1DA'},
    // RVR1960 no dramatizada
    {'label': 'RVR1960-ND', 'nt': 'SPNRVRN2SA', 'ot': 'SPNRVRN1SA'},
    // NVI dramatizada
    {'label': 'NVI', 'nt': 'SPNNVIN2DA', 'ot': 'SPNNVIN1DA'},
    // TLA dramatizada
    {'label': 'TLA', 'nt': 'SPNTLAN2DA', 'ot': 'SPNTLAN1DA'},
  ];

  // Fileset que se confirmó funcional durante esta sesión (cache)
  String? _workingNtFileset;
  String? _workingOtFileset;
  // Set de filesets que fallaron (no reintentar)
  final Set<String> _failedFilesets = {};

  // ─── Cache de URLs en memoria (expiran por sesión) ───
  final Map<String, String> _urlCache = {};

  Future<void> init() async {
    if (_initialized) return;

    // Cancelar subscripciones anteriores (guard contra doble-init)
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _bufferedSub?.cancel();
    await _playerStateSub?.cancel();

    _positionSub = _player.positionStream.listen((pos) {
      position.value = pos;
      _updateActiveVerse(pos);
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) duration.value = dur;
    });

    _bufferedSub = _player.bufferedPositionStream.listen((buffered) {
      if (duration.value.inMilliseconds > 0) {
        bufferedProgress.value =
            buffered.inMilliseconds / duration.value.inMilliseconds;
      }
    });

    _playerStateSub = _player.playerStateStream.listen((s) {
      switch (s.processingState) {
        case ProcessingState.idle:
        case ProcessingState.completed:
          state.value = AudioBibleState.idle;
          currentVerse.value = null;
          break;
        case ProcessingState.loading:
        case ProcessingState.buffering:
          state.value = AudioBibleState.buffering;
          break;
        case ProcessingState.ready:
          state.value =
              s.playing ? AudioBibleState.playing : AudioBibleState.paused;
          break;
      }
    });

    _initialized = true;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // OBTENER URL DE AUDIO PARA UN CAPÍTULO
  // ═══════════════════════════════════════════════════════════════════════

  Future<String?> getChapterAudioUrl({
    required String filesetId,
    required String bookCode,
    required int chapter,
  }) async {
    const apiKey = ApiConfig.bibleBrainKey;
    if (apiKey.isEmpty) return null;

    final cacheKey = '${filesetId}_${bookCode}_$chapter';
    if (_urlCache.containsKey(cacheKey)) return _urlCache[cacheKey];

    if (!ConnectivityService.I.hasInternet) return null;

    try {
      final uri = Uri.parse(
          '$_baseUrl/bibles/filesets/$filesetId/$bookCode/$chapter'
          '?key=$apiKey&v=4');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['data'] as List?;
        if (items == null || items.isEmpty) return null;

        final url = items[0]['path'] as String?;
        if (url != null) _urlCache[cacheKey] = url;
        return url;
      }
    } catch (e) {
      debugPrint('[BibleAudio] Error getting URL: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // OBTENER TIMESTAMPS DE VERSÍCULOS
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<VerseTimestamp>> getVerseTimestamps({
    required String filesetId,
    required String bookCode,
    required int chapter,
  }) async {
    const apiKey = ApiConfig.bibleBrainKey;
    if (apiKey.isEmpty) return [];
    if (!ConnectivityService.I.hasInternet) return [];

    try {
      final uri = Uri.parse(
          '$_baseUrl/timestamps/$filesetId/$bookCode/$chapter'
          '?key=$apiKey&v=4');

      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['data'] as List? ?? [];
        return items
            .map((item) => VerseTimestamp(
                  verse: item['verse_start'] as int,
                  startMs: ((item['timestamp'] as num) * 1000).toInt(),
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('[BibleAudio] Error getting timestamps: $e');
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REPRODUCIR CAPÍTULO
  // ═══════════════════════════════════════════════════════════════════════

  /// Intenta reproducir el capítulo con audio real.
  /// Retorna `true` si tuvo éxito, `false` si debe usarse TTS como fallback.
  Future<bool> playChapter({
    required int bookNumber,
    required int chapter,
    int startVerse = 1,
    double speed = 1.0,
  }) async {
    await init();

    if (ApiConfig.bibleBrainKey.isEmpty) {
      debugPrint('[BibleAudio] No API key configured');
      return false;
    }
    if (!ConnectivityService.I.hasInternet) {
      debugPrint('[BibleAudio] No internet');
      return false;
    }

    final bookCode = _kBookNumberToCode[bookNumber];
    if (bookCode == null) {
      debugPrint('[BibleAudio] Unknown book number: $bookNumber');
      return false;
    }

    // Buscar un fileset funcional (prueba múltiples con fallback)
    final result = await _findWorkingFileset(
      bookNumber: bookNumber,
      bookCode: bookCode,
      chapter: chapter,
    );

    if (result == null) {
      debugPrint('[BibleAudio] No fileset funcional para $bookCode/$chapter');
      return false;
    }

    final (filesetId, url) = result;

    // Obtener timestamps ANTES de play (evita race condition)
    _verseTimestamps = await getVerseTimestamps(
      filesetId: filesetId,
      bookCode: bookCode,
      chapter: chapter,
    );

    try {
      state.value = AudioBibleState.buffering;
      await _player.setUrl(url);
      await _player.setSpeed(speed.clamp(0.5, 2.0));

      // Si startVerse > 1, saltar al timestamp correspondiente
      if (startVerse > 1 && _verseTimestamps.isNotEmpty) {
        final timestamp =
            _verseTimestamps.where((t) => t.verse == startVerse).firstOrNull;
        if (timestamp != null) {
          await _player.seek(Duration(milliseconds: timestamp.startMs));
        }
      }

      await _player.play();
      return true;
    } catch (e) {
      debugPrint('[BibleAudio] Playback error: $e');
      state.value = AudioBibleState.idle;
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CONTROLES
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> pause() async => await _player.pause();
  Future<void> resume() async => await _player.play();

  Future<void> stop() async {
    await _player.stop();
    _verseTimestamps.clear();
    currentVerse.value = null;
    position.value = Duration.zero;
    duration.value = Duration.zero;
    bufferedProgress.value = 0.0;
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed.clamp(0.5, 2.0));
  }

  Future<void> seekToVerse(int verseNumber) async {
    final timestamp =
        _verseTimestamps.where((t) => t.verse == verseNumber).firstOrNull;
    if (timestamp != null) {
      await _player.seek(Duration(milliseconds: timestamp.startMs));
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PRIVADOS
  // ═══════════════════════════════════════════════════════════════════════

  void _updateActiveVerse(Duration pos) {
    if (_verseTimestamps.isEmpty) return;

    final posMs = pos.inMilliseconds;
    VerseTimestamp? active;

    for (final ts in _verseTimestamps) {
      if (ts.startMs <= posMs) {
        active = ts;
      } else {
        break;
      }
    }

    if (active != null && currentVerse.value != active.verse) {
      currentVerse.value = active.verse;
    }
  }

  /// Obtiene un fileset funcional para el libro dado, probando en orden.
  /// Retorna el fileset ID y la URL del audio, o null si ninguno funciona.
  Future<(String filesetId, String url)?> _findWorkingFileset({
    required int bookNumber,
    required String bookCode,
    required int chapter,
  }) async {
    final isNT = bookNumber >= 40;
    final key = isNT ? 'nt' : 'ot';

    // Si ya tenemos un fileset funcional, probar ese primero
    final cached = isNT ? _workingNtFileset : _workingOtFileset;
    if (cached != null && !_failedFilesets.contains(cached)) {
      final url = await getChapterAudioUrl(
        filesetId: cached,
        bookCode: bookCode,
        chapter: chapter,
      );
      if (url != null) return (cached, url);
    }

    // Probar todos los filesets en orden
    for (final fs in _kFilesets) {
      final filesetId = fs[key]!;
      if (_failedFilesets.contains(filesetId)) continue;
      if (filesetId == cached) continue; // ya probado

      debugPrint('[BibleAudio] Probando fileset ${fs['label']} ($filesetId)...');
      final url = await getChapterAudioUrl(
        filesetId: filesetId,
        bookCode: bookCode,
        chapter: chapter,
      );
      if (url != null) {
        debugPrint('[BibleAudio] ✓ Fileset ${fs['label']} funciona');
        // Guardar como funcional
        if (isNT) {
          _workingNtFileset = filesetId;
        } else {
          _workingOtFileset = filesetId;
        }
        return (filesetId, url);
      } else {
        debugPrint('[BibleAudio] ✗ Fileset ${fs['label']} sin audio');
        _failedFilesets.add(filesetId);
      }
    }
    return null;
  }

  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferedSub?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MAPEO bookNumber → código OSIS (para Bible Brain API)
// ═══════════════════════════════════════════════════════════════════════════

const _kBookNumberToCode = <int, String>{
  1: 'GEN', 2: 'EXO', 3: 'LEV', 4: 'NUM', 5: 'DEU',
  6: 'JOS', 7: 'JDG', 8: 'RUT', 9: '1SA', 10: '2SA',
  11: '1KI', 12: '2KI', 13: '1CH', 14: '2CH', 15: 'EZR',
  16: 'NEH', 17: 'EST', 18: 'JOB', 19: 'PSA', 20: 'PRO',
  21: 'ECC', 22: 'SNG', 23: 'ISA', 24: 'JER', 25: 'LAM',
  26: 'EZK', 27: 'DAN', 28: 'HOS', 29: 'JOL', 30: 'AMO',
  31: 'OBA', 32: 'JON', 33: 'MIC', 34: 'NAM', 35: 'HAB',
  36: 'ZEP', 37: 'HAG', 38: 'ZEC', 39: 'MAL',
  40: 'MAT', 41: 'MRK', 42: 'LUK', 43: 'JHN', 44: 'ACT',
  45: 'ROM', 46: '1CO', 47: '2CO', 48: 'GAL', 49: 'EPH',
  50: 'PHP', 51: 'COL', 52: '1TH', 53: '2TH', 54: '1TI',
  55: '2TI', 56: 'TIT', 57: 'PHM', 58: 'HEB', 59: 'JAS',
  60: '1PE', 61: '2PE', 62: '1JN', 63: '2JN', 64: '3JN',
  65: 'JUD', 66: 'REV',
};
