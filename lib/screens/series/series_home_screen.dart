import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/series.dart';
import '../../services/series_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home/category_hub_scaffold.dart';
import 'series_detail_screen.dart';

/// Catálogo de series en video (The Chosen y futuras series).
class SeriesHomeScreen extends StatefulWidget {
  const SeriesHomeScreen({super.key});

  @override
  State<SeriesHomeScreen> createState() => _SeriesHomeScreenState();
}

class _SeriesHomeScreenState extends State<SeriesHomeScreen> {
  List<VideoSeries> _series = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final series = await SeriesService.I.loadSeries();
    if (!mounted) return;
    setState(() {
      _series = series;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CategoryHubScaffold(
      title: 'Series',
      children: [
        _buildIntro(),
        const SizedBox(height: AppDesignSystem.spacingL),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_series.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'No hay series disponibles por ahora.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
          )
        else
          for (int i = 0; i < _series.length; i++) ...[
            _buildSeriesCard(_series[i], i),
            const SizedBox(height: AppDesignSystem.spacingM),
          ],
      ],
    );
  }

  Widget _buildIntro() {
    const accent = Color(0xFFE8C97A);
    return Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
            border:
                Border.all(color: accent.withValues(alpha: 0.2), width: 0.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.movie_creation_outlined,
                  color: accent, size: 22),
              const SizedBox(width: AppDesignSystem.spacingS),
              Expanded(
                child: Text(
                  'Series cristianas para ver y meditar. Contenido oficial.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.1, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildSeriesCard(VideoSeries series, int index) {
    final accent = series.accentColor;
    return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SeriesDetailScreen(series: series),
            ),
          ),
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    accent.withValues(alpha: 0.22),
                    AppDesignSystem.midnight,
                  ),
                  AppDesignSystem.midnightDeep,
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.local_movies, color: accent, size: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${series.seasons.length} temporadas',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      series.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 200 + index * 100),
          duration: 400.ms,
        )
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }
}
