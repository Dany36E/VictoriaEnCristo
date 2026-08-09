import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../models/series.dart';
import '../../theme/app_theme.dart';

/// Reproductor de episodios de una serie.
///
/// En Android/iOS embebe la playlist OFICIAL de YouTube (empezando en el
/// episodio elegido) y permite cambiar de episodio sin salir. En escritorio
/// (Windows, donde no hay WebView) abre el contenido en YouTube/oficial.
class SeriesPlayerScreen extends StatefulWidget {
  final VideoSeries series;
  final VideoSeason season;
  final int initialEpisodeIndex;

  const SeriesPlayerScreen({
    super.key,
    required this.series,
    required this.season,
    required this.initialEpisodeIndex,
  });

  @override
  State<SeriesPlayerScreen> createState() => _SeriesPlayerScreenState();
}

class _SeriesPlayerScreenState extends State<SeriesPlayerScreen> {
  YoutubePlayerController? _controller;
  late int _currentIndex;

  bool get _canEmbed {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialEpisodeIndex;
    if (_canEmbed) {
      _controller = YoutubePlayerController(
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: true,
          strictRelatedVideos: true,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _play(_currentIndex));
    }
  }

  Future<void> _play(int index) async {
    final ctrl = _controller;
    if (ctrl == null) return;
    final episode = widget.season.episodes[index];
    setState(() => _currentIndex = index);

    if (episode.youtubeVideoId != null &&
        episode.youtubeVideoId!.trim().isNotEmpty) {
      await ctrl.loadVideoById(videoId: episode.youtubeVideoId!);
    } else if (widget.season.isEmbeddable) {
      await ctrl.loadPlaylist(
        list: [widget.season.youtubePlaylistId!],
        listType: ListType.playlist,
        index: index,
      );
    }
  }

  Future<void> _openExternal() async {
    final url = widget.season.officialUrl ?? widget.series.officialUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.series.accentColor;
    final episode = widget.season.episodes[_currentIndex];

    return Scaffold(
      backgroundColor: AppDesignSystem.midnightDeep,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.midnightDeep,
        foregroundColor: AppDesignSystem.pureWhite,
        elevation: 0,
        title: Text(
          widget.season.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Reproductor / respaldo ──────────────────────────────────
            if (_canEmbed && _controller != null)
              YoutubePlayer(
                controller: _controller!,
                aspectRatio: 16 / 9,
              )
            else
              _buildExternalFallback(accent),

            // ── Cabecera del episodio actual ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'EP ${episode.number}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      episode.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Lista de episodios de la temporada ──────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: widget.season.episodes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ep = widget.season.episodes[index];
                  final active = index == _currentIndex;
                  return _EpisodeRow(
                    episode: ep,
                    accent: accent,
                    active: active,
                    onTap: () {
                      if (_canEmbed) {
                        _play(index);
                      } else {
                        setState(() => _currentIndex = index);
                        _openExternal();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalFallback(Color accent) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.play_circle_outline, color: accent, size: 56),
          const SizedBox(height: 14),
          Text(
            'La reproducción embebida no está disponible en esta plataforma.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openExternal,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Ver en YouTube / oficial'),
          ),
        ],
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final VideoEpisode episode;
  final Color accent;
  final bool active;
  final VoidCallback onTap;

  const _EpisodeRow({
    required this.episode,
    required this.accent,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.play_arrow_rounded : Icons.play_circle_outline,
              color: active ? accent : Colors.white.withValues(alpha: 0.5),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Episodio ${episode.number}',
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    episode.title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: active ? 1 : 0.85),
                      fontSize: 14,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
