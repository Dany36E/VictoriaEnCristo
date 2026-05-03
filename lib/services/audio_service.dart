import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_pref_cloud_sync_service.dart';

/// Estado del reproductor TTS
enum TtsState { playing, stopped, paused }

/// Servicio de Text-to-Speech para devocionales y versículos
class AudioService {
  static const String _audioEnabledKey = 'audio_enabled';
  static const String _audioSpeedKey = 'audio_speed';
  static const String _audioPitchKey = 'audio_pitch';

  // ═══════════════════════════════════════════════════════════════════════════
  // CALIBRACIÓN DE VELOCIDAD TTS
  // El valor 1.0 de flutter_tts es muy rápido. Mapeamos valores de UI
  // a valores reales más naturales para una lectura meditativa.
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convertir velocidad de UI a velocidad real del motor TTS
  /// UI: 0.75 → TTS: 0.35 (Muy pausado)
  /// UI: 1.0  → TTS: 0.45 (Conversación calmada)
  /// UI: 1.25 → TTS: 0.55 (Lectura fluida)
  /// UI: 1.5  → TTS: 0.65 (Aún comprensible)
  double _mapSpeedToTts(double uiSpeed) {
    if (uiSpeed <= 0.75) return 0.35;
    if (uiSpeed <= 1.0) return 0.45;
    if (uiSpeed <= 1.25) return 0.55;
    return 0.65;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRE-PROCESAMIENTO DE TEXTO BÍBLICO (NLP)
  // Sanitiza el texto para que el TTS lea correctamente las referencias
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mapa de libros numerados a su forma hablada
  static const Map<String, String> _numberedBooks = {
    '1 Corintios': 'Primera de Corintios',
    '2 Corintios': 'Segunda de Corintios',
    '1 Tesalonicenses': 'Primera de Tesalonicenses',
    '2 Tesalonicenses': 'Segunda de Tesalonicenses',
    '1 Timoteo': 'Primera de Timoteo',
    '2 Timoteo': 'Segunda de Timoteo',
    '1 Pedro': 'Primera de Pedro',
    '2 Pedro': 'Segunda de Pedro',
    '1 Juan': 'Primera de Juan',
    '2 Juan': 'Segunda de Juan',
    '3 Juan': 'Tercera de Juan',
    '1 Reyes': 'Primer libro de Reyes',
    '2 Reyes': 'Segundo libro de Reyes',
    '1 Samuel': 'Primer libro de Samuel',
    '2 Samuel': 'Segundo libro de Samuel',
    '1 Crónicas': 'Primer libro de Crónicas',
    '2 Crónicas': 'Segundo libro de Crónicas',
  };

  /// Sanitiza el texto para lectura TTS natural
  /// Convierte "1 Corintios 10:13" → "Primera de Corintios, capítulo diez, versículo trece"
  String sanitizeTextForTts(String text) {
    String result = text;

    // 1. Reemplazar libros numerados por su forma hablada
    _numberedBooks.forEach((numbered, spoken) {
      result = result.replaceAll(numbered, spoken);
    });

    // 2. Detectar patrón de capítulo:versículo (ej. "10:13", "3:16")
    // Regex: uno o más dígitos, seguido de dos puntos, seguido de uno o más dígitos
    final versePattern = RegExp(r'(\d+):(\d+)');
    result = result.replaceAllMapped(versePattern, (match) {
      final chapter = match.group(1);
      final verse = match.group(2);
      return 'capítulo $chapter, versículo $verse';
    });

    // 3. Limpiar caracteres problemáticos
    result = result
        .replaceAll('—', ', ') // Guión largo
        .replaceAll('–', ', ') // Guión medio
        .replaceAll('"', '') // Comillas dobles
        .replaceAll('"', '') // Comillas tipográficas
        .replaceAll('"', '') // Comillas tipográficas
        .replaceAll('«', '') // Comillas españolas
        .replaceAll('»', ''); // Comillas españolas

    // 4. Añadir pausas naturales después de puntos
    result = result.replaceAll('. ', '... ');

    return result;
  }

  // Singleton
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Flutter TTS instance
  FlutterTts? _flutterTts;
  bool _ttsInitialized = false;
  bool _ttsAvailable = true;

  // Estado
  TtsState _ttsState = TtsState.stopped;
  bool _audioEnabled = true;
  double _audioSpeed = 1.0;
  double _audioPitch = 1.0;
  String? _currentlyPlaying;
  String? _pendingText; // Texto pendiente para reanudar

  // Stream controller para notificar cambios de estado
  final _stateController = StreamController<TtsState>.broadcast();
  Stream<TtsState> get stateStream => _stateController.stream;

  // Getters
  bool get isPlaying => _ttsState == TtsState.playing;
  bool get isPaused => _ttsState == TtsState.paused;
  bool get isStopped => _ttsState == TtsState.stopped;
  TtsState get state => _ttsState;
  bool get audioEnabled => _audioEnabled;
  bool get ttsAvailable => _ttsAvailable;
  double get audioSpeed => _audioSpeed;
  double get audioPitch => _audioPitch;
  String? get currentlyPlaying => _currentlyPlaying;

  /// Inicializar servicio TTS
  Future<void> initialize() async {
    await _loadSettings();
    try {
      await _initTts();
    } on MissingPluginException catch (e) {
      _ttsAvailable = false;
      debugPrint('TTS unavailable: $e');
    } catch (e) {
      _ttsAvailable = false;
      debugPrint('TTS init error: $e');
    }
  }

  /// Inicializar Flutter TTS
  Future<void> _initTts() async {
    if (_ttsInitialized || !_ttsAvailable) return;

    _flutterTts = FlutterTts();

    // Configurar idioma español latinoamericano (México como predeterminado)
    // Intentar primero es-MX (México), luego es-US (Estados Unidos), fallback es-ES
    try {
      await _flutterTts!.setLanguage('es-MX');
    } catch (e) {
      try {
        await _flutterTts!.setLanguage('es-US');
      } catch (e2) {
        await _flutterTts!.setLanguage('es-ES');
      }
    }
    // Usar velocidad calibrada, no el valor raw
    await _flutterTts!.setSpeechRate(_mapSpeedToTts(_audioSpeed));
    await _flutterTts!.setPitch(_audioPitch);
    await _flutterTts!.setVolume(1.0);

    // Listeners de estado
    _flutterTts!.setStartHandler(() {
      _ttsState = TtsState.playing;
      _stateController.add(_ttsState);
    });

    _flutterTts!.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      _currentlyPlaying = null;
      _pendingText = null;
      _stateController.add(_ttsState);
    });

