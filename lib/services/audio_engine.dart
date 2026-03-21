import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AUDIO ENGINE v2.0 - Sistema Determinístico de Audio
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ARQUITECTURA:
/// - UN motor central (singleton real)
/// - BGM y SFX TOTALMENTE independientes
/// - UI observa estado REAL (no prefs)
/// - Pausar/Continuar SIEMPRE funcionan
/// 
/// REGLAS:
/// 1) bgmState es la ÚNICA fuente de verdad para UI
/// 2) pauseBgm() SOLO si state == playing
/// 3) resumeBgm() SOLO si state == paused
/// 4) startBgm() carga asset si state == stopped
/// 5) NUNCA usar resume() sin play() previo
/// 6) SFX usa player separado, no afecta BGM
/// ═══════════════════════════════════════════════════════════════════════════

/// Estados del BGM (máquina de estados estricta)
enum BgmPlaybackState {
  stopped,   // No hay reproducción, no hay asset cargado
  loading,   // Cargando asset
  playing,   // Reproduciendo activamente
  paused,    // Pausado (asset cargado, se puede resumir)
  error,     // Error en la reproducción
}

class AudioEngine {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON REAL
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final AudioEngine _instance = AudioEngine._internal();
  static AudioEngine get I => _instance;
  static AudioEngine get instance => _instance;
  factory AudioEngine() => _instance;
  
  /// ID de sesión para logs
  late final String _sessionId;
  
