import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../audio_engine.dart';
import 'bible_audio_settings.dart';

/// Modo de lectura TTS
enum TtsReadMode { verseOnly, annotationOnly, both }

/// Cómo terminó la cola de lectura.
enum TtsEndReason {
  /// Se leyó toda la cola.
  completed,

  /// El motor falló (sin voz instalada, errores seguidos, etc.).
  error,
}

/// Elemento de la cola de lectura TTS
class TtsQueueItem {
  final String text;
  final int verseIndex; // -1 para items que no son versículos
  const TtsQueueItem(this.text, this.verseIndex);
}

// ═══════════════════════════════════════════════════════════════════════════
// VOCES
// ═══════════════════════════════════════════════════════════════════════════

/// Voz del motor TTS (lo que devuelve `flutter_tts.getVoices`).
@immutable
class TtsVoice {
  final String name;
  final String locale;

  /// Android: «very high», «high», «normal»…  iOS: «default», «enhanced»,
  /// «premium».
  final String? quality;
  final bool networkRequired;

  /// Android: features separadas por tabulador (p. ej. «notInstalled»).
  final String? features;

  /// iOS/macOS: identificador de AVSpeechSynthesisVoice.
  final String? identifier;

  const TtsVoice({
    required this.name,
    required this.locale,
    this.quality,
    this.networkRequired = false,
    this.features,
    this.identifier,
  });

  static TtsVoice? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name']?.toString();
    final locale = raw['locale']?.toString();
    if (name == null || name.isEmpty || locale == null) return null;
    final net = raw['network_required']?.toString();
    return TtsVoice(
      name: name,
      locale: locale,
      quality: raw['quality']?.toString(),
      networkRequired: net == '1' || net == 'true',
      features: raw['features']?.toString(),
      identifier: raw['identifier']?.toString(),
    );
  }

  Map<String, String> toEngineMap() => {
    'name': name,
    'locale': locale,
    if (identifier != null && identifier!.isNotEmpty) 'identifier': identifier!,
  };

  /// Locale normalizado: «es_MX» → «es-mx».
  String get normalizedLocale => locale.replaceAll('_', '-').toLowerCase();

  bool matches(TtsVoicePreference pref) =>
      name == pref.name &&
      normalizedLocale == pref.locale.replaceAll('_', '-').toLowerCase();

  TtsVoicePreference toPreference() =>
      TtsVoicePreference(name: name, locale: locale);

  /// Nombre legible para la lista de ajustes.
  String get displayName {
    final n = name.toLowerCase();
    if (n.contains('-x-')) {
      // Android: «es-us-x-esd-network» → «es-US · esd (en línea)»
      final tag = name.split('-x-').last.split('-').first;
      final online = n.contains('network') ? ' (en línea)' : '';
      return '$locale · $tag$online';
    }
    return '$name ($locale)';
  }

  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);

  @override
  String toString() => 'TtsVoice($name, $locale, q=$quality)';
}

/// Ordena y elige voces: mejor calidad primero y, a igual calidad, el acento
/// preferido (latinoamericano antes que España; EE. UU. antes que Reino Unido).
class BibleVoicePicker {
  const BibleVoicePicker._();

  /// Si la voz es del idioma pedido.
  static bool isForLanguage(TtsVoice v, BibleLanguage language) {
    final loc = v.normalizedLocale;
    return loc == language.code || loc.startsWith('${language.code}-');
  }

