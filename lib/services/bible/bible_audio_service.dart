import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../utils/platform_capabilities.dart';
import '../../models/bible/bible_version.dart';
import '../connectivity_service.dart';
import 'bible_audio_settings.dart';

/// Estado del audio bíblico real.
enum AudioBibleState { idle, buffering, playing, paused }

/// Timestamp de un versículo dentro del audio del capítulo.
class VerseTimestamp {
  final int verse;
  final int startMs;
  const VerseTimestamp({required this.verse, required this.startMs});
}

/// Filesets de audio (Bible Brain / DBP v4) de una versión, en orden de
/// preferencia: primero dramatizado (…2DA), luego solo narración (…1DA).
///
/// Formato de ID DBP: 3 letras idioma + 3 versión + colección (`O` = AT,
/// `N` = NT) + tipo (`2` = dramatizado, `1` = no dramatizado) + `DA` (audio).
class BibleAudioFilesets {
  final List<String> ot;
  final List<String> nt;
  const BibleAudioFilesets({this.ot = const [], this.nt = const []});

  List<String> forBook(int bookNumber) => bookNumber >= 40 ? nt : ot;
}

/// ÚNICO lugar donde se mapea versión → filesets de audio narrado.
///
/// ⚠️ TODOS los IDs son TENTATIVOS: hay que verificarlos con la API
/// (`GET /bibles?language_code=spa&v=4`, ver docs/BIBLE_BRAIN_SETUP.md) y
/// confirmar la licencia de cada grabación antes de publicar. Una versión que
/// no está aquí (o con listas vacías) usa siempre la voz sintética: nunca se
/// reproduce el audio de otra versión distinta a la que se está leyendo.
const Map<String, BibleAudioFilesets> kBibleAudioFilesets = {
  // Reina-Valera 1960 (© Sociedades Bíblicas Unidas)
  'RVR1960': BibleAudioFilesets(
    ot: ['SPNRVRO2DA', 'SPNRVRO1DA'],
    nt: ['SPNRVRN2DA', 'SPNRVRN1DA'],
  ),
  // Nueva Versión Internacional (© Biblica)
  'NVI': BibleAudioFilesets(
    ot: ['SPNNVIO2DA', 'SPNNVIO1DA'],
    nt: ['SPNNVIN2DA', 'SPNNVIN1DA'],
  ),
  // La Biblia de las Américas (© The Lockman Foundation)
  'LBLA': BibleAudioFilesets(
    ot: ['SPNBDAO2DA', 'SPNBDAO1DA'],
    nt: ['SPNBDAN2DA', 'SPNBDAN1DA'],
  ),
  // Traducción en Lenguaje Actual (© Sociedades Bíblicas Unidas)
  'TLA': BibleAudioFilesets(
    ot: ['SPNTLAO2DA', 'SPNTLAO1DA'],
    nt: ['SPNTLAN2DA', 'SPNTLAN1DA'],
  ),
  // NTV, NLT y NKJV: sin audio narrado conocido en Bible Brain → TTS.
  // New International Version (© Biblica)
  'NIV_EN': BibleAudioFilesets(
    ot: ['ENGNIVO2DA', 'ENGNIVO1DA'],
    nt: ['ENGNIVN2DA', 'ENGNIVN1DA'],
  ),
};

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE AUDIO SERVICE — Audio bíblico real (voz humana) via Bible Brain API.
///
/// Fuente: Faith Comes By Hearing (https://4.dbt.io/api)
/// Solo prueba los filesets de la versión activa ([kBibleAudioFilesets]).
/// Fallback: retorna false para que el caller use TTS (sin clave, sin
/// internet, plataforma sin reproductor o versión sin audio).
/// ═══════════════════════════════════════════════════════════════════════════
class BibleAudioService {
  static final BibleAudioService I = BibleAudioService._();
  BibleAudioService._();

  late final AudioPlayer? _player = PlatformCapabilities.supportsAudioPlayback
      ? AudioPlayer()
      : null;
  bool _initialized = false;

  /// El reproductor solo se crea al reproducir por primera vez: stop() y
  /// compañía no deben crearlo (en tests/escritorio colgaría o fallaría).
  bool _playerCreated = false;
  AudioPlayer? get _activePlayer => _playerCreated ? _player : null;

  // ─── Stream subscriptions ───
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferedSub;
  StreamSubscription? _playerStateSub;