  AudioEngine._internal() {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    _log('ENGINE', '════════════════════════════════════════════════════════');
    _log('ENGINE', 'Created - hashCode: $hashCode, sessionId: $_sessionId');
    _log('ENGINE', '════════════════════════════════════════════════════════');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLAYERS SEPARADOS (crítico: independientes)
  // ═══════════════════════════════════════════════════════════════════════════
  
  AudioPlayer? _bgmPlayer;   // SOLO para música de fondo
  AudioPlayer? _sfxPlayer;   // SOLO para efectos de sonido
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADOS OBSERVABLES (UI escucha estos ValueNotifiers)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Estado actual del BGM - LA ÚNICA FUENTE DE VERDAD PARA UI
  final ValueNotifier<BgmPlaybackState> bgmState = ValueNotifier(BgmPlaybackState.stopped);
  
  /// ¿Está habilitado el BGM? (solo indica preferencia del usuario)
  final ValueNotifier<bool> bgmEnabled = ValueNotifier(true);
  
  /// ¿Están habilitados los SFX?
  final ValueNotifier<bool> sfxEnabled = ValueNotifier(true);
  
  /// Volumen BGM [0.0 - 1.0]
  final ValueNotifier<double> bgmVolume = ValueNotifier(0.5);
  
  /// Volumen SFX [0.0 - 1.0]
  final ValueNotifier<double> sfxVolume = ValueNotifier(0.7);
  
  /// ¿BGM está muteado? (volumen 0 pero sigue reproduciendo)
  final ValueNotifier<bool> bgmMuted = ValueNotifier(false);
  
  /// Volumen antes de mutear (para restaurar)
  double _volumeBeforeMute = 0.5;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CONTROL INTERNO
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Mutex para serializar operaciones BGM
  Completer<void>? _bgmOpLock;
  
  /// Token de cancelación para operaciones en progreso
  int _bgmOpToken = 0;
  
  /// Asset actualmente cargado
  String? _currentBgmAsset;
  
  /// ¿Ya inicializado?
  bool _isInitialized = false;
  
  /// Último error
  String? _lastError;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ASSETS BGM - ORDEN DE PRIORIDAD
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Assets en orden de preferencia:
  /// 1. worship_pad.mp3 (el del usuario si existe)
  /// 2. Worship_pads.mp3 (principal largo)
  /// 3. Worship_pads2.mp3 (alternativo)
  /// 4. test_song.mp3 (fallback)
  static const List<String> _bgmCandidates = [
    'assets/sounds/worship_pad.mp3',    // El del usuario
    'assets/sounds/Worship_pads.mp3',   // Principal largo
    'assets/sounds/Worship_pads2.mp3',  // Alternativo
    'assets/sounds/test_song.mp3',      // Fallback
  ];
  
  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS PÚBLICOS
  // ═══════════════════════════════════════════════════════════════════════════
  
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  String? get currentBgmAsset => _currentBgmAsset;
  Duration get bgmPosition => _bgmPlayer?.position ?? Duration.zero;
  Duration get bgmDuration => _bgmPlayer?.duration ?? Duration.zero;
  bool get isBgmActuallyPlaying => _bgmPlayer?.playing ?? false;
  int get bgmPlayerHash => _bgmPlayer?.hashCode ?? 0;
  int get sfxPlayerHash => _sfxPlayer?.hashCode ?? 0;

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> init() async {
    if (_isInitialized) {
      _log('INIT', 'Already initialized - skipping');
      return;
    }
    
    _log('INIT', '════════════════════════════════════════════════════════');
    _log('INIT', 'START');
    _log('INIT', '════════════════════════════════════════════════════════');
    
    try {
      // ─────────────────────────────────────────────────────────────────────
      // 1) AUDIO SESSION (Android)
      // ─────────────────────────────────────────────────────────────────────
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      _log('INIT', 'AudioSession configured ✓');
      
      // ─────────────────────────────────────────────────────────────────────
      // 2) CREAR PLAYERS SEPARADOS
      // ─────────────────────────────────────────────────────────────────────
      _bgmPlayer = AudioPlayer();
      _sfxPlayer = AudioPlayer();
      
      _log('INIT', 'Players created:');
      _log('INIT', '  BGM: ${_bgmPlayer.hashCode}');
      _log('INIT', '  SFX: ${_sfxPlayer.hashCode}');
      
      // ─────────────────────────────────────────────────────────────────────
      // 3) CONFIGURAR BGM (loop infinito)
      // ─────────────────────────────────────────────────────────────────────
      await _bgmPlayer!.setLoopMode(LoopMode.all);
      
      // ─────────────────────────────────────────────────────────────────────
      // 4) CONFIGURAR SFX (sin loop)
      // ─────────────────────────────────────────────────────────────────────
      await _sfxPlayer!.setLoopMode(LoopMode.off);
      
      // ─────────────────────────────────────────────────────────────────────
      // 5) CARGAR PREFERENCIAS
      // ─────────────────────────────────────────────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      bgmEnabled.value = prefs.getBool('audio_bgm_enabled') ?? true;
      sfxEnabled.value = prefs.getBool('audio_sfx_enabled') ?? true;
      bgmVolume.value = prefs.getDouble('audio_bgm_volume') ?? 0.5;
      sfxVolume.value = prefs.getDouble('audio_sfx_volume') ?? 0.7;
      
      await _bgmPlayer!.setVolume(bgmVolume.value);
      await _sfxPlayer!.setVolume(sfxVolume.value);
      
      _log('INIT', 'Preferences loaded:');
      _log('INIT', '  BGM: enabled=${bgmEnabled.value}, vol=${bgmVolume.value}');
      _log('INIT', '  SFX: enabled=${sfxEnabled.value}, vol=${sfxVolume.value}');
      
      _isInitialized = true;
      _lastError = null;
      
      _log('INIT', '════════════════════════════════════════════════════════');
      _log('INIT', 'COMPLETE ✓');
      _log('INIT', '════════════════════════════════════════════════════════');
      
    } catch (e) {
      _lastError = 'Init failed: $e';
      _isInitialized = true; // Para no reintentar infinito
      _log('INIT', '❌ FAILED: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MUTEX - Serializar operaciones BGM
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<T> _runBgmOp<T>(String opName, Future<T> Function() operation) async {
    if (_bgmOpLock != null && !_bgmOpLock!.isCompleted) {
      _log('MUTEX', '⏳ Waiting: $opName');
      await _bgmOpLock!.future;
    }
    
    _bgmOpLock = Completer<void>();
    _log('MUTEX', '🔒 Acquired: $opName');
    
    try {
      final result = await operation();
      return result;
    } finally {
      _log('MUTEX', '🔓 Released: $opName');
      _bgmOpLock!.complete();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BGM - API PÚBLICA
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Activa/desactiva BGM (persiste y ejecuta)
  Future<bool> setBgmEnabled(bool enabled) async {
    _log('BGM', '════════════════════════════════════════════════════════');
    _log('BGM', 'setBgmEnabled($enabled)');
    _log('BGM', '════════════════════════════════════════════════════════');
    
    bgmEnabled.value = enabled;
    
    // Persistir
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('audio_bgm_enabled', enabled);
    } catch (e) {
      _log('BGM', '⚠️ Pref error: $e');
    }
    
    if (enabled) {
      return await startBgm();
    } else {
      // IMPORTANTE: Incrementar token para cancelar operaciones en progreso
      _bgmOpToken++;
      _log('BGM', '⏹️ Disabling BGM - stopping directly (token: $_bgmOpToken)');
      await _bgmPlayer?.stop();
      _currentBgmAsset = null;
      bgmState.value = BgmPlaybackState.stopped;
      _log('BGM', '✓ BGM disabled and stopped');
      return true;
    }
  }
  
  /// INICIAR BGM (carga asset si no hay uno cargado)
  /// Solo llama esto cuando state == stopped
  Future<bool> startBgm() async {
    // Capturar token actual para detectar cancelaciones
    final myToken = _bgmOpToken;
    
    return await _runBgmOp('startBgm', () async {
      _log('BGM', '▶️ startBgm() | state: ${bgmState.value} | token: $myToken');
      
      // Verificar si fue cancelado antes de empezar
      if (myToken != _bgmOpToken) {
        _log('BGM', '⚠️ Cancelled (token mismatch: $myToken != $_bgmOpToken)');
        return false;
      }
      
      if (!_isInitialized || _bgmPlayer == null) {
        _lastError = 'Not initialized';
        _log('BGM', '❌ Not initialized');
        return false;
      }
      
      if (!bgmEnabled.value) {
        _log('BGM', '⏸️ BGM disabled - not starting');
        return false;
      }
      
      // Si ya está playing, no hacer nada
      if (bgmState.value == BgmPlaybackState.playing) {
        _log('BGM', '✓ Already playing');
        return true;
      }
      
      // Si está pausado, resumir
      if (bgmState.value == BgmPlaybackState.paused && _currentBgmAsset != null) {
        _log('BGM', '▶️ Resuming from pause');
        await _bgmPlayer!.play();
        bgmState.value = BgmPlaybackState.playing;
        _log('BGM', '✓ Resumed');
        return true;
      }
      
      // State es stopped o error → necesita cargar asset
      bgmState.value = BgmPlaybackState.loading;
      
      // Probar assets en orden
      for (final asset in _bgmCandidates) {
        // Verificar si se canceló (token cambió o disabled)
        if (myToken != _bgmOpToken || !bgmEnabled.value) {
          _log('BGM', '⚠️ Cancelled during loading loop');
          bgmState.value = BgmPlaybackState.stopped;
          return false;
        }
        
        _log('BGM', '────────────────────────────────────────────────');
        _log('BGM', 'Trying: $asset');
        
        try {
          // Stop antes de cargar nuevo
          await _bgmPlayer!.stop();
          
          // Verificar cancelación después de cada operación async
          if (myToken != _bgmOpToken || !bgmEnabled.value) {
            _log('BGM', '⚠️ Cancelled after stop');
            bgmState.value = BgmPlaybackState.stopped;
            return false;
          }
          
          // Volumen
          await _bgmPlayer!.setVolume(bgmVolume.value);
          
          // Cargar
          _log('BGM', '>>> setAsset <<<');
          final duration = await _bgmPlayer!.setAsset(asset);
          _log('BGM', '>>> setAsset OK: ${duration?.inSeconds}s <<<');
          
          // Verificar cancelación antes de play
          if (myToken != _bgmOpToken || !bgmEnabled.value) {
            _log('BGM', '⚠️ Cancelled before play');
            await _bgmPlayer!.stop();
            bgmState.value = BgmPlaybackState.stopped;
            return false;
          }
          
          // Reproducir
          _log('BGM', '>>> play() <<<');
          await _bgmPlayer!.play();
          _log('BGM', '>>> play() DONE <<<');
          
          // Verificar cancelación después de play
          if (myToken != _bgmOpToken || !bgmEnabled.value) {
            _log('BGM', '⚠️ Cancelled after play - stopping');
            await _bgmPlayer!.stop();
            bgmState.value = BgmPlaybackState.stopped;
            return false;
          }
          
          // Verificar que avanza
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Verificar cancelación después de delay
          if (myToken != _bgmOpToken || !bgmEnabled.value) {
            _log('BGM', '⚠️ Cancelled during verification');
            await _bgmPlayer!.stop();
            bgmState.value = BgmPlaybackState.stopped;
            return false;
          }
          
          final pos1 = _bgmPlayer!.position.inMilliseconds;
          await Future.delayed(const Duration(milliseconds: 300));
          final pos2 = _bgmPlayer!.position.inMilliseconds;
          
          final isPlaying = _bgmPlayer!.playing;
          final isAdvancing = pos2 > pos1;
          
          _log('BGM', 'Check: playing=$isPlaying, pos1=$pos1, pos2=$pos2, advancing=$isAdvancing');
          
          if (isPlaying) {
            // Última verificación antes de declarar éxito
            if (myToken != _bgmOpToken || !bgmEnabled.value) {
              _log('BGM', '⚠️ Cancelled at success - stopping');
              await _bgmPlayer!.stop();
              bgmState.value = BgmPlaybackState.stopped;
              return false;
            }
            
            _currentBgmAsset = asset;
            _lastError = null;
            bgmState.value = BgmPlaybackState.playing;
            _log('BGM', '✅ SUCCESS: $asset');
            return true;
          }
          
        } catch (e) {
          _log('BGM', '❌ Failed: $e');
        }
      }
      
      // Todos fallaron
      _lastError = 'All BGM assets failed';
      bgmState.value = BgmPlaybackState.error;
      _log('BGM', '❌ ALL ASSETS FAILED');
      return false;
    });
  }
  
  /// PAUSAR BGM
  /// ⚠️ SOLO funciona si state == playing
  Future<void> pauseBgm() async {
    await _runBgmOp('pauseBgm', () async {
      _log('BGM', '⏸️ pauseBgm() | state: ${bgmState.value}');
      
      // SOLO pausar si está playing
      if (bgmState.value != BgmPlaybackState.playing) {
        _log('BGM', '⚠️ Cannot pause - state is ${bgmState.value}, not playing');
        return;
      }
      
      await _bgmPlayer?.pause();
      bgmState.value = BgmPlaybackState.paused;
      _log('BGM', '✓ Paused | state: ${bgmState.value}');
    });
  }
  
  /// REANUDAR BGM
  /// ⚠️ SOLO funciona si state == paused
  Future<void> resumeBgm() async {
    await _runBgmOp('resumeBgm', () async {
      _log('BGM', '▶️ resumeBgm() | state: ${bgmState.value}');
      
      if (!bgmEnabled.value) {
        _log('BGM', '⚠️ BGM disabled - not resuming');
        return;
      }
      
      // SOLO resumir si está paused
      if (bgmState.value != BgmPlaybackState.paused) {
        _log('BGM', '⚠️ Cannot resume - state is ${bgmState.value}, not paused');
        return;
      }
      
      await _bgmPlayer?.play();
      bgmState.value = BgmPlaybackState.playing;
      _log('BGM', '✓ Resumed | state: ${bgmState.value}');
    });
  }
  
  /// DETENER BGM completamente (descarga asset)
  Future<void> stopBgm() async {
    await _runBgmOp('stopBgm', () async {
      _log('BGM', '⏹️ stopBgm() | state: ${bgmState.value}');
      
      await _bgmPlayer?.stop();
      _currentBgmAsset = null;
      bgmState.value = BgmPlaybackState.stopped;
      _log('BGM', '✓ Stopped | state: ${bgmState.value}');
    });
  }
  
  /// ═══════════════════════════════════════════════════════════════════════
  /// MUTE BGM (volumen 0 pero sigue reproduciendo)
  /// ═══════════════════════════════════════════════════════════════════════
  Future<void> muteBgm() async {
    if (bgmMuted.value) {
      _log('BGM', '⚠️ Already muted');
      return;
    }
    
    _volumeBeforeMute = bgmVolume.value;
    await _bgmPlayer?.setVolume(0.0);
    bgmMuted.value = true;
    _log('BGM', '🔇 Muted (was: $_volumeBeforeMute)');
  }
  
  /// ═══════════════════════════════════════════════════════════════════════
  /// UNMUTE BGM (restaura volumen previo)
  /// ═══════════════════════════════════════════════════════════════════════
  Future<void> unmuteBgm() async {
    if (!bgmMuted.value) {
      _log('BGM', '⚠️ Not muted');
      return;
    }
    
    await _bgmPlayer?.setVolume(_volumeBeforeMute);
    bgmVolume.value = _volumeBeforeMute;
    bgmMuted.value = false;
    _log('BGM', '🔊 Unmuted (restored: $_volumeBeforeMute)');
  }
  
  // ═══════════════════════════════════════════════════════════════════════
  // SCREEN MUTE — silencia BGM cuando el usuario sale de HomeScreen
  // ═══════════════════════════════════════════════════════════════════════
  bool _mutedByScreen = false;

  /// Silenciar BGM al navegar fuera de HomeScreen (no pausa, solo vol 0)
  Future<void> muteForScreen() async {
    if (_bgmPlayer != null) {
      await _bgmPlayer!.setVolume(0.0);
      _mutedByScreen = true;
      _log('BGM', '🔇 Muted by screen navigation');
    }
  }

  /// Restaurar volumen al volver a HomeScreen
  Future<void> unmuteForScreen() async {
    if (_mutedByScreen && bgmEnabled.value) {
      final vol = bgmMuted.value ? 0.0 : bgmVolume.value;
      await _bgmPlayer?.setVolume(vol);
      _mutedByScreen = false;
      _log('BGM', '🔊 Unmuted by screen navigation (vol: $vol)');
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// TOGGLE MUTE
  /// ═══════════════════════════════════════════════════════════════════════
  Future<void> toggleMuteBgm() async {
    if (bgmMuted.value) {
      await unmuteBgm();
    } else {
      await muteBgm();
    }
  }
  
  /// ═══════════════════════════════════════════════════════════════════════
  /// HARD STOP ALL AUDIO - KILL SWITCH 🛑
  /// Detiene TODO el audio inmediatamente, destruye players, reinicia estado
  /// ═══════════════════════════════════════════════════════════════════════
  Future<void> hardStopAllAudio() async {
    _log('KILL', '═══════════════════════════════════════════════════════');
    _log('KILL', '🛑 HARD STOP ALL AUDIO');
    _log('KILL', '═══════════════════════════════════════════════════════');
    
    // 1) Parar y disponer BGM
    try {
      await _bgmPlayer?.stop();
      await _bgmPlayer?.dispose();
      _log('KILL', '✓ BGM stopped & disposed');
    } catch (e) {
      _log('KILL', '⚠️ BGM dispose error: $e');
    }
    
    // 2) Parar y disponer SFX
    try {
      await _sfxPlayer?.stop();
      await _sfxPlayer?.dispose();
      _log('KILL', '✓ SFX stopped & disposed');
    } catch (e) {
      _log('KILL', '⚠️ SFX dispose error: $e');
    }
    
    // 3) Recrear players
    _bgmPlayer = AudioPlayer();
    _sfxPlayer = AudioPlayer();
    
    // 4) Reiniciar estado
    _currentBgmAsset = null;
    bgmState.value = BgmPlaybackState.stopped;
    bgmMuted.value = false;
    
    _log('KILL', '✓ Players recreated');
    _log('KILL', '  NEW BGM: ${_bgmPlayer!.hashCode}');
    _log('KILL', '  NEW SFX: ${_sfxPlayer!.hashCode}');
    _log('KILL', '═══════════════════════════════════════════════════════');
  }
  
  /// Cambiar volumen BGM
  Future<void> setBgmVolume(double volume) async {
    bgmVolume.value = volume.clamp(0.0, 1.0);
    await _bgmPlayer?.setVolume(bgmVolume.value);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('audio_bgm_volume', bgmVolume.value);
    } catch (e) {
      _log('BGM', '⚠️ Volume save error: $e');
    }
    _log('BGM', 'Volume set: ${bgmVolume.value}');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SFX - EFECTOS DE SONIDO (INDEPENDIENTES DEL BGM)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// SFX usa SOLO vibración háptica (estándar de la industria)
  /// No hay audio - es instantáneo y profesional
  
  /// Reproduce efecto de selección (tap suave)
  /// Uso: al seleccionar un gigante, presionar botones
  void playSelect() {
    if (!sfxEnabled.value) return;
    HapticFeedback.lightImpact();
    _log('SFX', '📳 lightImpact');
  }
  
  /// Reproduce efecto de confirmación
  /// Uso: al confirmar una acción importante
  void playConfirm() {
    if (!sfxEnabled.value) return;
    HapticFeedback.mediumImpact();
    _log('SFX', '📳 mediumImpact');
  }
  
  /// Reproduce efecto de tap (legacy compatibility)
  void playTap() => playSelect();
  
  /// Reproduce efecto de éxito (vibración más notable)
  void playSuccess() {
    if (!sfxEnabled.value) return;
    HapticFeedback.heavyImpact();
    _log('SFX', '📳 heavyImpact');
  }
  
  /// Reproduce efecto de error (vibración doble)
  void playError() {
    if (!sfxEnabled.value) return;
    HapticFeedback.vibrate();
    _log('SFX', '📳 vibrate (error)');
  }
  
  /// Activa/desactiva SFX
  Future<void> setSfxEnabled(bool enabled) async {
    sfxEnabled.value = enabled;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('audio_sfx_enabled', enabled);
    } catch (e) {
      _log('SFX', '⚠️ Pref error: $e');
    }
    _log('SFX', 'Enabled: $enabled');
  }
  
  /// Cambiar volumen SFX
  Future<void> setSfxVolume(double volume) async {
    sfxVolume.value = volume.clamp(0.0, 1.0);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('audio_sfx_volume', sfxVolume.value);
    } catch (e) {
      _log('SFX', '⚠️ Volume save error: $e');
    }
    _log('SFX', 'Volume: ${sfxVolume.value}');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIAGNÓSTICO
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Dump completo del estado de audio a la consola
  void dumpAudioStatus() {
    final report = '''
═══════════════════════════════════════════════════════════════════════════════
🔊 AUDIO ENGINE v2.0 STATUS DUMP
═══════════════════════════════════════════════════════════════════════════════
Engine: $hashCode | Session: $_sessionId | Initialized: $_isInitialized

BGM STATE:
  • State:        ${bgmState.value}
  • Enabled:      ${bgmEnabled.value}
  • Muted:        ${bgmMuted.value}
  • Volume:       ${(bgmVolume.value * 100).toInt()}%
  • VolumePreMute:${(_volumeBeforeMute * 100).toInt()}%
  • Position:     ${bgmPosition.inSeconds}s / ${bgmDuration.inSeconds}s
  • Asset:        $_currentBgmAsset
  • Player Hash:  ${_bgmPlayer?.hashCode ?? 'NULL'}
  • Player.playing: ${_bgmPlayer?.playing ?? 'NULL'}

SFX STATE:
  • Enabled:      ${sfxEnabled.value}
  • Volume:       ${(sfxVolume.value * 100).toInt()}%
  • Player Hash:  ${_sfxPlayer?.hashCode ?? 'NULL'}

LAST ERROR: $_lastError

IMPORTANT: If you hear audio but state says stopped/muted, there's a ROGUE PLAYER!
═══════════════════════════════════════════════════════════════════════════════
''';
    
    debugPrint(report);
    _log('DUMP', 'Status dumped ↑');
  }

  String getDiagnosticReport() {
    return '''
═══════════════════════════════════════════════════════════════════════════════
AUDIO ENGINE v2.0 DIAGNOSTIC
═══════════════════════════════════════════════════════════════════════════════
Engine: $hashCode | Session: $_sessionId

BGM:
  State:     ${bgmState.value}
  Enabled:   ${bgmEnabled.value}
  Volume:    ${(bgmVolume.value * 100).toInt()}%
  Position:  ${bgmPosition.inSeconds}s / ${bgmDuration.inSeconds}s
  Asset:     $_currentBgmAsset
  Player:    ${_bgmPlayer?.hashCode}
  Playing:   ${_bgmPlayer?.playing}

SFX:
  Enabled:   ${sfxEnabled.value}
  Volume:    ${(sfxVolume.value * 100).toInt()}%
  Player:    ${_sfxPlayer?.hashCode}

Error: $_lastError
═══════════════════════════════════════════════════════════════════════════════
''';
  }
  
  /// Test BGM
  Future<bool> testBgm() async {
    _log('TEST', 'testBgm()');
    bgmEnabled.value = true;
    return await startBgm();
  }
  
  /// Test SFX - Solo vibración háptica, NO audio
  Future<bool> testSfx() async {
    _log('TEST', 'testSfx() - Solo haptic');
    
    try {
      // Triple vibración para que el usuario sienta el test
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.heavyImpact();
      
      _log('TEST', '✓ Haptic feedback test completed');
      return true;
    } catch (e) {
      _log('TEST', '❌ Haptic error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGGING
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _log(String tag, String message) {
    debugPrint('🎵 [$tag|$_sessionId] $message');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> dispose() async {
    _log('ENGINE', 'Disposing...');
    
    await _bgmPlayer?.dispose();
    await _sfxPlayer?.dispose();
    
    _bgmPlayer = null;
    _sfxPlayer = null;
    _isInitialized = false;
    
    _log('ENGINE', 'Disposed ✓');
  }
}
