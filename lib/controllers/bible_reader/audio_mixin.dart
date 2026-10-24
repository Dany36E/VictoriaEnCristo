import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/bible/bible_audio_service.dart';
import '../../services/bible/bible_audio_settings.dart';
import '../../services/bible/bible_tts_service.dart';
import '../../services/bible/enduring_word_service.dart';
import '../../services/audio_engine.dart';
import 'reader_state.dart';

/// Se llama cuando el audio de un capítulo terminó solo y el avance
/// automático está activo. Debe navegar al siguiente capítulo (o al primer
/// capítulo del siguiente libro) y devolver `true`; `false` si no hay a dónde
/// ir (fin de Apocalipsis), y entonces el audio simplemente se detiene.
typedef AudioChapterFinishedCallback = bool Function();

/// Gestión del audio bíblico (audio real + TTS fallback).
///
/// Máquina de estados:
/// - [toggleTts] inicia (audio narrado de la versión activa → si no hay, TTS)
///   o detiene.
/// - Cuando el capítulo termina solo: se limpia el estado ([ttsActive],
///   [realAudioActive], versículo resaltado) y, si el avance automático está
///   activo (y el temporizador no era «al terminar el capítulo»), se llama a
///   [onAudioChapterFinished]; al cargar el nuevo capítulo el audio sigue.
/// - Si el motor falla, se limpia el estado sin avanzar.
/// - El controlador debe llamar a [audioBeforeChapterChange] al empezar
///   `loadChapter` y a [audioAfterChapterLoaded] cuando ya tiene los
///   versículos.
mixin AudioMixin on ReaderState {
  // ── Sesión compartida entre lectores ──
  // Pasar al siguiente libro abre otro BibleReaderScreen (otro controlador):
  // la continuación pendiente y el «dueño» del audio son estáticos para que
  // el lector viejo, al cerrarse, no detenga el audio del nuevo.
  static Object? _audioOwner;
  static DateTime? _pendingContinueUntil;
  static TtsReadMode _pendingMode = TtsReadMode.verseOnly;
  static const _continueWindow = Duration(seconds: 20);

  /// Lo asigna la pantalla: avanza al siguiente capítulo/libro. Ver
  /// [AudioChapterFinishedCallback].
  AudioChapterFinishedCallback? onAudioChapterFinished;

  bool _audioListenerAttached = false;
  bool _audioSubscribed = false;
  StreamSubscription<TtsEndReason>? _ttsEndSub;
  StreamSubscription<void>? _sleepSub;
  bool _continueAfterLoad = false;
  bool _audioDisposed = false;

  /// Se incrementa en cada inicio/parada/cambio de capítulo: un inicio en
  /// vuelo (buscando audio narrado) se descarta si el token cambió.
  int _audioToken = 0;
  TtsReadMode _audioMode = TtsReadMode.verseOnly;

  bool get _ownsAudio => identical(_audioOwner, this);

  bool get _hasPendingContinuation =>
      _continueAfterLoad ||
      (_pendingContinueUntil?.isAfter(DateTime.now()) ?? false);

  /// Si el audio está sonando ahora (no en pausa).
  bool get isAudioPlaying {
    if (realAudioActive) {
      final s = BibleAudioService.I.state.value;
      return s == AudioBibleState.playing || s == AudioBibleState.buffering;
    }
    return ttsActive && BibleTtsService.I.isPlaying.value;
  }

  // ── Lifecycle ──

  void attachAudioListener() {
    if (_audioListenerAttached) return;
    BibleAudioService.I.state.addListener(_onRealAudioStateChanged);
    _audioListenerAttached = true;
  }

  void detachAudioListener() {
    if (!_audioListenerAttached) return;
    BibleAudioService.I.state.removeListener(_onRealAudioStateChanged);
    _audioListenerAttached = false;
  }

  void _ensureAudioSubscriptions() {
    attachAudioListener();
    if (_audioSubscribed) return;
    _audioSubscribed = true;
    _ttsEndSub = BibleTtsService.I.onQueueEnded.listen(_onTtsQueueEnded);
    _sleepSub = BibleSleepTimer.I.onFired.listen((_) => _onSleepTimerFired());
    BibleTtsService.I.currentVerseIndex.addListener(_onTtsVerseChanged);
    BibleAudioService.I.currentVerse.addListener(_onRealVerseChanged);
  }

  /// Llamar en `dispose` del controlador.
  void disposeAudio() {
    _audioDisposed = true;
    _audioToken++;
    final owned = _ownsAudio || _audioOwner == null;
    unawaited(_ttsEndSub?.cancel());
    unawaited(_sleepSub?.cancel());
    _ttsEndSub = null;
    _sleepSub = null;
    if (_audioSubscribed) {
      BibleTtsService.I.currentVerseIndex.removeListener(_onTtsVerseChanged);
      BibleAudioService.I.currentVerse.removeListener(_onRealVerseChanged);
      _audioSubscribed = false;
    }
    detachAudioListener();
    if (owned) {
      _audioOwner = null;
      unawaited(BibleTtsService.I.stop());
      unawaited(BibleAudioService.I.stop());
      // Si se está pasando al siguiente libro, el temporizador sigue.
      if (!_hasPendingContinuation) BibleSleepTimer.I.cancel();
    }
    _continueAfterLoad = false;
    audioVerseIndex.dispose();
    audioVerseNumber.dispose();
  }

  // ── Cambio de capítulo ──

  /// Llamar al INICIO de `loadChapter` (cambio de capítulo, de versión o
  /// primera carga). Detiene el audio del capítulo anterior, limpia el
  /// resaltado y recuerda si hay que seguir leyendo en el nuevo capítulo:
  /// - si el capítulo anterior terminó solo con avance automático, o
  /// - si el audio estaba sonando (no en pausa) cuando el usuario cambió
  ///   de capítulo.
  void audioBeforeChapterChange() {
    _audioToken++;
    if (!_hasPendingContinuation && isAnyAudioActive && isAudioPlaying) {
      _setContinuation(_audioMode);
    }
    if (_ownsAudio) {
      unawaited(BibleTtsService.I.stop());
      unawaited(BibleAudioService.I.stop());
    }
    _resetAudioState();
  }

  /// Llamar cuando `loadChapter` ya cargó [verses] (después del
  /// notifyListeners). Si hay una continuación pendiente, empieza a leer el
  /// nuevo capítulo desde el principio.
  void audioAfterChapterLoaded() {
    if (!_hasPendingContinuation) return;
    final mode = _pendingMode;
    _clearContinuation();
    if (verses.isEmpty) return;
    unawaited(_startAudio(mode: mode == TtsReadMode.verseOnly ? null : mode));
  }

  void _setContinuation(TtsReadMode mode) {
    _continueAfterLoad = true;
    _pendingMode = mode;
    _pendingContinueUntil = DateTime.now().add(_continueWindow);
  }

  void _clearContinuation() {
    _continueAfterLoad = false;
    _pendingContinueUntil = null;
  }

  void _resetAudioState() {
    ttsActive = false;
    realAudioActive = false;
    audioVerseIndex.value = -1;
    audioVerseNumber.value = null;
  }

  // ── Toggle ──

  /// Toggle audio: detiene si está activo, o inicia (real → TTS fallback).
  /// Con [mode] distinto de versículos (modo estudio) se usa TTS directo.
  Future<void> toggleTts({TtsReadMode? mode}) async {
    if (isAnyAudioActive) {
      await stopAllAudio();
      return;
    }
    await _startAudio(mode: mode);
  }

  /// Play/pausa de la sesión activa (botón de la barra del reproductor).
  Future<void> toggleAudioPause() async {
    if (realAudioActive) {
      await BibleAudioService.I.togglePlayPause();
    } else if (BibleTtsService.I.isPlaying.value) {
      await BibleTtsService.I.pause();
    } else if (BibleTtsService.I.isPaused) {
      await BibleTtsService.I.resume();
    }
  }

  Future<void> _startAudio({TtsReadMode? mode}) async {
    if (_audioDisposed) return;
    final token = ++_audioToken;
    bool stale() => _audioDisposed || token != _audioToken || !_ownsAudio;

    _audioOwner = this;
    _ensureAudioSubscriptions();
    await BibleAudioSettings.I.ensureLoaded();
    if (stale()) return;

    // Modo estudio (comentario Guzik) → TTS directo
    if (mode != null && mode != TtsReadMode.verseOnly) {
      if (studyModeEnabled && guzikChapter == null) {
        await loadGuzikCommentary();
      }
      if (stale()) return;
      _startTtsWithMode(mode);
      return;
    }

    // Pausar BGM
    final engine = AudioEngine.I;
    if (engine.bgmState.value == BgmPlaybackState.playing) {
      await engine.pauseBgm();
    }

    // Intentar audio narrado de la versión activa primero
    final success = await BibleAudioService.I.playChapter(
      version: currentVersion,
      bookNumber: bookNumber,
      chapter: currentChapter,
    );

    // El capítulo cambió o se detuvo mientras se buscaba el audio.
    if (stale()) {
      if (success && !_audioDisposed) await BibleAudioService.I.stop();
      return;
    }

    if (success) {
      _audioMode = TtsReadMode.verseOnly;
      realAudioActive = true;
      ttsActive = true;
      notifyListeners();
    } else {
      debugPrint('[Audio] No real audio available, using TTS fallback');
      _startTtsWithMode(TtsReadMode.verseOnly);
    }
  }

  /// Detiene todo audio (real y TTS) por decisión del usuario: cancela
  /// también el temporizador y cualquier continuación pendiente.
  Future<void> stopAllAudio() async {
    _audioToken++;
    _clearContinuation();
    BibleSleepTimer.I.cancel();
    final wasReal = realAudioActive;
    _resetAudioState();
    notifyListeners();
    if (wasReal || _ownsAudio) await BibleAudioService.I.stop();
    await BibleTtsService.I.stop();
  }

  // ── Eventos de los servicios ──

  void _onRealAudioStateChanged() {
    if (!_ownsAudio || !realAudioActive) return;
    if (BibleAudioService.I.state.value == AudioBibleState.idle) {
      _handleChapterEnd(natural: BibleAudioService.I.completedNaturally);
    }
  }

  void _onTtsQueueEnded(TtsEndReason reason) {
    if (!_ownsAudio || realAudioActive || !ttsActive) return;
    _handleChapterEnd(natural: reason == TtsEndReason.completed);
  }

  void _onSleepTimerFired() {
    if (!_ownsAudio || !isAnyAudioActive) return;
    _audioToken++;
    _clearContinuation();
    final wasReal = realAudioActive;
    _resetAudioState();
    notifyListeners();
    if (wasReal) unawaited(BibleAudioService.I.stop());
    unawaited(BibleTtsService.I.stop());
  }

  /// El capítulo terminó solo ([natural]) o falló. Limpia el estado y, si
  /// corresponde, avanza al siguiente capítulo.
  void _handleChapterEnd({required bool natural}) {
    final mode = _audioMode;
    _resetAudioState();
    if (!natural || BibleSleepTimer.I.consumeEndOfChapter()) {
      _clearContinuation();
      notifyListeners();
      return;
    }
    final advance = onAudioChapterFinished;
    if (!BibleAudioSettings.I.autoAdvance.value || advance == null) {
      notifyListeners();
      return;
    }
    _setContinuation(mode);
    notifyListeners();
    var advanced = false;
    try {
      advanced = advance();
    } catch (e) {
      debugPrint('[Audio] onAudioChapterFinished falló: $e');
    }
    if (!advanced) _clearContinuation();
  }

  void _onTtsVerseChanged() {
    if (!_ownsAudio || realAudioActive) return;
    final idx = BibleTtsService.I.currentVerseIndex.value;
    _setAudioVerse(idx >= 0 && idx < verses.length ? idx : -1);
  }

  void _onRealVerseChanged() {
    if (!_ownsAudio || !realAudioActive) return;
    final number = BibleAudioService.I.currentVerse.value;
    _setAudioVerse(number == null ? -1 : indexForVerseNumber(number));
  }

  /// Índice en [verses] para el número de versículo [number] (el parser
  /// omite versículos vacíos, así que índice ≠ número - 1). Si no está
  /// exacto, el último versículo anterior a él; -1 si ninguno.
  int indexForVerseNumber(int number) {
    var best = -1;
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i].verse;
      if (v == number) return i;
      if (v < number) best = i;
    }
    return best;
  }

  void _setAudioVerse(int idx) {
    audioVerseIndex.value = idx;
    audioVerseNumber.value = idx >= 0 ? verses[idx].verse : null;
  }

  void _startTtsWithMode(TtsReadMode mode) {
    _audioMode = mode;
    final queue = _buildTtsQueue(mode);
    unawaited(
      BibleTtsService.I.startReadingQueue(
        queue,
        mode: mode,
        language: currentVersion.language,
      ),
    );
    ttsActive = true;
    notifyListeners();
  }

  List<TtsQueueItem> _buildTtsQueue(TtsReadMode mode) {
    final queue = <TtsQueueItem>[];

    if (mode == TtsReadMode.verseOnly || guzikChapter == null) {
      for (int i = 0; i < verses.length; i++) {
        queue.add(TtsQueueItem(verses[i].text.trim(), i));
      }
    } else if (mode == TtsReadMode.annotationOnly) {
      for (final section in guzikChapter!.sections) {
        _addSectionToQueue(queue, section);
      }
    } else {
      for (final item in studyItems) {
        switch (item.type) {
          case StudyItemType.verse:
            final v = verses[item.index];
            queue.add(TtsQueueItem(v.text.trim(), item.index));
          case StudyItemType.annotation:
            final section = guzikChapter!.sections[item.index];
            _addSectionToQueue(queue, section);
          case StudyItemType.banner:
          case StudyItemType.attribution:
            break;
        }
      }
    }

    return queue;
  }

  void _addSectionToQueue(List<TtsQueueItem> queue, EWSection section) {
    if (section.heading.isNotEmpty) {
      queue.add(TtsQueueItem(section.heading, -1));
    }
    for (final paragraph in section.paragraphs) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.length > 3000) {
        final chunks = _splitLongText(trimmed, 2500);
        for (final chunk in chunks) {
          queue.add(TtsQueueItem(chunk, -1));
        }
      } else {
        queue.add(TtsQueueItem(trimmed, -1));
      }
    }
  }

  static List<String> _splitLongText(String text, int maxLen) {
    final chunks = <String>[];
    var remaining = text;
    while (remaining.length > maxLen) {
      var splitAt = remaining.lastIndexOf('. ', maxLen);
      if (splitAt <= 0) splitAt = remaining.lastIndexOf(' ', maxLen);
      if (splitAt <= 0) splitAt = maxLen;
      chunks.add(remaining.substring(0, splitAt + 1).trim());
      remaining = remaining.substring(splitAt + 1).trim();
    }
    if (remaining.isNotEmpty) chunks.add(remaining);
    return chunks;
  }
}
