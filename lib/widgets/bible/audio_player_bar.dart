import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/bible/bible_tts_service.dart';
import '../../theme/bible_reader_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AUDIO PLAYER BAR — Barra minimalista para TTS en el reader.
/// Se posiciona en la parte superior, debajo del header.
/// ═══════════════════════════════════════════════════════════════════════════
class AudioPlayerBar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String bookChapter; // "Génesis 1"
  final VoidCallback onClose;

  const AudioPlayerBar({
    super.key,
    required this.theme,
    required this.bookChapter,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final tts = BibleTtsService.I;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: t.surface.withOpacity(0.95),
      child: Row(
        children: [
          // Play/pause
          ValueListenableBuilder<bool>(
            valueListenable: tts.isPlaying,
            builder: (ctx, playing, _) {
              return GestureDetector(
                onTap: () {
                  if (playing) {
                    tts.pause();
                  } else {
                    tts.resume();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: t.accent,
                    size: 22,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Mode indicator
          ValueListenableBuilder<TtsReadMode>(
            valueListenable: tts.readMode,
            builder: (ctx, mode, _) {
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
                    color: t.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
          // Current verse indicator
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: tts.currentVerseIndex,
              builder: (ctx, idx, _) {
                return Text(
                  idx >= 0
                      ? '$bookChapter:${idx + 1}'
                      : bookChapter,
                  style: GoogleFonts.manrope(
                    color: t.textSecondary,
                    fontSize: 13,
                  ),
                );
              },
            ),
          ),
          // Stop
          GestureDetector(
            onTap: () {
              tts.stop();
              onClose();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close,
                  color: t.textSecondary.withOpacity(0.5), size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