  // ─── Estado público (reactivo) ───
  final ValueNotifier<AudioBibleState> state = ValueNotifier(AudioBibleState.idle);
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<double> bufferedProgress = ValueNotifier(0.0);

  /// Número de versículo (no índice) que suena, según los timestamps.
  final ValueNotifier<int?> currentVerse = ValueNotifier(null);

  /// `true` cuando el último paso a [AudioBibleState.idle] fue porque el
  /// capítulo terminó solo (no por stop/error). Se fija ANTES de cambiar
  /// [state], así los listeners de `state` pueden consultarlo.
  bool completedNaturally = false;

  // ─── Timestamps de versículos ───
  List<VerseTimestamp> _verseTimestamps = [];

  static const String _baseUrl = 'https://4.dbt.io/api';

  // Fileset que se confirmó funcional durante esta sesión, por
  // «versión|testamento» (cache)
  final Map<String, String> _workingFilesets = {};
  // Set de filesets que fallaron (no reintentar)
  final Set<String> _failedFilesets = {};

  // ─── Cache de URLs en memoria (expiran por sesión) ───
  final Map<String, String> _urlCache = {};

  /// Filesets a probar para [version] y [bookNumber] (vacío = solo TTS).
  static List<String> filesetsFor(BibleVersion version, int bookNumber) =>
      kBibleAudioFilesets[version.id]?.forBook(bookNumber) ?? const [];

  /// Si hay audio narrado configurado (clave + filesets) para [version].
  static bool isConfiguredFor(BibleVersion version) =>
      ApiConfig.bibleBrainKey.isNotEmpty &&
      kBibleAudioFilesets.containsKey(version.id);

  Future<void> init() async {
    if (_initialized) return;

    // Desktop guard: just_audio not available on Windows/Linux. Skip stream
    // wiring entirely — callers will get false from playChapter().
    if (!PlatformCapabilities.supportsAudioPlayback) {
      _initialized = true;
      return;
    }
    final player = _player;
    if (player == null) {
      _initialized = true;
      return;
    }
    _playerCreated = true;

    // Cancelar subscripciones anteriores (guard contra doble-init)
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _bufferedSub?.cancel();
    await _playerStateSub?.cancel();

    _positionSub = player.positionStream.listen((pos) {
      position.value = pos;
      _updateActiveVerse(pos);
    });

    _durationSub = player.durationStream.listen((dur) {
      if (dur != null) duration.value = dur;
    });

    _bufferedSub = player.bufferedPositionStream.listen((buffered) {
      if (duration.value.inMilliseconds > 0) {
        bufferedProgress.value = buffered.inMilliseconds / duration.value.inMilliseconds;
      }
    });

    _playerStateSub = player.playerStateStream.listen((s) {
      switch (s.processingState) {
        case ProcessingState.idle:
        case ProcessingState.completed:
          completedNaturally =
              s.processingState == ProcessingState.completed;
          currentVerse.value = null;
          state.value = AudioBibleState.idle;
          break;
        case ProcessingState.loading:
        case ProcessingState.buffering:
          completedNaturally = false;
          state.value = AudioBibleState.buffering;
          break;
        case ProcessingState.ready:
          completedNaturally = false;
          state.value = s.playing ? AudioBibleState.playing : AudioBibleState.paused;
          break;
      }
    });

    // Velocidad en vivo desde los ajustes.
    BibleAudioSettings.I.speed.addListener(_onSpeedSetting);

    _initialized = true;
  }

