import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../models/series.dart';
import '../../theme/app_theme.dart';

/// Reproductor de episodios. Embebe YouTube por ID de video (método fiable;
/// evita el bug de loadPlaylist del paquete). Siempre ofrece "Ver en YouTube"
/// como respaldo para que nunca quede una pantalla en blanco.
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

  VideoEpisode get _current => widget.season.episodes[_currentIndex];

  bool _episodeEmbeddable(VideoEpisode e) =>
      _canEmbed &&
      e.youtubeVideoId != null &&
      e.youtubeVideoId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialEpisodeIndex;
    if (_episodeEmbeddable(_current)) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: _current.youtubeVideoId!,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: true,
          strictRelatedVideos: true,
        ),
      );
    }
  }

  Future<void> _select(int index) async {
    final ep = widget.season.episodes[index];
    setState(() => _currentIndex = index);
    if (_episodeEmbeddable(ep)) {
      final ctrl = _controller;
      if (ctrl != null) {
        await ctrl.loadVideoById(videoId: ep.youtubeVideoId!);
      } else {
        // No había controlador (el 1er episodio no era embebible); recrearlo
        // no es trivial en caliente, así que abrimos externo.
        await _openExternal(ep);
      }
    } else {
      await _openExternal(ep);
    }
  }

  Future<void> _openExternal(VideoEpisode ep) async {
    String? url;
    final vid = ep.youtubeVideoId;
    if (vid != null && vid.trim().isNotEmpty) {
      url = 'https://www.youtube.com/watch?v=$vid';
    } else if (widget.season.youtubePlaylistId != null) {
      url = 'https://www.youtube.com/playlist?list=${widget.season.youtubePlaylistId}';
    } else {
      url = widget.season.officialUrl ?? widget.series.officialUrl;
    }
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
    final ep = _current;
    final embeddable = _episodeEmbeddable(ep);

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
            if (embeddable && _controller != null)
              YoutubePlayer(controller: _controller!, aspectRatio: 16 / 9)
            else
              _buildExternalFallback(accent),

            // Cabecera episodio + botón "Ver en YouTube" (respaldo siempre).
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
                      'EP ${ep.number}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ep.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ver en YouTube',
                    onPressed: () => _openExternal(ep),
                    icon: Icon(Icons.open_in_new, color: accent, size: 20),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: widget.season.episodes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final e = widget.season.episodes[index];
                  return _EpisodeRow(
                    episode: e,
                    accent: accent,
                    active: index == _currentIndex,
                    onTap: () => _select(index),
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
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.smart_display_outlined, color: accent, size: 52),
          const SizedBox(height: 12),
          Text(
            'Este episodio se ve en YouTube.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _openExternal(_current),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Ver en YouTube'),
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    episode.title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: active ? 1 : 0.85),
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
