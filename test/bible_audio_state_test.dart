import 'dart:async';

import 'package:app_quitar/controllers/bible_reader/audio_mixin.dart';
import 'package:app_quitar/controllers/bible_reader/reader_state.dart';
import 'package:app_quitar/models/bible/bible_verse.dart';
import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/services/bible/bible_audio_service.dart';
import 'package:app_quitar/services/bible/bible_audio_settings.dart';
import 'package:app_quitar/services/bible/bible_tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Motor TTS falso: registra lo que se le pide y deja que el test decida
// cuándo termina cada texto.
// ═══════════════════════════════════════════════════════════════════════════
class FakeTtsEngine implements BibleTtsEngine {
  FakeTtsEngine({this.voices = const [], this.voicesThrow = false});

  final List<TtsVoice> voices;
  final bool voicesThrow;
  bool speakOk = true;

  final spoken = <String>[];
  final rates = <double>[];
  final languages = <String>[];
  final voicesSet = <TtsVoice>[];
  int stops = 0;

  VoidCallback? _complete;
  void Function(String)? _error;

  @override
  set onComplete(VoidCallback? callback) => _complete = callback;

  @override
  set onError(void Function(String message)? callback) => _error = callback;

  /// Simula que el motor terminó de decir el texto actual.
  void complete() => _complete?.call();

  void fail(String msg) => _error?.call(msg);

  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    return speakOk;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> setSpeechRate(double rate) async => rates.add(rate);

  @override
  Future<bool> setLanguage(String locale) async {
    languages.add(locale);
    return true;
  }

  @override
  Future<bool> setVoice(TtsVoice voice) async {
    voicesSet.add(voice);
    return true;
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    if (voicesThrow) throw Exception('sin plugin');
    return voices;
  }
}

/// Deja correr microtareas y timers de duración cero.
Future<void> settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<BibleVerse> versesFor(int chapter, {int count = 3}) => [
  for (var i = 1; i <= count; i++)
    BibleVerse(
      bookName: 'Juan',
      bookNumber: 43,
      chapter: chapter,
      verse: i,
      text: 'Capítulo $chapter versículo $i',
      version: 'NTV',
    ),
];

/// Lector mínimo con el AudioMixin (NTV: sin audio narrado → siempre TTS).
class TestReader extends ReaderState with AudioMixin {
  TestReader({this.totalChaps = 3}) {
    verses = versesFor(1);
    totalChapters = totalChaps;
  }

  final int totalChaps;

  @override
  int get bookNumber => 43;
  @override
  String get bookName => 'Juan';
  @override
  BibleVersion get currentVersion => BibleVersion.ntv;
  @override
  int currentChapter = 1;

  /// Igual que BibleReaderController.loadChapter, sin parser.
  void goToChapter(int chapter) {
    audioBeforeChapterChange();
    currentChapter = chapter;
    verses = versesFor(chapter);
    notifyListeners();
    audioAfterChapterLoaded();
  }

  @override
  Future<void> loadGuzikCommentary() async {}
  @override
  void buildStudyItems() {}

  @override
  void dispose() {
    disposeAudio();
    super.dispose();
  }
}