    _flutterTts!.setCancelHandler(() {
      _ttsState = TtsState.stopped;
      _stateController.add(_ttsState);
    });

    _flutterTts!.setPauseHandler(() {
      _ttsState = TtsState.paused;
      _stateController.add(_ttsState);
    });

    _flutterTts!.setContinueHandler(() {
      _ttsState = TtsState.playing;
      _stateController.add(_ttsState);
    });

    _flutterTts!.setErrorHandler((msg) {
      debugPrint('TTS Error: $msg');
      _ttsState = TtsState.stopped;
      _stateController.add(_ttsState);
    });

    _ttsInitialized = true;
  }

  /// Cargar configuración desde SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _audioEnabled = prefs.getBool(_audioEnabledKey) ?? true;
    _audioSpeed = prefs.getDouble(_audioSpeedKey) ?? 1.0;
    _audioPitch = prefs.getDouble(_audioPitchKey) ?? 1.0;
  }

  /// Guardar configuración
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_audioEnabledKey, _audioEnabled);
    await prefs.setDouble(_audioSpeedKey, _audioSpeed);
    await prefs.setDouble(_audioPitchKey, _audioPitch);
    UserPrefCloudSyncService.I.markDirty();
  }

  /// Habilitar/deshabilitar audio
  Future<void> setAudioEnabled(bool enabled) async {
    _audioEnabled = enabled;
    await _saveSettings();
    if (!enabled && isPlaying) {
      await stop();
    }
  }

  /// Cambiar velocidad de reproducción (valores de UI: 0.75, 1.0, 1.25, 1.5)
  Future<void> setAudioSpeed(double speed) async {
    _audioSpeed = speed.clamp(0.5, 2.0);
    await _saveSettings();
    if (_ttsInitialized) {
      // Aplicar velocidad calibrada al motor TTS
      await _flutterTts!.setSpeechRate(_mapSpeedToTts(_audioSpeed));
    }
  }

  /// Cambiar tono de voz (0.5 - 2.0)
  Future<void> setAudioPitch(double pitch) async {
    _audioPitch = pitch.clamp(0.5, 2.0);
    await _saveSettings();
    if (_ttsInitialized) {
      await _flutterTts!.setPitch(_audioPitch);
    }
  }

  /// Reproducir texto genérico (con sanitización automática)
  Future<void> speak(String text, {String? label}) async {
    if (!_audioEnabled || !_ttsAvailable) return;
    if (!_ttsInitialized) {
      try {
        await _initTts();
      } on MissingPluginException catch (e) {
        _ttsAvailable = false;
        debugPrint('TTS unavailable: $e');
        return;
      } catch (e) {
        _ttsAvailable = false;
        debugPrint('TTS speak init error: $e');
        return;
      }
    }

    // Detener cualquier reproducción actual
    await stop();

    // Sanitizar texto para lectura natural de citas bíblicas
    final sanitizedText = sanitizeTextForTts(text);

    _currentlyPlaying = label ?? 'Texto';
    _pendingText = sanitizedText;
    _ttsState = TtsState.playing;
    _stateController.add(_ttsState);

    await _flutterTts!.speak(sanitizedText);
  }

  /// Reproducir devocional completo (título, versículo, reflexión, oración)
  Future<void> playDevotional({
    required String title,
    required String verse,
    required String reflection,
    required String prayer,
  }) async {
    if (!_audioEnabled) return;

    // Construir texto completo con pausas naturales
    final fullText =
        '''
$title.

Versículo: $verse.

Reflexión: $reflection.

Oración: $prayer.
''';

    await speak(fullText, label: title);
  }

  /// Reproducir versículo individual
  Future<void> playVerse(String reference, String verseText) async {
    if (!_audioEnabled) return;

    final text = '$verseText. $reference.';
    await speak(text, label: reference);
  }

  /// Reproducir oración
  Future<void> playPrayer(String prayerTitle, String prayerContent) async {
    if (!_audioEnabled) return;

    final text = '$prayerTitle. $prayerContent';
    await speak(text, label: prayerTitle);
  }

  /// Pausar reproducción
  Future<void> pause() async {
    if (!_ttsInitialized || !isPlaying) return;
    await _flutterTts!.pause();
    _ttsState = TtsState.paused;
    _stateController.add(_ttsState);
  }

  /// Reanudar reproducción (usa API nativa de Android/iOS)
  Future<void> resume() async {
    if (!_ttsInitialized || _ttsState != TtsState.paused) return;

    // Intentar usar el resume nativo primero
    try {
      await _flutterTts!.speak(_pendingText ?? '');
      _ttsState = TtsState.playing;
      _stateController.add(_ttsState);
    } catch (e) {
      debugPrint('TTS resume error: $e');
      // Fallback: si falla, reiniciar desde el principio
      if (_pendingText != null) {
        await speak(_pendingText!, label: _currentlyPlaying);
      }
    }
  }

  /// Detener reproducción
  Future<void> stop() async {
    if (!_ttsInitialized) return;
    await _flutterTts!.stop();
    _ttsState = TtsState.stopped;
    _currentlyPlaying = null;
    _pendingText = null;
    _stateController.add(_ttsState);
  }

  /// Toggle play/pause
  Future<void> togglePlayPause(String text, {String? label}) async {
    if (isPlaying) {
      await pause();
    } else if (isPaused) {
      await resume();
    } else {
      await speak(text, label: label);
    }
  }

  /// Obtener duración estimada de lectura
  Duration getEstimatedDuration(String text) {
    final wordCount = text.split(' ').length;
    final wordsPerMinute = 150 * _audioSpeed;
    final minutes = wordCount / wordsPerMinute;
    return Duration(seconds: (minutes * 60).round());
  }

  /// Limpiar recursos
  void dispose() {
    _flutterTts?.stop();
    _stateController.close();
  }
}
