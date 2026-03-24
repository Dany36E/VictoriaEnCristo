import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/bible/bible_verse.dart';
import '../audio_engine.dart';

/// Modo de lectura TTS
enum TtsReadMode { verseOnly, annotationOnly, both }

/// Elemento de la cola de lectura TTS
class TtsQueueItem {
  final String text;
  final int verseIndex; // -1 para items que no son versículos
  const TtsQueueItem(this.text, this.verseIndex);
}

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE TTS SERVICE — Lee un capítulo verso por verso con tracking.
///
/// Emite el índice del versículo que se está leyendo para highlighting.
/// Usa su propio FlutterTts para no interferir con el AudioService general.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleTtsService {
  static final BibleTtsService _instance = BibleTtsService._internal();
  factory BibleTtsService() => _instance;
  static BibleTtsService get I => _instance;
  BibleTtsService._internal();

  FlutterTts? _tts;
  bool _initialized = false;

  List<TtsQueueItem> _queue = [];
  int _queueIndex = -1;
  bool _playing = false;
  bool _paused = false;

  /// Generación de lectura: se incrementa en cada stop/start para cancelar
  /// cualquier _readCurrent() en vuelo que pertenezca a una sesión anterior.
  int _generation = 0;
  int _speakingGen = 0;

  /// Índice del versículo que se está leyendo (-1 si no hay nada)
  final ValueNotifier<int> currentVerseIndex = ValueNotifier(-1);

  /// Si está leyendo
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);

  /// Modo de lectura actual
  final ValueNotifier<TtsReadMode> readMode = ValueNotifier(TtsReadMode.verseOnly);

  Future<void> _init() async {
    if (_initialized) return;
    _tts = FlutterTts();
    try {
      await _tts!.setLanguage('es-MX');
    } catch (_) {
      try {
        await _tts!.setLanguage('es-US');
      } catch (_) {
        await _tts!.setLanguage('es-ES');
      }
    }
    await _tts!.setSpeechRate(0.45);
    await _tts!.setPitch(1.0);
    await _tts!.setVolume(1.0);

    _tts!.setCompletionHandler(() {
      _onItemComplete(_speakingGen);
    });
    _tts!.setCancelHandler(() {
      // No limpiar estado aquí — stop() ya lo maneja vía _generation
    });
    _tts!.setErrorHandler((msg) {
      // No detener: saltar al siguiente item
      if (_playing) {
        _onItemComplete(_speakingGen);
      }
    });

    _initialized = true;
  }

  /// Iniciar lectura desde un índice específico (modo solo versículos)
  Future<void> startReading(List<BibleVerse> verses, {int fromIndex = 0}) async {
    final queue = <TtsQueueItem>[];
    for (int i = fromIndex; i < verses.length; i++) {
      queue.add(TtsQueueItem(verses[i].text.trim(), i));
    }
    await startReadingQueue(queue, mode: TtsReadMode.verseOnly);
  }

  /// Iniciar lectura con cola personalizada y modo
  Future<void> startReadingQueue(List<TtsQueueItem> queue, {TtsReadMode mode = TtsReadMode.verseOnly}) async {
    // Detener BGM al activar TTS
    final engine = AudioEngine.I;
    if (engine.bgmState.value == BgmPlaybackState.playing) {
      await engine.pauseBgm();
    }

    await _init();
    await stop();
    _queue = queue;
    _queueIndex = 0;
    readMode.value = mode;
    _playing = true;
    _paused = false;
    isPlaying.value = true;
    final gen = ++_generation;
    await _readCurrent(gen);
  }

  Future<void> _readCurrent(int gen) async {
    if (gen != _generation) return; // sesión cancelada
    if (!_playing || _queueIndex >= _queue.length || _queueIndex < 0) {
      await stop();
      return;
    }
    final item = _queue[_queueIndex];
    currentVerseIndex.value = item.verseIndex;

    // Saltar items con texto vacío
    if (item.text.trim().isEmpty) {
      _onItemComplete(gen);
      return;
    }

    _speakingGen = gen;
    final result = await _tts?.speak(item.text);
    if (gen != _generation) return; // cancelado mientras speak ejecutaba
    if (result != 1) {
      // speak falló (texto muy largo, error engine, etc.) → avanzar
      _onItemComplete(gen);
    }
  }

  void _onItemComplete([int? gen]) {
    gen ??= _generation;
    if (gen != _generation) return; // sesión obsoleta
    if (!_playing) return;
    _queueIndex++;
    if (_queueIndex >= _queue.length) {
      stop();
      return;
    }
    _readCurrent(gen); // fire-and-forget OK: protegido por generation
  }

  /// Pausar lectura
  Future<void> pause() async {
    if (!_playing) return;
    _paused = true;
    _playing = false;
    isPlaying.value = false;
    await _tts?.pause();
  }

  /// Reanudar lectura
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    _playing = true;
    isPlaying.value = true;
    // flutter_tts pause/resume no es confiable en todos los dispositivos,
    // releyendo el item actual
    final gen = ++_generation;
    _readCurrent(gen);
  }

  /// Detener lectura
  Future<void> stop() async {
    final wasStopping = !_playing && !_paused && _queue.isEmpty;
    _generation++; // invalida cualquier _readCurrent en vuelo
    _playing = false;
    _paused = false;
    _queueIndex = -1;
    _queue = [];
    isPlaying.value = false;
    currentVerseIndex.value = -1;
    readMode.value = TtsReadMode.verseOnly;
    if (!wasStopping) await _tts?.stop();
  }

  /// Toggle play/pause
  Future<void> toggle(List<BibleVerse> verses, {int fromIndex = 0}) async {
    if (_playing) {
      await pause();
    } else if (_paused) {
      await resume();
    } else {
      await startReading(verses, fromIndex: fromIndex);
    }
  }

  Future<void> dispose() async {
    await stop();
  }
}
