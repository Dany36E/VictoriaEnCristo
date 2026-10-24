import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import '../../services/bible/bible_audio_service.dart';
import '../../services/bible/bible_audio_settings.dart';
import '../../services/bible/bible_tts_service.dart';
import '../../theme/bible_reader_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AUDIO PLAYER BAR — Barra unificada para Audio Real + TTS en el reader.
/// Se posiciona en la parte superior, debajo del header.
///
/// Fila compacta: play/pausa · tipo de audio + referencia · velocidad ·
/// temporizador de sueño · avance automático · cerrar. Con audio narrado
/// agrega la barra de progreso.
/// ═══════════════════════════════════════════════════════════════════════════
class AudioPlayerBar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String bookChapter;
  final bool isRealAudio;
  final VoidCallback onClose;

  /// Número del versículo que suena (unificado TTS/real; normalmente
  /// `controller.audioVerseNumber`). Si es null se usa el del servicio.
  final ValueListenable<int?>? verseNumber;

  /// Play/pausa. Si es null se llama directo al servicio activo.
  final VoidCallback? onPlayPause;

  const AudioPlayerBar({
    super.key,
    required this.theme,
    required this.bookChapter,
    required this.isRealAudio,
    required this.onClose,
    this.verseNumber,
    this.onPlayPause,
  });

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;

    // Barra compacta: se limita la escala de texto para que los controles
    // quepan; la referencia se recorta con «…» si no alcanza.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Material(
        color: t.surface.withValues(alpha: 0.97),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isRealAudio
                    ? t.accent.withValues(alpha: 0.3)
                    : t.accent.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    _buildPlayPause(t),
                    Expanded(child: _buildInfo(t)),
                    _SpeedButton(theme: t),
                    _SleepTimerButton(theme: t),
                    _AutoAdvanceButton(theme: t),
                    IconButton(
                      onPressed: onClose,
                      tooltip: 'Cerrar audio',
                      icon: Icon(
                        Icons.close,
                        color: t.textoTenue(0.8),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Barra de progreso (solo audio real) ──
              if (isRealAudio) _buildProgressBar(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playButton(
    BibleReaderThemeData t, {
    required bool playing,
    required bool buffering,
  }) {
    return IconButton(
      onPressed: buffering ? null : (onPlayPause ?? _defaultPlayPause),
      tooltip: buffering
          ? 'Cargando audio'
          : playing
          ? 'Pausar'
          : 'Reproducir',
      icon: buffering
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
            )
          : Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: t.accent,
              size: 26,
            ),
    );
  }

  void _defaultPlayPause() {
    if (isRealAudio) {
      BibleAudioService.I.togglePlayPause();
    } else if (BibleTtsService.I.isPlaying.value) {
      BibleTtsService.I.pause();
    } else {
      BibleTtsService.I.resume();
    }
  }

  Widget _buildPlayPause(BibleReaderThemeData t) {
    if (isRealAudio) {
      return ValueListenableBuilder<AudioBibleState>(
        valueListenable: BibleAudioService.I.state,
        builder: (_, st, _) => _playButton(
          t,
          playing: st == AudioBibleState.playing,
          buffering: st == AudioBibleState.buffering,
        ),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: BibleTtsService.I.isPlaying,
      builder: (_, playing, _) =>
          _playButton(t, playing: playing, buffering: false),
    );
  }

  /// Tipo de audio arriba y referencia abajo.
  Widget _buildInfo(BibleReaderThemeData t) {
    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isRealAudio ? Icons.graphic_eq : Icons.record_voice_over_outlined,
          size: 12,
          color: isRealAudio ? t.accent : t.textoTenue(0.8),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            isRealAudio ? 'Audio narrado' : 'Voz sintética',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isRealAudio ? t.accent : t.textoTenue(0.8),
            ),
          ),
        ),
        if (!isRealAudio) _buildModeTag(t),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          badge,
          ValueListenableBuilder<int?>(
            valueListenable: _verseListenable(),
            builder: (_, verse, _) {
              final ref = verse != null ? '$bookChapter:$verse' : bookChapter;
              return Text(
                ref,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: 'Leyendo $ref',
                style: AppFonts.manrope(color: t.textPrimary, fontSize: 13),
              );
            },
          ),
        ],
      ),
    );
  }

  ValueListenable<int?> _verseListenable() {
    final given = verseNumber;
    if (given != null) return given;
    if (isRealAudio) return BibleAudioService.I.currentVerse;
    return _TtsVerseNumber.instance;
  }

  Widget _buildModeTag(BibleReaderThemeData t) {
    return ValueListenableBuilder<TtsReadMode>(
      valueListenable: BibleTtsService.I.readMode,
      builder: (_, mode, _) {
        if (mode == TtsReadMode.verseOnly) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            mode == TtsReadMode.both ? 'V+C' : 'COM',
            semanticsLabel: mode == TtsReadMode.both
                ? 'Versículos y comentario'
                : 'Solo comentario',
            style: AppFonts.manrope(
              color: t.accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(BibleReaderThemeData t) {
    return ValueListenableBuilder<Duration>(
      valueListenable: BibleAudioService.I.position,
      builder: (_, pos, _) {
        final dur = BibleAudioService.I.duration.value;
        final progress = dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        return Semantics(
          label: 'Progreso del capítulo',
          value: '${_fmt(pos)} de ${_fmt(dur)}',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: t.accent.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(t.accent),
                      minHeight: 2,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, top: 2),
                    child: Row(
                      children: [
                        Text(
                          _fmt(pos),
                          style: AppFonts.manrope(
                            fontSize: 10,
                            color: t.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _fmt(dur),
                          style: AppFonts.manrope(
                            fontSize: 10,
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fallback cuando la pantalla no pasa `verseNumber`: número aproximado a
/// partir del índice TTS (índice + 1).
class _TtsVerseNumber extends ValueNotifier<int?> {
  _TtsVerseNumber._() : super(null) {
    BibleTtsService.I.currentVerseIndex.addListener(_sync);
    _sync();
  }
  static final _TtsVerseNumber instance = _TtsVerseNumber._();

  void _sync() {
    final idx = BibleTtsService.I.currentVerseIndex.value;
    value = idx >= 0 ? idx + 1 : null;
  }
}

/// Texto de un botón compacto de la barra (velocidad, temporizador).
class _BarChip extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData? icon;
  final String text;
  final bool active;

  const _BarChip({
    required this.theme,
    required this.text,
    this.icon,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final color = active ? t.accent : t.textoTenue(0.8);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) Icon(icon, size: 18, color: color),
          if (icon != null && text.isNotEmpty) const SizedBox(width: 2),
          if (text.isNotEmpty)
            Text(
              text,
              style: AppFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

PopupMenuItem<T> _menuItem<T>(
  BibleReaderThemeData t, {
  required T value,
  required String label,
  required bool selected,
}) {
  return PopupMenuItem<T>(
    value: value,
    child: Semantics(
      selected: selected,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: selected
                ? Icon(Icons.check, size: 18, color: t.accent)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppFonts.manrope(
              color: t.textPrimary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SpeedButton extends StatelessWidget {
  final BibleReaderThemeData theme;
  const _SpeedButton({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final settings = BibleAudioSettings.I;
    return ValueListenableBuilder<double>(
      valueListenable: settings.speed,
      builder: (context, speed, _) {
        final label = BibleAudioSettings.speedLabel(speed);
        return Semantics(
          button: true,
          label: 'Velocidad de lectura: $label',
          excludeSemantics: true,
          child: PopupMenuButton<double>(
            tooltip: 'Velocidad',
            color: t.surface,
            padding: EdgeInsets.zero,
            initialValue: speed,
            onSelected: settings.setSpeed,
            itemBuilder: (_) => [
              for (final s in BibleAudioSettings.speeds)
                _menuItem<double>(
                  t,
                  value: s,
                  label: BibleAudioSettings.speedLabel(s),
                  selected: s == speed,
                ),
            ],
            child: _BarChip(theme: t, text: label, active: speed != 1.0),
          ),
        );
      },
    );
  }
}

class _SleepTimerButton extends StatelessWidget {
  final BibleReaderThemeData theme;
  const _SleepTimerButton({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final timer = BibleSleepTimer.I;
    return ValueListenableBuilder<SleepTimerMode>(
      valueListenable: timer.mode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Duration?>(
          valueListenable: timer.remaining,
          builder: (context, remaining, _) {
            final active = mode != SleepTimerMode.off;
            final text = remaining != null
                ? BibleSleepTimer.format(remaining)
                : mode == SleepTimerMode.endOfChapter
                ? 'Cap.'
                : '';
            final semantic = !active
                ? 'Temporizador de sueño: desactivado'
                : remaining != null
                ? 'Temporizador de sueño: faltan ${remaining.inMinutes} '
                      'minutos ${remaining.inSeconds.remainder(60)} segundos'
                : 'Temporizador de sueño: al terminar el capítulo';
            return Semantics(
              button: true,
              label: semantic,
              excludeSemantics: true,
              child: PopupMenuButton<SleepTimerMode>(
                tooltip: 'Temporizador de sueño',
                color: t.surface,
                padding: EdgeInsets.zero,
                onSelected: timer.set,
                itemBuilder: (_) => [
                  for (final m in SleepTimerMode.values)
                    _menuItem<SleepTimerMode>(
                      t,
                      value: m,
                      label: m.label,
                      selected: m == mode,
                    ),
                ],
                child: _BarChip(
                  theme: t,
                  icon: active ? Icons.bedtime : Icons.bedtime_outlined,
                  text: text,
                  active: active,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AutoAdvanceButton extends StatelessWidget {
  final BibleReaderThemeData theme;
  const _AutoAdvanceButton({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final settings = BibleAudioSettings.I;
    return ValueListenableBuilder<bool>(
      valueListenable: settings.autoAdvance,
      builder: (context, on, _) {
        return Semantics(
          toggled: on,
          label: 'Seguir con el siguiente capítulo',
          excludeSemantics: true,
          child: IconButton(
            onPressed: () => settings.setAutoAdvance(!on),
            tooltip: on
                ? 'Avance automático activado'
                : 'Avance automático desactivado',
            icon: Icon(
              on ? Icons.playlist_play_rounded : Icons.playlist_remove_rounded,
              color: on ? t.accent : t.textoTenue(0.8),
              size: 22,
            ),
          ),
        );
      },
    );
  }
}
