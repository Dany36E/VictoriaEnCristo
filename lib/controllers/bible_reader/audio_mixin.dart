import 'package:flutter/foundation.dart';
import '../../services/bible/bible_audio_service.dart';
import '../../services/bible/bible_tts_service.dart';
import '../../services/bible/enduring_word_service.dart';
import '../../services/audio_engine.dart';
import 'reader_state.dart';

/// Gestión del audio bíblico (audio real + TTS fallback).
mixin AudioMixin on ReaderState {
  bool _audioListenerAttached = false;

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

  void disposeAudio() {
    BibleTtsService.I.stop();
    BibleAudioService.I.stop();
    detachAudioListener();
  }

  // ── Toggle ──

  /// Toggle audio: detiene si está activo, o inicia (real → TTS fallback).
  Future<void> toggleTts({TtsReadMode? mode}) async {
    if (realAudioActive) {
      await BibleAudioService.I.stop();
      realAudioActive = false;
      notifyListeners();
      return;
    }
    if (ttsActive) {
      BibleTtsService.I.stop();
      ttsActive = false;
      notifyListeners();
      return;
    }

    // Si modo estudio con Guzik y se pide modo específico → TTS directo
    if (mode != null) {
      if (mode != TtsReadMode.verseOnly &&
          studyModeEnabled && guzikChapter == null) {
        await loadGuzikCommentary();
      }
      _startTtsWithMode(mode);
      return;
    }

    // Pausar BGM
    final engine = AudioEngine.I;
    if (engine.bgmState.value == BgmPlaybackState.playing) {
      await engine.pauseBgm();
    }

    // Intentar audio real primero
    final success = await BibleAudioService.I.playChapter(
      bookNumber: bookNumber,
      chapter: currentChapter,
    );

    if (success) {
      realAudioActive = true;
      ttsActive = true;
      notifyListeners();
      attachAudioListener();
    } else {
      debugPrint('[Audio] No real audio available, using TTS fallback');
      BibleTtsService.I.startReading(verses);
      ttsActive = true;
      notifyListeners();
    }
  }

  void _onRealAudioStateChanged() {
    if (BibleAudioService.I.state.value == AudioBibleState.idle &&
        realAudioActive) {
      realAudioActive = false;
      ttsActive = false;
      detachAudioListener();
      notifyListeners();
    }
  }

  /// Detiene todo audio (real y TTS).
  Future<void> stopAllAudio() async {
    if (realAudioActive) {
      await BibleAudioService.I.stop();
      detachAudioListener();
      realAudioActive = false;
    }
    BibleTtsService.I.stop();
    ttsActive = false;
    notifyListeners();
  }

  void _startTtsWithMode(TtsReadMode mode) {
    final queue = _buildTtsQueue(mode);
    BibleTtsService.I.startReadingQueue(queue, mode: mode);
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
