import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/bible_version.dart';

/// Voz elegida por el usuario para la lectura sintética (nombre + locale tal
/// como los da `flutter_tts.getVoices`). `null` = «Automática».
@immutable
class TtsVoicePreference {
  final String name;
  final String locale;
  const TtsVoicePreference({required this.name, required this.locale});

  String _encode() => '$name\n$locale';

  static TtsVoicePreference? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('\n');
    if (parts.length != 2 || parts[0].isEmpty) return null;
    return TtsVoicePreference(name: parts[0], locale: parts[1]);
  }

  @override
  bool operator ==(Object other) =>
      other is TtsVoicePreference &&
      other.name == name &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);
}

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE AUDIO SETTINGS — Preferencias persistidas del audio bíblico.
///
/// Velocidad, avance automático al siguiente capítulo y voz sintética por
/// idioma. Los servicios de audio escuchan estos notifiers y aplican los
/// cambios en vivo (la velocidad se aplica mientras se reproduce).
/// ═══════════════════════════════════════════════════════════════════════════
class BibleAudioSettings {
  static final BibleAudioSettings I = BibleAudioSettings._();
  BibleAudioSettings._();

  /// Instancia aislada para tests.
  @visibleForTesting
  BibleAudioSettings.forTesting();

  static const _kSpeed = 'bible_audio_speed';
  static const _kAutoAdvance = 'bible_audio_auto_advance';
  static const _kVoicePrefix = 'bible_tts_voice_';

  /// Velocidades que se ofrecen al usuario.
  static const List<double> speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  /// Velocidad elegida (1.0 = normal).
  final ValueNotifier<double> speed = ValueNotifier(1.0);

  /// Pasar solo al siguiente capítulo (o libro) cuando termina el audio.
  final ValueNotifier<bool> autoAdvance = ValueNotifier(true);

  /// Voz elegida para versiones en español (`null` = automática).
  final ValueNotifier<TtsVoicePreference?> voiceSpanish = ValueNotifier(null);

  /// Voz elegida para versiones en inglés (`null` = automática).
  final ValueNotifier<TtsVoicePreference?> voiceEnglish = ValueNotifier(null);

  Future<void>? _loading;

  ValueNotifier<TtsVoicePreference?> voiceNotifierFor(BibleLanguage language) =>
      language == BibleLanguage.english ? voiceEnglish : voiceSpanish;

  TtsVoicePreference? voiceFor(BibleLanguage language) =>
      voiceNotifierFor(language).value;

  /// Carga las preferencias una sola vez (idempotente).
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      speed.value = normalizeSpeed(prefs.getDouble(_kSpeed) ?? 1.0);
      autoAdvance.value = prefs.getBool(_kAutoAdvance) ?? true;
      voiceSpanish.value = TtsVoicePreference._decode(
        prefs.getString('$_kVoicePrefix${BibleLanguage.spanish.code}'),
      );
      voiceEnglish.value = TtsVoicePreference._decode(
        prefs.getString('$_kVoicePrefix${BibleLanguage.english.code}'),
      );
    } catch (e) {
      debugPrint('[BibleAudioSettings] Error cargando prefs: $e');
    }
  }

  /// Ajusta [value] a la velocidad ofrecida más cercana.
  static double normalizeSpeed(double value) {
    var best = speeds.first;
    for (final s in speeds) {
      if ((s - value).abs() < (best - value).abs()) best = s;
    }
    return best;
  }

  /// Etiqueta corta en español: «1x», «1,25x».
  static String speedLabel(double value) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString().replaceAll('.', ',');
    return '${text}x';
  }

  Future<void> setSpeed(double value) async {
    speed.value = normalizeSpeed(value);
    await _save((p) => p.setDouble(_kSpeed, speed.value));
  }

  Future<void> setAutoAdvance(bool value) async {
    autoAdvance.value = value;
    await _save((p) => p.setBool(_kAutoAdvance, value));
  }

  /// Guarda la voz elegida para [language]; `null` vuelve a «Automática».
  Future<void> setVoice(
    BibleLanguage language,
    TtsVoicePreference? voice,
  ) async {
    voiceNotifierFor(language).value = voice;
    final key = '$_kVoicePrefix${language.code}';
    await _save(
      (p) => voice == null ? p.remove(key) : p.setString(key, voice._encode()),
    );
  }

  Future<void> _save(Future<bool> Function(SharedPreferences p) op) async {
    try {
      await op(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('[BibleAudioSettings] Error guardando prefs: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEMPORIZADOR DE SUEÑO
// ═══════════════════════════════════════════════════════════════════════════

enum SleepTimerMode {
  off(null, 'Desactivado'),
  minutes15(Duration(minutes: 15), '15 minutos'),
  minutes30(Duration(minutes: 30), '30 minutos'),
  minutes60(Duration(minutes: 60), '1 hora'),
  endOfChapter(null, 'Al terminar el capítulo');

  final Duration? duration;
  final String label;
  const SleepTimerMode(this.duration, this.label);
}

/// Temporizador de sueño del audio bíblico (de sesión, no se persiste).
///
/// - Con minutos: cuenta hacia atrás y emite [onFired] al llegar a cero.
/// - Con [SleepTimerMode.endOfChapter]: el reproductor llama a
///   [consumeEndOfChapter] cuando un capítulo termina de forma natural; si
///   devuelve `true`, debe detenerse sin pasar al siguiente capítulo.
class BibleSleepTimer {
  static final BibleSleepTimer I = BibleSleepTimer._();
  BibleSleepTimer._();

  @visibleForTesting
  BibleSleepTimer.forTesting();

  /// Modo activo.
  final ValueNotifier<SleepTimerMode> mode = ValueNotifier(SleepTimerMode.off);

  /// Tiempo restante (solo en modos con minutos; `null` en los demás).
  final ValueNotifier<Duration?> remaining = ValueNotifier(null);

  final StreamController<void> _fired = StreamController<void>.broadcast();

  /// Se emite cuando el temporizador vence y hay que detener el audio.
  Stream<void> get onFired => _fired.stream;

  Timer? _ticker;
  DateTime? _endsAt;

  bool get isActive => mode.value != SleepTimerMode.off;

  void set(SleepTimerMode value) {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    mode.value = value;
    final duration = value.duration;
    if (duration == null) {
      remaining.value = null;
      return;
    }
    remaining.value = duration;
    _endsAt = DateTime.now().add(duration);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void cancel() => set(SleepTimerMode.off);

  /// Avanza un segundo a mano (tests).
  @visibleForTesting
  void debugTick() => _tick();

  void _tick() {
    final current = remaining.value;
    if (current == null) return;
    // Cuenta por ticks (exacto en tests) pero sin pasarse del reloj real
    // (si la app estuvo suspendida, el reloj manda).
    var next = current - const Duration(seconds: 1);
    final wall = _endsAt?.difference(DateTime.now());
    if (wall != null && wall < next) next = wall;
    if (next <= Duration.zero) {
      cancel();
      _fired.add(null);
      return;
    }
    remaining.value = next;
  }

  /// Llamar cuando un capítulo termina de forma natural. Devuelve `true` si
  /// el temporizador era «al terminar el capítulo» (y lo desactiva).
  bool consumeEndOfChapter() {
    if (mode.value != SleepTimerMode.endOfChapter) return false;
    cancel();
    return true;
  }

  /// «12:05» para la barra del reproductor.
  static String format(Duration d) {
    final m = d.inMinutes.toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @visibleForTesting
  Future<void> dispose() async {
    _ticker?.cancel();
    await _fired.close();
  }
}
