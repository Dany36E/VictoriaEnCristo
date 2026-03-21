import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/bible/bible_audio_service.dart';
import '../../services/bible/bible_tts_service.dart';
import '../../theme/bible_reader_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AUDIO PLAYER BAR — Barra unificada para Audio Real + TTS en el reader.
/// Se posiciona en la parte superior, debajo del header.
/// ═══════════════════════════════════════════════════════════════════════════
class AudioPlayerBar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String bookChapter;
  final bool isRealAudio;
  final VoidCallback onClose;

  const AudioPlayerBar({
    super.key,
    required this.theme,
    required this.bookChapter,
    required this.isRealAudio,
    required this.onClose,
  });

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.surface.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: isRealAudio
                ? const Color(0xFFD4AF37).withOpacity(0.3)
                : t.accent.withOpacity(0.15),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Fila principal: play/pause + info + close ──
          SizedBox(
            height: 40,
            child: Row(
              children: [
                // Play/pause
                _buildPlayPause(t),
                const SizedBox(width: 8),
                // Tipo de audio
                _buildAudioTypeBadge(t),
                const SizedBox(width: 8),
                // Mode indicator (TTS) o verse indicator (real)
                Expanded(child: _buildInfo(t)),
                // Stop
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.close,
                        color: t.textSecondary.withOpacity(0.5), size: 18),
                  ),
                ),
              ],
            ),
          ),
          // ── Barra de progreso (solo audio real) ──
          if (isRealAudio) _buildProgressBar(t),
        ],
      ),
    );
  }

  Widget _buildPlayPause(BibleReaderThemeData t) {
    if (isRealAudio) {
      return ValueListenableBuilder<AudioBibleState>(
        valueListenable: BibleAudioService.I.state,
        builder: (_, st, __) {
          final playing = st == AudioBibleState.playing;
          final buffering = st == AudioBibleState.buffering;
          return GestureDetector(
            onTap: buffering ? null : () => BibleAudioService.I.togglePlayPause(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: buffering
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFFD4AF37),
                      ),
                    )
                  : Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: const Color(0xFFD4AF37),
                      size: 22,
                    ),
            ),
          );
        },
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: BibleTtsService.I.isPlaying,
      builder: (_, playing, __) {
        return GestureDetector(
          onTap: () {
            if (playing) {
              BibleTtsService.I.pause();
            } else {
              BibleTtsService.I.resume();
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: t.accent,
              size: 22,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioTypeBadge(BibleReaderThemeData t) {
    if (isRealAudio) {
      return ValueListenableBuilder<AudioBibleState>(
        valueListenable: BibleAudioService.I.state,
        builder: (_, st, __) {
          final buffering = st == AudioBibleState.buffering;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (buffering) ...[
                SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: const Color(0xFFD4AF37).withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 3),
                Text('Cargando...',
                  style: GoogleFonts.manrope(
                    fontSize: 8,
                    color: const Color(0xFFD4AF37).withOpacity(0.7),
                  ),
                ),
              ] else ...[
                Icon(Icons.graphic_eq, size: 10,
                    color: const Color(0xFFD4AF37).withOpacity(0.7)),
                const SizedBox(width: 3),
                Text('Audio bíblico',
                  style: GoogleFonts.manrope(
                    fontSize: 8,
                    color: const Color(0xFFD4AF37).withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.record_voice_over_outlined, size: 10,
            color: t.textSecondary.withOpacity(0.5)),
        const SizedBox(width: 3),
        Text('Lectura sintetizada',
          style: GoogleFonts.manrope(
            fontSize: 8,
            color: t.textSecondary.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildInfo(BibleReaderThemeData t) {
    if (isRealAudio) {
      return ValueListenableBuilder<int?>(
        valueListenable: BibleAudioService.I.currentVerse,
        builder: (_, verse, __) {
          return Text(
            verse != null ? '$bookChapter:$verse' : bookChapter,
            style: GoogleFonts.manrope(
              color: t.textSecondary, fontSize: 13),
          );
        },
      );
    }

    // TTS: mode + verse
    return Row(
      children: [
        ValueListenableBuilder<TtsReadMode>(
          valueListenable: BibleTtsService.I.readMode,
          builder: (_, mode, __) {
            if (mode == TtsReadMode.verseOnly) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                mode == TtsReadMode.both ? 'V+C' : 'COM',
                style: GoogleFonts.manrope(
                    color: t.accent, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            );
          },
        ),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: BibleTtsService.I.currentVerseIndex,
            builder: (_, idx, __) {
              return Text(
                idx >= 0 ? '$bookChapter:${idx + 1}' : bookChapter,
                style: GoogleFonts.manrope(
                    color: t.textSecondary, fontSize: 13),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(BibleReaderThemeData t) {
    return ValueListenableBuilder<Duration>(
      valueListenable: BibleAudioService.I.position,
      builder: (_, pos, __) {
        final dur = BibleAudioService.I.duration.value;
        final progress = dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        return Column(
          children: [
            SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor:
                    const Color(0xFFD4AF37).withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFD4AF37)),
                minHeight: 2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4, top: 2),
              child: Row(
                children: [
                  Text(_fmt(pos),
                      style: GoogleFonts.manrope(
                          fontSize: 9, color: t.textSecondary)),
                  const Spacer(),
                  Text(_fmt(dur),
                      style: GoogleFonts.manrope(
                          fontSize: 9, color: t.textSecondary)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
