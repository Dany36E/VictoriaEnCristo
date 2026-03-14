import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// FEEDBACK ENGINE v1.0 - Sistema Premium de Feedback (Haptics + SFX)
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Estilo: Netflix/HBO Premium Dark - NO arcade
/// 
/// Características:
/// - Haptics sutiles (lightImpact/mediumImpact)
/// - SFX mini (40-160ms WAV) en volumen bajo-medio
/// - Rate-limiting para evitar spam (<100ms)
/// - Toggles independientes para Haptics y SFX
/// - Completamente separado del BGM
/// ═══════════════════════════════════════════════════════════════════════════

/// Tipos de eventos de feedback
enum FeedbackEvent {
  tap,        // Tap genérico en botones
  select,     // Seleccionar/deseleccionar items
  tabChange,  // Cambio de tabs
  confirm,    // Confirmación/acción principal
  paper,      // Efecto "papelito" de versículo
}

class FeedbackEngine {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final FeedbackEngine _instance = FeedbackEngine._internal();
  static FeedbackEngine get I => _instance;
  static FeedbackEngine get instance => _instance;
  factory FeedbackEngine() => _instance;
  
  FeedbackEngine._internal() {
    _log('ENGINE', '════════════════════════════════════════════════════════');
    _log('ENGINE', 'FeedbackEngine created - hashCode: $hashCode');
    _log('ENGINE', '════════════════════════════════════════════════════════');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLAYER SFX (separado del BGM)
  // ═══════════════════════════════════════════════════════════════════════════
  
  AudioPlayer? _sfxPlayer;
  bool _isInitialized = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADOS (observables)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// ¿Haptics habilitados?
  final ValueNotifier<bool> hapticsEnabled = ValueNotifier(true);
  
  /// ¿SFX habilitados?
  final ValueNotifier<bool> sfxEnabled = ValueNotifier(true);
  
  /// Volumen SFX [0.0 - 1.0] (default 0.4 = sutil)
  final ValueNotifier<double> sfxVolume = ValueNotifier(0.4);

  // ═══════════════════════════════════════════════════════════════════════════
  // RATE LIMITING (anti-spam)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Últimos timestamps por evento
  final Map<FeedbackEvent, int> _lastEventTime = {};
  
  /// Mínimo entre eventos iguales (ms)
  static const int _rateLimitMs = 100;

  // ═══════════════════════════════════════════════════════════════════════════
  // ASSETS SFX
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const Map<FeedbackEvent, String> _sfxAssets = {
    FeedbackEvent.tap: 'assets/sounds/sfx/tap.mp3',
    FeedbackEvent.select: 'assets/sounds/sfx/select.mp3',
    FeedbackEvent.tabChange: 'assets/sounds/sfx/tab_slide.mp3', // Page-flip sutil para tabs
    FeedbackEvent.confirm: 'assets/sounds/sfx/confirm.mp3',
    FeedbackEvent.paper: 'assets/sounds/sfx/paper.mp3',
  };
  
  // ═══════════════════════════════════════════════════════════════════════════
  // VOLÚMENES ESPECÍFICOS POR EVENTO
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const Map<FeedbackEvent, double> _eventVolumes = {
    FeedbackEvent.tap: 0.40,
    FeedbackEvent.select: 0.40,
    FeedbackEvent.tabChange: 0.30, // Más bajo - sutil page/slide
    FeedbackEvent.confirm: 0.45,
    FeedbackEvent.paper: 0.35,
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  bool get isInitialized => _isInitialized;

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
    
    try {
      // Crear player SFX
      _sfxPlayer = AudioPlayer();
      _log('INIT', 'SFX Player created: ${_sfxPlayer.hashCode}');
      
      // Cargar preferencias
      await _loadPreferences();
      
      _isInitialized = true;
      
      _log('INIT', '════════════════════════════════════════════════════════');
      _log('INIT', 'COMPLETE ✓');
      _log('INIT', '  Haptics: ${hapticsEnabled.value}');
      _log('INIT', '  SFX: ${sfxEnabled.value}');
      _log('INIT', '  SFX Vol: ${sfxVolume.value}');
      _log('INIT', '════════════════════════════════════════════════════════');
    } catch (e) {
      _log('INIT', '❌ Error: $e');
    }
  }
  
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hapticsEnabled.value = prefs.getBool('feedback_haptics_enabled') ?? true;
      sfxEnabled.value = prefs.getBool('feedback_sfx_enabled') ?? true;
      sfxVolume.value = prefs.getDouble('feedback_sfx_volume') ?? 0.4;
      _log('INIT', 'Preferences loaded ✓');
    } catch (e) {
      _log('INIT', '⚠️ Prefs load error: $e');
    }
  }
  
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('feedback_haptics_enabled', hapticsEnabled.value);
      await prefs.setBool('feedback_sfx_enabled', sfxEnabled.value);
      await prefs.setDouble('feedback_sfx_volume', sfxVolume.value);
    } catch (e) {
      _log('PREFS', '⚠️ Save error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // API PÚBLICA - Eventos de Feedback
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Tap genérico en botones
  void tap() => _trigger(FeedbackEvent.tap, HapticFeedback.lightImpact);
  
  /// Seleccionar/deseleccionar items (gigantes, checkboxes)
  void select() => _trigger(FeedbackEvent.select, HapticFeedback.lightImpact);
  
  /// Cambio de tabs
  void tabChange() => _trigger(FeedbackEvent.tabChange, HapticFeedback.lightImpact);
  
  /// Confirmación/acción principal (botones CTA)
  void confirm() => _trigger(FeedbackEvent.confirm, HapticFeedback.mediumImpact);
  
  /// Efecto "papelito" de versículo
  void paper() => _trigger(FeedbackEvent.paper, HapticFeedback.lightImpact);

  // ═══════════════════════════════════════════════════════════════════════════
  // CORE - Trigger con rate-limiting
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _trigger(FeedbackEvent event, Future<void> Function() hapticFn) {
    // Rate limiting
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastEventTime[event] ?? 0;
    
    if (now - lastTime < _rateLimitMs) {
      _log('RATE', '⏱️ Rate limited: ${event.name} (${now - lastTime}ms < ${_rateLimitMs}ms)');
      return;
    }
    
    _lastEventTime[event] = now;
    
    // Haptic
    if (hapticsEnabled.value) {
      hapticFn();
      _log('HAPTIC', '📳 ${event.name} -> ${hapticFn == HapticFeedback.lightImpact ? 'lightImpact' : 'mediumImpact'}');
    }
    
    // SFX
    if (sfxEnabled.value) {
      _playSfx(event);
    }
  }
  
  Future<void> _playSfx(FeedbackEvent event) async {
    if (_sfxPlayer == null) {
      _log('SFX', '⚠️ Player null');
      return;
    }
    
    final asset = _sfxAssets[event];
    if (asset == null) {
      _log('SFX', '⚠️ No asset for ${event.name}');
      return;
    }
    
    try {
      // Stop antes de play para no encimar
      await _sfxPlayer!.stop();
      
      // Volumen específico del evento, modulado por el volumen global
      final eventVolume = _eventVolumes[event] ?? 0.40;
      final finalVolume = (sfxVolume.value * eventVolume).clamp(0.0, 1.0);
      
      // Cargar y reproducir
      await _sfxPlayer!.setAsset(asset);
      await _sfxPlayer!.setVolume(finalVolume);
      await _sfxPlayer!.seek(Duration.zero);
      await _sfxPlayer!.play();
      
      _log('SFX', '🎵 ${event.name} asset=$asset vol=${finalVolume.toStringAsFixed(2)} (base=${eventVolume.toStringAsFixed(2)})');
    } catch (e) {
      _log('SFX', '❌ Error playing ${event.name}: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTROLES
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Habilitar/deshabilitar haptics
  Future<void> setHapticsEnabled(bool enabled) async {
    hapticsEnabled.value = enabled;
    await _savePreferences();
    _log('CTRL', 'Haptics: ${enabled ? 'ON' : 'OFF'}');
  }
  
  /// Habilitar/deshabilitar SFX
  Future<void> setSfxEnabled(bool enabled) async {
    sfxEnabled.value = enabled;
    await _savePreferences();
    _log('CTRL', 'SFX: ${enabled ? 'ON' : 'OFF'}');
  }
  
  /// Cambiar volumen SFX
  Future<void> setSfxVolume(double volume) async {
    sfxVolume.value = volume.clamp(0.0, 1.0);
    await _savePreferences();
    _log('CTRL', 'SFX Volume: ${sfxVolume.value.toStringAsFixed(2)}');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEST
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Probar todos los efectos
  Future<void> testAll() async {
    _log('TEST', '════════════════════════════════════════════════════════');
    _log('TEST', 'Testing all feedback events...');
    
    tap();
    await Future.delayed(const Duration(milliseconds: 400));
    
    select();
    await Future.delayed(const Duration(milliseconds: 400));
    
    tabChange();
    await Future.delayed(const Duration(milliseconds: 400));
    
    confirm();
    await Future.delayed(const Duration(milliseconds: 400));
    
    paper();
    
    _log('TEST', '════════════════════════════════════════════════════════');
    _log('TEST', 'Test complete ✓');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGGING
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _log(String tag, String message) {
    debugPrint('🎯 [FEEDBACK|$tag] $message');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> dispose() async {
    _log('ENGINE', 'Disposing...');
    await _sfxPlayer?.dispose();
    _sfxPlayer = null;
    _isInitialized = false;
  }
}