  /// Nivel de calidad (0 = no usable/novedad, 3 = premium/neural).
  static int qualityTier(TtsVoice v) {
    final name = v.name.toLowerCase();
    final id = (v.identifier ?? '').toLowerCase();
    final q = (v.quality ?? '').toLowerCase();
    final features = (v.features ?? '').toLowerCase();

    // Voces sin instalar (Android) o de novedad (iOS: Eloquence, «Bells»,
    // «Bubbles»…) no sirven para leer la Biblia.
    if (features.contains('notinstalled')) return 0;
    if (id.contains('eloquence') || id.contains('speech.synthesis.voice')) {
      return 0;
    }

    if (q == 'premium' ||
        id.contains('premium') ||
        name.contains('neural') ||
        name.contains('premium') ||
        name.contains('wavenet')) {
      return 3;
    }
    if (q == 'enhanced' ||
        q == 'very high' ||
        q == 'high' ||
        id.contains('enhanced') ||
        name.contains('enhanced') ||
        name.contains('network') ||
        v.networkRequired) {
      return 2;
    }
    // Calidad numérica (algunos motores la dan como 400/500).
    final numeric = int.tryParse(q);
    if (numeric != null && numeric >= 400) return 2;
    return 1;
  }

  /// Preferencia de acento dentro del idioma.
  static int localeScore(TtsVoice v, BibleLanguage language) {
    final loc = v.normalizedLocale;
    if (language == BibleLanguage.english) {
      if (loc.startsWith('en-us')) return 5;
      if (loc.startsWith('en-gb')) return 3;
      return 1;
    }
    if (loc.startsWith('es-mx')) return 5;
    if (loc.startsWith('es-us') || loc.startsWith('es-419')) return 4;
    if (loc.startsWith('es-es')) return 2;
    return 1;
  }

  static int score(TtsVoice v, BibleLanguage language) =>
      qualityTier(v) * 10 + localeScore(v, language);

