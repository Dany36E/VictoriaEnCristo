import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// MODELOS DE SERIES (contenido en video)
///
/// Estructura data-driven cargada desde `assets/content/series.json`.
/// Pensado para The Chosen y futuras series cristianas.
///
/// Reproducción legal: NO se alojan videos. Cada temporada apunta a una
/// playlist OFICIAL de YouTube (embebida) o, como respaldo, a la página
/// oficial de la serie (se abre externamente).
/// ═══════════════════════════════════════════════════════════════════════════

class VideoEpisode {
  final int number;
  final String title;
  final String? synopsis;

  /// ID de video de YouTube directo (opcional). Si está presente, se reproduce
  /// este video en específico en lugar de usar el índice dentro de la playlist.
  final String? youtubeVideoId;

  const VideoEpisode({
    required this.number,
    required this.title,
    this.synopsis,
    this.youtubeVideoId,
  });

  factory VideoEpisode.fromJson(Map<String, dynamic> json) {
    return VideoEpisode(
      number: json['number'] as int,
      title: json['title'] as String? ?? '',
      synopsis: json['synopsis'] as String?,
      youtubeVideoId: json['youtubeVideoId'] as String?,
    );
  }
}

class VideoSeason {
  final int number;
  final String title;

  /// Playlist OFICIAL de YouTube para esta temporada (embebida). Al tocar un
  /// episodio, el reproductor abre la playlist en el índice correspondiente.
  final String? youtubePlaylistId;

  /// URL oficial de respaldo (se abre externamente cuando no hay playlist
  /// embebible verificada).
  final String? officialUrl;

  final List<VideoEpisode> episodes;

  const VideoSeason({
    required this.number,
    required this.title,
    this.youtubePlaylistId,
    this.officialUrl,
    required this.episodes,
  });

  bool get isEmbeddable =>
      youtubePlaylistId != null && youtubePlaylistId!.trim().isNotEmpty;

  factory VideoSeason.fromJson(Map<String, dynamic> json) {
    return VideoSeason(
      number: json['number'] as int,
      title: json['title'] as String? ?? 'Temporada ${json['number']}',
      youtubePlaylistId: json['youtubePlaylistId'] as String?,
      officialUrl: json['officialUrl'] as String?,
      episodes: (json['episodes'] as List<dynamic>? ?? [])
          .map((e) => VideoEpisode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VideoSeries {
  final String id;
  final String title;
  final String tagline;
  final String description;

  /// Color de acento en formato hex (ej. "FFE8C97A").
  final String accentHex;

  /// URL oficial general de la serie (se abre externamente).
  final String? officialUrl;

  final List<VideoSeason> seasons;

  const VideoSeries({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.accentHex,
    this.officialUrl,
    required this.seasons,
  });

  Color get accentColor {
    final hex = accentHex.replaceAll('#', '');
    final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return Color(value ?? 0xFFE8C97A);
  }

  int get totalEpisodes =>
      seasons.fold(0, (sum, s) => sum + s.episodes.length);

  factory VideoSeries.fromJson(Map<String, dynamic> json) {
    return VideoSeries(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      description: json['description'] as String? ?? '',
      accentHex: json['accentHex'] as String? ?? 'FFE8C97A',
      officialUrl: json['officialUrl'] as String?,
      seasons: (json['seasons'] as List<dynamic>? ?? [])
          .map((e) => VideoSeason.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