const _esLocal = TtsVoice(
  name: 'es-es-x-eea-local',
  locale: 'es-ES',
  quality: 'normal',
);
const _esMxLocal = TtsVoice(
  name: 'es-mx-x-mxa-local',
  locale: 'es-MX',
  quality: 'normal',
);
const _esUsNetwork = TtsVoice(
  name: 'es-us-x-esd-network',
  locale: 'es-US',
  quality: 'high',
  networkRequired: true,
);
const _esMxNotInstalled = TtsVoice(
  name: 'es-mx-x-mxb-network',
  locale: 'es-MX',
  quality: 'very high',
  networkRequired: true,
  features: 'networkTimeoutMs\tnotInstalled',
);
const _enLocal = TtsVoice(
  name: 'en-gb-x-gba-local',
  locale: 'en-GB',
  quality: 'normal',
);
const _enNetwork = TtsVoice(
  name: 'en-us-x-iom-network',
  locale: 'en-US',
  quality: 'high',
  networkRequired: true,
);
const _allVoices = [
  _esLocal,
  _esMxLocal,
  _esUsNetwork,
  _esMxNotInstalled,
  _enLocal,
  _enNetwork,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('BibleTtsService (motor falso)', () {
    late FakeTtsEngine fake;
    late BibleAudioSettings settings;
    late BibleTtsService tts;
    late List<TtsEndReason> ended;
    late StreamSubscription<TtsEndReason> sub;

    setUp(() async {
      fake = FakeTtsEngine(voices: _allVoices);
      settings = BibleAudioSettings.forTesting();
      await settings.ensureLoaded();
      tts = BibleTtsService.forTesting(
        fake,
        settings: settings,
        platform: TargetPlatform.android,
      );
      ended = [];
      sub = tts.onQueueEnded.listen(ended.add);
    });

    tearDown(() async {
      await sub.cancel();
      await tts.dispose();
    });

    test('la cola avanza con cada finalización y al terminar se limpia',
        () async {
      final verses = versesFor(1);
      await tts.startReading(verses);
      expect(tts.isPlaying.value, isTrue);
      expect(tts.currentVerseIndex.value, 0);
      expect(fake.spoken, ['Capítulo 1 versículo 1']);

      fake.complete();
      await settle();
      expect(tts.currentVerseIndex.value, 1);
      fake.complete();
      await settle();
      expect(tts.currentVerseIndex.value, 2);
      expect(ended, isEmpty);

      fake.complete();
      await settle();
      expect(tts.isPlaying.value, isFalse);
      expect(tts.currentVerseIndex.value, -1);
      expect(ended, [TtsEndReason.completed]);
    });

    test('textos vacíos se saltan sin contarse como error', () async {
      await tts.startReadingQueue(const [
        TtsQueueItem('', 0),
        TtsQueueItem('Hola', 1),
      ]);
      await settle();
      expect(fake.spoken, ['Hola']);
      expect(tts.currentVerseIndex.value, 1);
      fake.complete();
      await settle();
      expect(ended, [TtsEndReason.completed]);
    });

    test('si el motor falla seguido, termina con error', () async {
      fake.speakOk = false;
      await tts.startReading(versesFor(1, count: 5));
      await settle();
      expect(tts.isPlaying.value, isFalse);
      expect(tts.currentVerseIndex.value, -1);
      expect(ended, [TtsEndReason.error]);
      expect(fake.spoken.length, 3); // se rinde a los 3 errores seguidos
    });

    test('stop (cambio de capítulo) limpia el índice y no avisa fin', () async {
      await tts.startReading(versesFor(1));
      fake.complete();
      await settle();
      expect(tts.currentVerseIndex.value, 1);

      await tts.stop();
      expect(tts.currentVerseIndex.value, -1);
      expect(tts.isPlaying.value, isFalse);
      // Una finalización tardía del motor no hace nada.
      fake.complete();
      await settle();
      expect(tts.currentVerseIndex.value, -1);
      expect(ended, isEmpty);
    });

    test('pausa y reanuda releyendo el versículo actual', () async {
      await tts.startReading(versesFor(1));
      fake.complete();
      await settle();
      await tts.pause();
      expect(tts.isPlaying.value, isFalse);
      expect(tts.isPaused, isTrue);
      fake.complete(); // finalización del texto interrumpido: se ignora
      await settle();
      expect(tts.currentVerseIndex.value, 1);
      await tts.resume();
      expect(fake.spoken.last, 'Capítulo 1 versículo 2');
      expect(tts.isPlaying.value, isTrue);
    });

    test('cambiar la velocidad mientras lee se aplica en vivo', () async {
      await tts.startReading(versesFor(1));
      expect(fake.rates.last, closeTo(0.45, 1e-9));
      final before = fake.spoken.length;

      await settings.setSpeed(1.5);
      await settle();
      expect(fake.rates.last, closeTo(0.45 * 1.5, 1e-9));
      // Relee el item actual con la nueva velocidad.
      expect(fake.spoken.length, before + 1);
      expect(fake.spoken.last, 'Capítulo 1 versículo 1');
      expect(tts.currentVerseIndex.value, 0);
    });

    test('elige la mejor voz en español y respeta la elección del usuario',
        () async {
      await tts.startReading(versesFor(1));
      expect(fake.voicesSet.last, _esUsNetwork);
      expect(tts.activeVoice.value, _esUsNetwork);

      await settings.setVoice(
        BibleLanguage.spanish,
        _esLocal.toPreference(),
      );
      await settle();
      expect(fake.voicesSet.last, _esLocal);
    });

    test('las versiones en inglés usan voces en inglés', () async {
      final verses = [
        for (final v in versesFor(1))
          BibleVerse(
            bookName: 'John',
            bookNumber: 43,
            chapter: 1,
            verse: v.verse,
            text: 'In the beginning',
            version: 'NIV_EN',
          ),
      ];
      await tts.startReading(verses);
      expect(fake.voicesSet.last, _enNetwork);
    });

    test('si getVoices falla, usa el idioma por defecto sin romperse',
        () async {
      final noVoices = FakeTtsEngine(voicesThrow: true);
      final service = BibleTtsService.forTesting(
        noVoices,
        settings: settings,
        platform: TargetPlatform.android,
      );
      await service.startReading(versesFor(1));
      expect(service.isPlaying.value, isTrue);
      expect(noVoices.voicesSet, isEmpty);
      expect(noVoices.languages, contains('es-MX'));
      expect(await service.voicesFor(BibleLanguage.spanish), isEmpty);
      await service.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('BibleVoicePicker', () {
    test('prefiere voces de red/mejoradas sobre locales', () {
      expect(
        BibleVoicePicker.pick(_allVoices, BibleLanguage.spanish),
        _esUsNetwork,
      );
    });

    test('a igual calidad prefiere es-MX / es-US sobre es-ES', () {
      expect(
        BibleVoicePicker.pick(
          const [_esLocal, _esMxLocal],
          BibleLanguage.spanish,
        ),
        _esMxLocal,
      );
    });

    test('descarta voces sin instalar', () {
      final ranked = BibleVoicePicker.rank(_allVoices, BibleLanguage.spanish);
      expect(ranked, isNot(contains(_esMxNotInstalled)));
      expect(ranked.every((v) => v.locale.startsWith('es')), isTrue);
    });

    test('iOS: premium > enhanced > compacta; ignora voces de novedad', () {
      const compact = TtsVoice(
        name: 'Paulina',
        locale: 'es-MX',
        quality: 'default',
        identifier: 'com.apple.voice.compact.es-MX.Paulina',
      );
      const enhanced = TtsVoice(
        name: 'Mónica',
        locale: 'es-ES',
        quality: 'enhanced',
        identifier: 'com.apple.voice.enhanced.es-ES.Monica',
      );
      const premium = TtsVoice(
        name: 'Paulina (premium)',
        locale: 'es-MX',
        quality: 'premium',
        identifier: 'com.apple.voice.premium.es-MX.Paulina',
      );
      const novelty = TtsVoice(
        name: 'Eddy',
        locale: 'es-MX',
        quality: 'default',
        identifier: 'com.apple.eloquence.es-MX.Eddy',
      );
      expect(
        BibleVoicePicker.pick(
          const [compact, enhanced, novelty],
          BibleLanguage.spanish,
        ),
        enhanced,
      );
      expect(
        BibleVoicePicker.pick(
          const [compact, enhanced, premium],
          BibleLanguage.spanish,
        ),
        premium,
      );
      expect(
        BibleVoicePicker.rank(const [novelty], BibleLanguage.spanish),
        isEmpty,
      );
    });

    test('la elección explícita gana; si ya no existe, la mejor', () {
      expect(
        BibleVoicePicker.pick(
          _allVoices,
          BibleLanguage.spanish,
          preferred: _esLocal.toPreference(),
        ),
        _esLocal,
      );
      expect(
        BibleVoicePicker.pick(
          _allVoices,
          BibleLanguage.spanish,
          preferred: const TtsVoicePreference(name: 'borrada', locale: 'es-MX'),
        ),
        _esUsNetwork,
      );
    });

    test('sin voces devuelve null', () {
      expect(BibleVoicePicker.pick(const [], BibleLanguage.spanish), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Velocidad', () {
    test('Android: 0.45 × velocidad (flutter_tts 0.5 = normal)', () {
      double rate(double s) =>
          BibleTtsRate.forSpeed(s, platform: TargetPlatform.android, isWeb: false);
      expect(rate(1.0), closeTo(0.45, 1e-9));
      expect(rate(0.75), closeTo(0.3375, 1e-9));
      expect(rate(2.0), closeTo(0.9, 1e-9));
    });

    test('iOS: AVSpeechUtterance con 0.5 = normal', () {
      double rate(double s) =>
          BibleTtsRate.forSpeed(s, platform: TargetPlatform.iOS, isWeb: false);
      expect(rate(1.0), closeTo(0.5, 1e-9));
      expect(rate(0.75), closeTo(0.42, 1e-9));
      expect(rate(2.0), closeTo(0.68, 1e-9));
      expect(rate(1.125), closeTo(0.525, 1e-9));
      expect(rate(1.25) > rate(1.0) && rate(1.5) > rate(1.25), isTrue);
    });

    test('web y Windows', () {
      expect(BibleTtsRate.forSpeed(1.5, isWeb: true), 1.5);
      expect(
        BibleTtsRate.forSpeed(
          1.0,
          platform: TargetPlatform.windows,
          isWeb: false,
        ),
        closeTo(0.5, 1e-9),
      );
    });

    test('etiquetas y normalización', () async {
      expect(BibleAudioSettings.speedLabel(1.0), '1x');
      expect(BibleAudioSettings.speedLabel(1.25), '1,25x');
      expect(BibleAudioSettings.normalizeSpeed(1.3), 1.25);
      final s = BibleAudioSettings.forTesting();
      await s.ensureLoaded();
      await s.setSpeed(2.0);
      final reloaded = BibleAudioSettings.forTesting();
      await reloaded.ensureLoaded();
      expect(reloaded.speed.value, 2.0);
      expect(reloaded.autoAdvance.value, isTrue); // por defecto activo
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Temporizador de sueño', () {
    void tick(BibleSleepTimer timer, Duration d) {
      for (var i = 0; i < d.inSeconds; i++) {
        timer.debugTick();
      }
    }

    test('con minutos cuenta hacia atrás y avisa al vencer', () async {
      final timer = BibleSleepTimer.forTesting();
      var fired = 0;
      final sub = timer.onFired.listen((_) => fired++);

      timer.set(SleepTimerMode.minutes15);
      expect(timer.remaining.value, const Duration(minutes: 15));

      tick(timer, const Duration(minutes: 1));
      expect(timer.remaining.value, const Duration(minutes: 14));
      await settle();
      expect(fired, 0);

      tick(timer, const Duration(minutes: 14));
      await settle();
      expect(fired, 1);
      expect(timer.mode.value, SleepTimerMode.off);
      expect(timer.remaining.value, isNull);

      await sub.cancel();
      await timer.dispose();
    });

    test('cancelar detiene la cuenta', () async {
      final timer = BibleSleepTimer.forTesting();
      var fired = 0;
      final sub = timer.onFired.listen((_) => fired++);
      timer.set(SleepTimerMode.minutes30);
      tick(timer, const Duration(minutes: 5));
      expect(timer.remaining.value, const Duration(minutes: 25));
      timer.cancel();
      tick(timer, const Duration(minutes: 40));
      await settle();
      expect(fired, 0);
      expect(timer.remaining.value, isNull);
      await sub.cancel();
      await timer.dispose();
    });

    test('al terminar el capítulo: se consume una sola vez', () async {
      final timer = BibleSleepTimer.forTesting();
      timer.set(SleepTimerMode.endOfChapter);
      expect(timer.remaining.value, isNull);
      expect(timer.consumeEndOfChapter(), isTrue);
      expect(timer.mode.value, SleepTimerMode.off);
      expect(timer.consumeEndOfChapter(), isFalse);
      await timer.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Versión → filesets de Bible Brain', () {
    final idFormat = RegExp(r'^[A-Z]{3}[A-Z0-9]{3}[ON][12]DA$');

    test('cada versión solo prueba sus propios filesets, AT y NT', () {
      expect(
        BibleAudioService.filesetsFor(BibleVersion.rvr1960, 43),
        ['SPNRVRN2DA', 'SPNRVRN1DA'],
      );
      expect(
        BibleAudioService.filesetsFor(BibleVersion.rvr1960, 1),
        ['SPNRVRO2DA', 'SPNRVRO1DA'],
      );
      expect(
        BibleAudioService.filesetsFor(BibleVersion.nvi, 40).first,
        'SPNNVIN2DA',
      );
      // Sin audio narrado configurado → solo TTS.
      expect(BibleAudioService.filesetsFor(BibleVersion.ntv, 43), isEmpty);
      expect(BibleAudioService.filesetsFor(BibleVersion.nkjv, 1), isEmpty);
    });

    test('los IDs tienen formato DBP y el testamento correcto', () {
      kBibleAudioFilesets.forEach((versionId, fs) {
        expect(
          BibleVersion.values.any((v) => v.id == versionId),
          isTrue,
          reason: '$versionId no es una BibleVersion',
        );
        for (final id in fs.ot) {
          expect(idFormat.hasMatch(id), isTrue, reason: id);
          expect(id[6], 'O', reason: id);
        }
        for (final id in fs.nt) {
          expect(idFormat.hasMatch(id), isTrue, reason: id);
          expect(id[6], 'N', reason: id);
        }
        // Todos los filesets de una versión son de la misma Biblia.
        final prefixes = {...fs.ot, ...fs.nt}.map((id) => id.substring(0, 6));
        expect(prefixes.toSet().length, 1, reason: versionId);
      });
      final allPrefixes = kBibleAudioFilesets.values
          .map((fs) => fs.nt.first.substring(0, 6))
          .toList();
      expect(allPrefixes.toSet().length, allPrefixes.length);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('AudioMixin (máquina de estados)', () {
    late FakeTtsEngine fake;
    late TestReader reader;

    setUp(() async {
      fake = FakeTtsEngine(voices: _allVoices);
      BibleTtsService.I.engine = fake;
      await BibleAudioSettings.I.ensureLoaded();
      await BibleAudioSettings.I.setAutoAdvance(true);
      BibleSleepTimer.I.cancel();
      reader = TestReader();
    });

    tearDown(() async {
      await reader.stopAllAudio();
      reader.dispose();
      await settle();
    });

    Future<void> finishChapter() async {
      for (var i = 0; i < reader.verses.length; i++) {
        fake.complete();
        await settle();
      }
    }

    test('al terminar el capítulo avanza y sigue leyendo', () async {
      var advances = 0;
      reader.onAudioChapterFinished = () {
        advances++;
        reader.goToChapter(reader.currentChapter + 1);
        return true;
      };
      await reader.toggleTts();
      await settle();
      expect(reader.ttsActive, isTrue);
      expect(reader.audioVerseIndex.value, 0);
      expect(reader.audioVerseNumber.value, 1);

      await finishChapter();
      expect(advances, 1);
      expect(reader.currentChapter, 2);
      expect(reader.ttsActive, isTrue);
      expect(fake.spoken.last, 'Capítulo 2 versículo 1');
      expect(reader.audioVerseIndex.value, 0);
    });

    test('sin avance automático se detiene y limpia el estado', () async {
      await BibleAudioSettings.I.setAutoAdvance(false);
      var advances = 0;
      reader.onAudioChapterFinished = () {
        advances++;
        return true;
      };
      await reader.toggleTts();
      await settle();
      await finishChapter();
      expect(advances, 0);
      expect(reader.ttsActive, isFalse);
      expect(reader.realAudioActive, isFalse);
      expect(reader.isAnyAudioActive, isFalse);
      expect(reader.audioVerseIndex.value, -1);
      expect(BibleTtsService.I.currentVerseIndex.value, -1);
    });

    test('fin de la Biblia: el callback devuelve false y se detiene',
        () async {
      reader.onAudioChapterFinished = () => false;
      await reader.toggleTts();
      await settle();
      await finishChapter();
      expect(reader.ttsActive, isFalse);
      // No queda una continuación pendiente para el próximo capítulo.
      reader.goToChapter(2);
      await settle();
      expect(reader.ttsActive, isFalse);
    });

    test('cambiar de capítulo mientras suena: se detiene, limpia y sigue',
        () async {
      await reader.toggleTts();
      await settle();
      fake.complete();
      await settle();
      expect(reader.audioVerseIndex.value, 1);

      reader.goToChapter(3);
      // El resaltado del capítulo anterior no se queda pegado.
      expect(BibleTtsService.I.currentVerseIndex.value, anyOf(-1, 0));
      await settle();
      expect(reader.ttsActive, isTrue);
      expect(fake.spoken.last, 'Capítulo 3 versículo 1');
      expect(reader.audioVerseIndex.value, 0);
    });

    test('cambiar de capítulo en pausa: se detiene sin seguir', () async {
      await reader.toggleTts();
      await settle();
      await reader.toggleAudioPause();
      expect(BibleTtsService.I.isPaused, isTrue);

      reader.goToChapter(2);
      await settle();
      expect(reader.ttsActive, isFalse);
      expect(reader.audioVerseIndex.value, -1);
      expect(BibleTtsService.I.currentVerseIndex.value, -1);
    });

    test('temporizador «al terminar el capítulo»: no avanza', () async {
      var advances = 0;
      reader.onAudioChapterFinished = () {
        advances++;
        return true;
      };
      BibleSleepTimer.I.set(SleepTimerMode.endOfChapter);
      await reader.toggleTts();
      await settle();
      await finishChapter();
      expect(advances, 0);
      expect(reader.ttsActive, isFalse);
      expect(BibleSleepTimer.I.mode.value, SleepTimerMode.off);
    });

    test('si el motor falla se limpia el estado sin avanzar', () async {
      var advances = 0;
      reader.onAudioChapterFinished = () {
        advances++;
        return true;
      };
      fake.speakOk = false;
      await reader.toggleTts();
      await settle();
      expect(advances, 0);
      expect(reader.ttsActive, isFalse);
      expect(reader.audioVerseIndex.value, -1);
    });

    test('detener a mano cancela el temporizador', () async {
      BibleSleepTimer.I.set(SleepTimerMode.endOfChapter);
      await reader.toggleTts();
      await settle();
      await reader.toggleTts(); // detener
      expect(reader.ttsActive, isFalse);
      expect(BibleSleepTimer.I.mode.value, SleepTimerMode.off);
    });

    test('indexForVerseNumber tolera versículos omitidos', () {
      reader.verses = [
        for (final n in [1, 2, 4, 5])
          BibleVerse(
            bookName: 'Juan',
            bookNumber: 43,
            chapter: 1,
            verse: n,
            text: 'v$n',
            version: 'NTV',
          ),
      ];
      expect(reader.indexForVerseNumber(4), 2);
      expect(reader.indexForVerseNumber(3), 1);
      expect(reader.indexForVerseNumber(9), 3);
    });
  });
}