  void _onSpeedSetting() {
    if (state.value != AudioBibleState.idle) {
      unawaited(setSpeed(BibleAudioSettings.I.speed.value));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // OBTENER URL DE AUDIO PARA UN CAPÍTULO
  // ═══════════════════════════════════════════════════════════════════════

  Future<String?> getChapterAudioUrl({
    required String filesetId,
    required String bookCode,
    required int chapter,
  }) async {
    final (url, _) = await _fetchChapterAudioUrl(
      filesetId: filesetId,
      bookCode: bookCode,
      chapter: chapter,
    );
    return url;
  }

  /// Devuelve la URL y si la respuesta fue definitiva (la API contestó: el
  /// fileset no tiene ese capítulo / no existe / no está autorizado). Un
  /// error de red o timeout NO es definitivo y no se cachea como fallo.
  Future<(String?, bool definitive)> _fetchChapterAudioUrl({
    required String filesetId,
    required String bookCode,
    required int chapter,
  }) async {
    const apiKey = ApiConfig.bibleBrainKey;
    if (apiKey.isEmpty) return (null, false);

    final cacheKey = '${filesetId}_${bookCode}_$chapter';
    final cached = _urlCache[cacheKey];
    if (cached != null) return (cached, true);

    if (!ConnectivityService.I.hasInternet) return (null, false);

    try {
      final uri = Uri.parse(
        '$_baseUrl/bibles/filesets/$filesetId/$bookCode/$chapter'
        '?key=$apiKey&v=4',
      );

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['data'] as List?;
        if (items == null || items.isEmpty) return (null, true);

        final url = items[0]['path'] as String?;
        if (url != null) _urlCache[cacheKey] = url;
        return (url, true);
      }
      // 4xx: fileset inexistente o sin permiso → definitivo. 5xx → reintentar.
      return (null, response.statusCode < 500);
    } catch (e) {
      debugPrint('[BibleAudio] Error getting URL: $e');
    }
    return (null, false);
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
        '?key=$apiKey&v=4',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['data'] as List? ?? [];
        return items
            .map(
              (item) => VerseTimestamp(
                verse: item['verse_start'] as int,
                startMs: ((item['timestamp'] as num) * 1000).toInt(),
              ),
            )
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

  /// Intenta reproducir el capítulo con audio real de [version] (solo se
  /// prueban los filesets de esa versión, ver [kBibleAudioFilesets]).
  /// Retorna `true` si tuvo éxito, `false` si debe usarse TTS como fallback.
  /// Si [speed] es null se usa la velocidad guardada en los ajustes.
  Future<bool> playChapter({
    required BibleVersion version,
    required int bookNumber,
    required int chapter,
    int startVerse = 1,
    double? speed,
  }) async {
    if (ApiConfig.bibleBrainKey.isEmpty) {
      debugPrint('[BibleAudio] No API key configured');
      return false;
    }
    final candidates = filesetsFor(version, bookNumber);
    if (candidates.isEmpty) {
      debugPrint('[BibleAudio] ${version.id} sin audio narrado configurado');
      return false;
    }

    await init();

    // Desktop guard: just_audio not available on Windows/Linux.
    if (!PlatformCapabilities.supportsAudioPlayback) {
      debugPrint('[BibleAudio] Audio playback unavailable on this platform');
      return false;
    }
    final player = _player;
    if (player == null) {
      debugPrint('[BibleAudio] Audio player unavailable on this platform');
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

    // Buscar un fileset funcional de esta versión (prueba con fallback)
    final result = await _findWorkingFileset(
      version: version,
      bookNumber: bookNumber,
      bookCode: bookCode,
      chapter: chapter,
      candidates: candidates,
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
      completedNaturally = false;
      state.value = AudioBibleState.buffering;
      await player.setUrl(url);
      final s = speed ?? BibleAudioSettings.I.speed.value;
      await player.setSpeed(s.clamp(0.5, 2.0));

      // Si startVerse > 1, saltar al timestamp correspondiente
      if (startVerse > 1 && _verseTimestamps.isNotEmpty) {
        final timestamp = _verseTimestamps.where((t) => t.verse == startVerse).firstOrNull;
        if (timestamp != null) {
          await player.seek(Duration(milliseconds: timestamp.startMs));
        }
      }

      // play() de just_audio completa al pausar/terminar: no esperarlo.
      unawaited(player.play().catchError((Object e) {
        debugPrint('[BibleAudio] Playback error: $e');
      }));
      return true;
    } catch (e) {
      debugPrint('[BibleAudio] Playback error: $e');
      completedNaturally = false;
      state.value = AudioBibleState.idle;
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CONTROLES
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> pause() async => await _activePlayer?.pause();

  /// play() de just_audio completa recién al pausar/terminar: no esperarlo.
  Future<void> resume() async {
    final player = _activePlayer;
    if (player == null) return;
    unawaited(player.play().catchError((Object e) {
      debugPrint('[BibleAudio] Playback error: $e');
    }));
  }

  Future<void> stop() async {
    completedNaturally = false;
    await _activePlayer?.stop();
    _verseTimestamps.clear();
    currentVerse.value = null;
    position.value = Duration.zero;
    duration.value = Duration.zero;
    bufferedProgress.value = 0.0;
  }

  Future<void> togglePlayPause() async {
    if (_activePlayer?.playing ?? false) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> setSpeed(double speed) async {
    await _activePlayer?.setSpeed(speed.clamp(0.5, 2.0));
  }

  Future<void> seekToVerse(int verseNumber) async {
    final timestamp = _verseTimestamps.where((t) => t.verse == verseNumber).firstOrNull;
    if (timestamp != null) {
      await _activePlayer?.seek(Duration(milliseconds: timestamp.startMs));
    }
  }

  Future<void> seek(Duration position) async {
    await _activePlayer?.seek(position);
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

  /// Obtiene un fileset funcional de [version] para el libro dado, probando
  /// [candidates] en orden. Retorna el fileset ID y la URL del audio, o null.
  Future<(String filesetId, String url)?> _findWorkingFileset({
    required BibleVersion version,
    required int bookNumber,
    required String bookCode,
    required int chapter,
    required List<String> candidates,
  }) async {
    final cacheKey = '${version.id}|${bookNumber >= 40 ? 'nt' : 'ot'}';

    // Si ya tenemos un fileset funcional, probar ese primero
    final cached = _workingFilesets[cacheKey];
    if (cached != null && !_failedFilesets.contains(cached)) {
      final url = await getChapterAudioUrl(filesetId: cached, bookCode: bookCode, chapter: chapter);
      if (url != null) return (cached, url);
    }

    // Probar los filesets de la versión en orden
    for (final filesetId in candidates) {
      if (_failedFilesets.contains(filesetId)) continue;
      if (filesetId == cached) continue; // ya probado

      debugPrint('[BibleAudio] Probando fileset $filesetId...');
      final (url, definitive) = await _fetchChapterAudioUrl(
        filesetId: filesetId,
        bookCode: bookCode,
        chapter: chapter,
      );
      if (url != null) {
        debugPrint('[BibleAudio] ✓ Fileset $filesetId funciona');
        _workingFilesets[cacheKey] = filesetId;
        return (filesetId, url);
      } else if (definitive) {
        debugPrint('[BibleAudio] ✗ Fileset $filesetId sin audio');
        _failedFilesets.add(filesetId);
      }
    }
    return null;
  }

  void dispose() {
    BibleAudioSettings.I.speed.removeListener(_onSpeedSetting);
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferedSub?.cancel();
    _playerStateSub?.cancel();
    _activePlayer?.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MAPEO bookNumber → código OSIS (para Bible Brain API)
// ═══════════════════════════════════════════════════════════════════════════

const _kBookNumberToCode = <int, String>{
  1: 'GEN',
  2: 'EXO',
  3: 'LEV',
  4: 'NUM',
  5: 'DEU',
  6: 'JOS',
  7: 'JDG',
  8: 'RUT',
  9: '1SA',
  10: '2SA',
  11: '1KI',
  12: '2KI',
  13: '1CH',
  14: '2CH',
  15: 'EZR',
  16: 'NEH',
  17: 'EST',
  18: 'JOB',
  19: 'PSA',
  20: 'PRO',
  21: 'ECC',
  22: 'SNG',
  23: 'ISA',
  24: 'JER',
  25: 'LAM',
  26: 'EZK',
  27: 'DAN',
  28: 'HOS',
  29: 'JOL',
  30: 'AMO',
  31: 'OBA',
  32: 'JON',
  33: 'MIC',
  34: 'NAM',
  35: 'HAB',
  36: 'ZEP',
  37: 'HAG',
  38: 'ZEC',
  39: 'MAL',
  40: 'MAT',
  41: 'MRK',
  42: 'LUK',
  43: 'JHN',
  44: 'ACT',
  45: 'ROM',
  46: '1CO',
  47: '2CO',
  48: 'GAL',
  49: 'EPH',
  50: 'PHP',
  51: 'COL',
  52: '1TH',
  53: '2TH',
  54: '1TI',
  55: '2TI',
  56: 'TIT',
  57: 'PHM',
  58: 'HEB',
  59: 'JAS',
  60: '1PE',
  61: '2PE',
  62: '1JN',
  63: '2JN',
  64: '3JN',
  65: 'JUD',
  66: 'REV',
};