  /// Voces del idioma, de mejor a peor (sin las inutilizables).
  static List<TtsVoice> rank(List<TtsVoice> voices, BibleLanguage language) {
    final list = voices
        .where((v) => isForLanguage(v, language) && qualityTier(v) > 0)
        .toSet()
        .toList();
    list.sort((a, b) {
      final byScore = score(b, language).compareTo(score(a, language));
      if (byScore != 0) return byScore;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  /// Elige la voz: la explícita del usuario si existe; si no, la mejor.
  static TtsVoice? pick(
    List<TtsVoice> voices,
    BibleLanguage language, {
    TtsVoicePreference? preferred,
  }) {
    if (preferred != null) {
      for (final v in voices) {
        if (v.matches(preferred)) return v;
      }
    }
    final ranked = rank(voices, language);
    return ranked.isEmpty ? null : ranked.first;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VELOCIDAD
// ═══════════════════════════════════════════════════════════════════════════

/// Convierte la velocidad que ve el usuario (0.75x–2x) a lo que espera
/// `flutter_tts.setSpeechRate` en cada plataforma.
class BibleTtsRate {
  const BibleTtsRate._();

  /// Android: flutter_tts multiplica por 2 (0.5 = normal). Leemos un poco
  /// más pausado que la voz normal (0.45 ≈ 0.9x), como antes.
  static const double androidBase = 0.45;

  /// iOS/macOS: AVSpeechUtterance (0.5 = normal, escala no lineal).
  /// Pares velocidad → rate, interpolados linealmente entre puntos.
  static const List<double> _appleSpeeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  static const List<double> _appleRates = [0.42, 0.5, 0.55, 0.6, 0.68];

  static double forSpeed(
    double speed, {
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    final s = speed.clamp(0.5, 2.0).toDouble();
    if (isWeb) return s; // SpeechSynthesisUtterance.rate (1 = normal)
    switch (platform ?? defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _interpolate(_appleSpeeds, _appleRates, s);
      case TargetPlatform.windows:
        // WinRT SpeakingRate = rate + 0.5 (1 = normal)
        return s - 0.5;
      case TargetPlatform.android:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return androidBase * s;
    }
  }

  static double _interpolate(List<double> xs, List<double> ys, double x) {
    if (x <= xs.first) return ys.first;
    if (x >= xs.last) return ys.last;
    for (var i = 0; i < xs.length - 1; i++) {
      if (x >= xs[i] && x <= xs[i + 1]) {
        final t = (x - xs[i]) / (xs[i + 1] - xs[i]);
        return ys[i] + (ys[i + 1] - ys[i]) * t;
      }
    }
    return ys.last;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MOTOR (inyectable para tests)
// ═══════════════════════════════════════════════════════════════════════════

/// Abstracción del motor de voz. La implementación real envuelve FlutterTts;
/// los tests inyectan uno falso con [BibleTtsService.forTesting].
abstract class BibleTtsEngine {
  /// Se llama al terminar de decir cada texto.
  set onComplete(VoidCallback? callback);

  /// Se llama si el motor reporta un error al decir un texto.
  set onError(void Function(String message)? callback);

  /// Empieza a decir [text]; `true` si el motor lo aceptó.
  Future<bool> speak(String text);
  Future<void> stop();
  Future<void> setSpeechRate(double rate);

  /// `true` si el idioma está disponible.
  Future<bool> setLanguage(String locale);
  Future<bool> setVoice(TtsVoice voice);

  /// Voces disponibles; lista vacía si la plataforma no las informa.
  Future<List<TtsVoice>> getVoices();
}

/// Motor real sobre flutter_tts. Tolera plataformas sin plugin (tests,
/// escritorio): en ese caso todo devuelve «no disponible» sin lanzar.
class FlutterTtsEngine implements BibleTtsEngine {
  FlutterTts? _tts;
  VoidCallback? _onComplete;
  void Function(String)? _onError;

  FlutterTts get _engine {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = FlutterTts();
    tts.setCompletionHandler(() => _onComplete?.call());
    tts.setCancelHandler(() {
      // No avanzar aquí: stop() ya maneja el estado vía generación.
    });
    tts.setErrorHandler((msg) => _onError?.call('$msg'));
    unawaited(_safe(() => tts.setPitch(1.0)));
    unawaited(_safe(() => tts.setVolume(1.0)));
    return _tts = tts;
  }

  static Future<Object?> _safe(Future<Object?> Function() op) async {
    try {
      return await op();
    } catch (e) {
      debugPrint('🗣️ [TTS] $e');
      return null;
    }
  }

  static bool _ok(Object? r) => r == 1 || r == true;

  @override
  set onComplete(VoidCallback? callback) => _onComplete = callback;

  @override
  set onError(void Function(String message)? callback) => _onError = callback;

  @override
  Future<bool> speak(String text) async =>
      _ok(await _safe(() => _engine.speak(text)));

  @override
  Future<void> stop() async => _safe(() => _engine.stop());

  @override
  Future<void> setSpeechRate(double rate) async =>
      _safe(() => _engine.setSpeechRate(rate));

  @override
  Future<bool> setLanguage(String locale) async =>
      _ok(await _safe(() => _engine.setLanguage(locale)));

  @override
  Future<bool> setVoice(TtsVoice voice) async =>
      _ok(await _safe(() => _engine.setVoice(voice.toEngineMap())));

  @override
  Future<List<TtsVoice>> getVoices() async {
    final raw = await _safe(() async => await _engine.getVoices);
    if (raw is! List) return const [];
    return raw.map(TtsVoice.fromMap).whereType<TtsVoice>().toList();
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE TTS SERVICE — Lee un capítulo verso por verso con tracking.
///
/// Emite el índice del versículo que se está leyendo para highlighting.
/// Usa su propio motor para no interferir con el AudioService general.
///
/// Ciclo de vida:
/// - [startReading]/[startReadingQueue] → lee item por item.
/// - Al terminar la cola (o al fallar el motor) se emite [onQueueEnded] con
///   el motivo, [isPlaying] pasa a false y [currentVerseIndex] a -1.
/// - [stop] limpia todo sin emitir [onQueueEnded] (lo pidió el usuario o
///   cambió el capítulo).
/// ═══════════════════════════════════════════════════════════════════════════
class BibleTtsService {
  static final BibleTtsService _instance = BibleTtsService._internal(
    FlutterTtsEngine(),
    BibleAudioSettings.I,
  );
  factory BibleTtsService() => _instance;
  static BibleTtsService get I => _instance;
  BibleTtsService._internal(this._engine, this._settings)
    : _platformOverride = null,
      _pauseBgm = true;

  /// Instancia aislada con motor falso. Pasar `BibleAudioSettings.forTesting()`
  /// en [settings] para no compartir ajustes con el singleton.
  @visibleForTesting
  BibleTtsService.forTesting(
    BibleTtsEngine engine, {
    BibleAudioSettings? settings,
    TargetPlatform? platform,
  }) : _engine = engine,
       _settings = settings ?? BibleAudioSettings.I,
       _platformOverride = platform,
       _pauseBgm = false;

  /// Cambia el motor (tests). Reinicia la configuración.
  @visibleForTesting
  set engine(BibleTtsEngine engine) {
    _engine = engine;
    _initialized = false;
    _voices = null;
    _appliedVoiceKey = null;
  }

  BibleTtsEngine _engine;
  final BibleAudioSettings _settings;
  final TargetPlatform? _platformOverride;
  final bool _pauseBgm;
  bool _initialized = false;
  bool _listening = false;

  List<TtsQueueItem> _queue = [];
  int _queueIndex = -1;
  bool _playing = false;
  bool _paused = false;
  BibleLanguage _language = BibleLanguage.spanish;
  double _speed = 1.0;

  /// Generación de lectura: se incrementa en cada stop/start para cancelar
  /// cualquier _readCurrent() en vuelo que pertenezca a una sesión anterior.
  int _generation = 0;
  int _speakingGen = 0;

  /// Errores seguidos del motor y textos leídos con éxito en la sesión.
  int _consecutiveErrors = 0;
  int _spokenCount = 0;
  static const _maxConsecutiveErrors = 3;

  /// Voces del motor (cache) y la voz aplicada.
  List<TtsVoice>? _voices;
  String? _appliedVoiceKey;

  /// Índice del versículo que se está leyendo (-1 si no hay nada)
  final ValueNotifier<int> currentVerseIndex = ValueNotifier(-1);

  /// Si está leyendo
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);

  /// Voz en uso (null si la plataforma no informa voces).
  final ValueNotifier<TtsVoice?> activeVoice = ValueNotifier(null);

  /// Modo de lectura actual
  final ValueNotifier<TtsReadMode> readMode = ValueNotifier(
    TtsReadMode.verseOnly,
  );

  final StreamController<TtsEndReason> _ended =
      StreamController<TtsEndReason>.broadcast();

  /// Se emite cuando la cola termina sola (completa o por error del motor).
  Stream<TtsEndReason> get onQueueEnded => _ended.stream;

  /// Hay una sesión (leyendo o en pausa).
  bool get hasSession => _playing || _paused;

  /// En pausa.
  bool get isPaused => _paused;

  /// Velocidad aplicada (0.75–2x).
  double get speed => _speed;

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    _engine.onComplete = () => _onItemComplete(_speakingGen, success: true);
    _engine.onError = (msg) {
      debugPrint('🗣️ [TTS] error: $msg');
      if (_playing) _onItemError(_speakingGen);
    };
    await _settings.ensureLoaded();
    if (!_listening) {
      _listening = true;
      _settings.speed.addListener(_onSpeedSetting);
      _settings.voiceSpanish.addListener(_onVoiceSetting);
      _settings.voiceEnglish.addListener(_onVoiceSetting);
    }
    _speed = _settings.speed.value;
    await _engine.setSpeechRate(_rateFor(_speed));
    await _applyLanguage(_language, force: true);
  }

  double _rateFor(double speed) =>
      BibleTtsRate.forSpeed(speed, platform: _platformOverride);

  /// Iniciar lectura desde un índice específico (modo solo versículos)
  Future<void> startReading(
    List<BibleVerse> verses, {
    int fromIndex = 0,
  }) async {
    final safeFromIndex = fromIndex < 0
        ? 0
        : fromIndex > verses.length
        ? verses.length
        : fromIndex;
    final queue = <TtsQueueItem>[];
    for (int i = safeFromIndex; i < verses.length; i++) {
      queue.add(TtsQueueItem(verses[i].text.trim(), i));
    }
    final hasValidStart = safeFromIndex < verses.length;
    final language = !hasValidStart
        ? BibleLanguage.spanish
        : BibleVersion.fromId(verses[safeFromIndex].version).language;
    await startReadingQueue(
      queue,
      mode: TtsReadMode.verseOnly,
      language: language,
    );
  }

  /// Iniciar lectura con cola personalizada y modo
  Future<void> startReadingQueue(
    List<TtsQueueItem> queue, {
    TtsReadMode mode = TtsReadMode.verseOnly,
    BibleLanguage language = BibleLanguage.spanish,
  }) async {
    // Detener BGM al activar TTS
    if (_pauseBgm) {
      final engine = AudioEngine.I;
      if (engine.bgmState.value == BgmPlaybackState.playing) {
        await engine.pauseBgm();
      }
    }

    await _init();
    await stop();
    await _applyLanguage(language);
    _queue = queue;
    _queueIndex = 0;
    _consecutiveErrors = 0;
    _spokenCount = 0;
    readMode.value = mode;
    _playing = true;
    _paused = false;
    isPlaying.value = true;
    final gen = ++_generation;
    await _readCurrent(gen);
  }

  /// Aplica idioma y voz (la elegida por el usuario o la mejor disponible).
  Future<void> _applyLanguage(
    BibleLanguage language, {
    bool force = false,
  }) async {
    final preferred = _settings.voiceFor(language);
    final key = '${language.code}|${preferred?.name}|${preferred?.locale}';
    if (!force && key == _appliedVoiceKey) return;
    _language = language;
    _appliedVoiceKey = key;

    final voice = BibleVoicePicker.pick(
      await _loadVoices(),
      language,
      preferred: preferred,
    );
    if (voice != null) {
      await _engine.setLanguage(voice.locale);
      final ok = await _engine.setVoice(voice);
      if (ok) {
        activeVoice.value = voice;
        debugPrint('🗣️ [TTS] voz: ${voice.name} (${voice.locale})');
        return;
      }
    }
    activeVoice.value = null;
    final fallbacks = language == BibleLanguage.english
        ? const ['en-US', 'en-GB']
        : const ['es-MX', 'es-US', 'es-ES'];
    for (final locale in fallbacks) {
      if (await _engine.setLanguage(locale)) return;
      debugPrint('🗣️ [TTS] $locale no disponible');
    }
  }

  Future<List<TtsVoice>> _loadVoices() async {
    final cached = _voices;
    if (cached != null) return cached;
    List<TtsVoice> voices;
    try {
      voices = await _engine.getVoices();
    } catch (e) {
      debugPrint('🗣️ [TTS] getVoices falló: $e');
      voices = const [];
    }
    // No cachear una lista vacía: el motor puede no estar listo aún.
    if (voices.isNotEmpty) _voices = voices;
    return voices;
  }

  /// Voces disponibles para [language], de mejor a peor (para ajustes).
  /// Lista vacía si la plataforma no informa voces.
  Future<List<TtsVoice>> voicesFor(BibleLanguage language) async {
    await _init();
    return BibleVoicePicker.rank(await _loadVoices(), language);
  }

  /// Dice una frase de muestra con [voice] (o la automática si es `null`).
  /// No hace nada si hay una lectura en curso.
  Future<void> previewVoice(TtsVoice? voice, BibleLanguage language) async {
    if (hasSession) return;
    await _init();
    final picked =
        voice ?? BibleVoicePicker.pick(await _loadVoices(), language);
    if (picked != null) {
      await _engine.setLanguage(picked.locale);
      await _engine.setVoice(picked);
    }
    _appliedVoiceKey = null; // la próxima lectura vuelve a aplicar su voz
    await _engine.stop();
    await _engine.speak(
      language == BibleLanguage.english
          ? 'The Lord is my shepherd; I shall not want.'
          : 'Jehová es mi pastor; nada me faltará.',
    );
  }

  Future<void> _readCurrent(int gen) async {
    if (gen != _generation) return; // sesión cancelada
    if (!_playing) return;
    if (_queueIndex >= _queue.length || _queueIndex < 0) {
      await _finish(gen);
      return;
    }
    final item = _queue[_queueIndex];
    currentVerseIndex.value = item.verseIndex;

    // Saltar items con texto vacío
    if (item.text.trim().isEmpty) {
      _advance(gen);
      return;
    }

    _speakingGen = gen;
    final ok = await _engine.speak(item.text);
    if (gen != _generation) return; // cancelado mientras speak ejecutaba
    if (!ok) {
      // speak falló (texto muy largo, error engine, etc.)
      _onItemError(gen);
    }
  }

  void _onItemComplete(int gen, {required bool success}) {
    if (gen != _generation || !_playing) return; // sesión obsoleta
    if (success) {
      _consecutiveErrors = 0;
      _spokenCount++;
    }
    _advance(gen);
  }

  void _onItemError(int gen) {
    if (gen != _generation || !_playing) return;
    _consecutiveErrors++;
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      debugPrint('🗣️ [TTS] demasiados errores seguidos; se detiene');
      unawaited(_finish(gen, reason: TtsEndReason.error));
      return;
    }
    _advance(gen); // saltar al siguiente item
  }

  void _advance(int gen) {
    if (gen != _generation || !_playing) return;
    _queueIndex++;
    if (_queueIndex >= _queue.length) {
      unawaited(_finish(gen));
      return;
    }
    unawaited(_readCurrent(gen)); // protegido por generation
  }

  /// La cola terminó sola: limpia y avisa a quien escuche.
  Future<void> _finish(int gen, {TtsEndReason? reason}) async {
    if (gen != _generation) return;
    final why =
        reason ??
        (_spokenCount > 0 ? TtsEndReason.completed : TtsEndReason.error);
    await stop();
    if (!_ended.isClosed) _ended.add(why);
  }

  /// Pausar lectura. Se detiene el motor (pause() no es confiable en todos
  /// los dispositivos) y al reanudar se relee el item actual.
  Future<void> pause() async {
    if (!_playing) return;
    _generation++; // ignora la finalización del item interrumpido
    _paused = true;
    _playing = false;
    isPlaying.value = false;
    await _engine.stop();
  }

  /// Reanudar lectura
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    _playing = true;
    isPlaying.value = true;
    final gen = ++_generation;
    await _readCurrent(gen);
  }

  /// Detener lectura (sin emitir [onQueueEnded]).
  Future<void> stop() async {
    final wasIdle = !_playing && !_paused && _queue.isEmpty;
    _generation++; // invalida cualquier _readCurrent en vuelo
    _playing = false;
    _paused = false;
    _queueIndex = -1;
    _queue = [];
    isPlaying.value = false;
    currentVerseIndex.value = -1;
    readMode.value = TtsReadMode.verseOnly;
    if (!wasIdle) await _engine.stop();
  }

  /// Cambia la velocidad (0.75–2x) en vivo: relee el item actual.
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    if (!_initialized) return; // se aplica en _init
    await _engine.setSpeechRate(_rateFor(speed));
    await _respeakCurrent();
  }

  void _onSpeedSetting() {
    if (_settings.speed.value != _speed) {
      unawaited(setSpeed(_settings.speed.value));
    }
  }

  void _onVoiceSetting() {
    unawaited(() async {
      await _applyLanguage(_language);
      await _respeakCurrent();
    }());
  }

  Future<void> _respeakCurrent() async {
    if (!_playing) return;
    final gen = ++_generation;
    await _engine.stop();
    await _readCurrent(gen);
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
    if (_listening) {
      _listening = false;
      _settings.speed.removeListener(_onSpeedSetting);
      _settings.voiceSpanish.removeListener(_onVoiceSetting);
      _settings.voiceEnglish.removeListener(_onVoiceSetting);
    }
    // El singleton vive toda la app; las instancias de test cierran su stream.
    if (!identical(this, _instance)) await _ended.close();
  }
}
