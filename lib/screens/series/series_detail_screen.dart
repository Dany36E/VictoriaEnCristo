import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/series.dart';
import '../../theme/app_theme.dart';
import 'series_player_screen.dart';

/// Detalle de una serie: portada, sinopsis y temporadas con sus episodios.
class SeriesDetailScreen extends StatefulWidget {
  final VideoSeries series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  late int _expandedSeason;

  @override
  void initState() {
    super.initState();
    _expandedSeason =
        widget.series.seasons.isNotEmpty ? widget.series.seasons.first.number : -1;
  }

  Future<void> _openEpisode(VideoSeason season, int episodeIndex) async {
    final ep = season.episodes[episodeIndex];
    final vid = ep.youtubeVideoId;
    if (vid != null && vid.trim().isNotEmpty) {
      // Episodio embebible → reproductor in-app (por ID de video, fiable).
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesPlayerScreen(
            series: widget.series,
            season: season,
            initialEpisodeIndex: episodeIndex,
          ),
        ),
      );
    } else if (season.youtubePlaylistUrl != null) {
      // Temporada en YouTube pero sin IDs por episodio → abrir playlist oficial.
      await _launch(season.youtubePlaylistUrl);
    } else {
      // Temporada solo en el sitio oficial.
      await _launch(season.officialUrl ?? widget.series.officialUrl);
    }
  }

  Future<void> _launch(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.series;
    final accent = s.accentColor;

    return Scaffold(
      backgroundColor: AppDesignSystem.midnightDeep,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppDesignSystem.midnightDeep,
            foregroundColor: AppDesignSystem.pureWhite,
            expandedHeight: 210,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                s.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              background: _buildHeaderBackground(accent),
            ),
          ),
          SliverToBoxAdapter(child: _buildIntro(accent)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final season = s.seasons[index];
                return _buildSeason(season, accent);
              },
              childCount: s.seasons.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: 0.25),
              AppDesignSystem.midnight,
            ),
            AppDesignSystem.midnightDeep,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: accent.withValues(alpha: 0.6),
          size: 72,
        ),
      ),
    );
  }

  Widget _buildIntro(Color accent) {
    final s = widget.series;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.tagline,
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.playlist_play, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                '${s.seasons.length} temporadas · ${s.totalEpisodes} episodios',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSeason(VideoSeason season, Color accent) {
    final expanded = _expandedSeason == season.number;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(
              () => _expandedSeason = expanded ? -1 : season.number,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_movies_outlined, color: accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          season.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          season.hasEmbeddableEpisodes
                              ? '${season.episodes.length} episodios · en la app'
                              : season.youtubePlaylistUrl != null
                                  ? '${season.episodes.length} episodios · en YouTube'
                                  : '${season.episodes.length} episodios · sitio oficial',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            for (int i = 0; i < season.episodes.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _episodeTile(season, i, accent),
              ),
          ],
        ],
      ),
    );
  }

  Widget _episodeTile(VideoSeason season, int index, Color accent) {
    final ep = season.episodes[index];
    return InkWell(
      onTap: () => _openEpisode(season, index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '${ep.number}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ep.title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              (ep.youtubeVideoId != null && ep.youtubeVideoId!.trim().isNotEmpty)
                  ? Icons.play_circle_outline
                  : Icons.open_in_new,
              color: Colors.white.withValues(alpha: 0.4),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
