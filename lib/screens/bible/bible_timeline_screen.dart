import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/bible_timeline_models.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_timeline_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE TIMELINE SCREEN — Línea de tiempo bíblica visual
///
/// Scroll horizontal con períodos, eventos y personajes.
/// Tap en evento abre detalle, tap en referencia navega al lector.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleTimelineScreen extends StatefulWidget {
  final int? highlightBookNumber;

  const BibleTimelineScreen({super.key, this.highlightBookNumber});

  @override
  State<BibleTimelineScreen> createState() => _BibleTimelineScreenState();
}

class _BibleTimelineScreenState extends State<BibleTimelineScreen> {
  bool _loading = true;
  String? _selectedPeriodId;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _searchMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await BibleTimelineService.I.init();
    } catch (e) { debugPrint('⏳ [TIMELINE] Load error: $e'); }
    if (mounted) {
      setState(() => _loading = false);
      // Si viene de un capítulo, seleccionar el período relevante
      if (widget.highlightBookNumber != null) {
        final events = BibleTimelineService.I
            .eventsForBook(widget.highlightBookNumber!);
        if (events.isNotEmpty) {
          setState(() => _selectedPeriodId = events.first.periodId);
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (context, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );

        SystemChrome.setSystemUIOverlayStyle(
          t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );

        return Scaffold(
          backgroundColor: t.background,
          body: SafeArea(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        color: t.accent, strokeWidth: 1.5))
                : Column(
                    children: [
                      _buildHeader(t),
                      _buildPeriodTimeline(t),
                      Expanded(child: _buildContent(t)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t) {
    if (_searchMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: t.isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: GoogleFonts.manrope(
                      color: t.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar eventos, personajes...',
                    hintStyle: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: t.textSecondary, size: 20),
              onPressed: () {
                setState(() {
                  _searchMode = false;
                  _searchQuery = '';
                });
                _searchController.clear();
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios,
                color: t.textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Icon(Icons.timeline, color: t.accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Línea de Tiempo',
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.search,
                color: t.textSecondary.withOpacity(0.6), size: 20),
            onPressed: () => setState(() => _searchMode = true),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTimeline(BibleReaderThemeData t) {
    final periods = BibleTimelineService.I.periods;

    return Container(
      height: 80,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: periods.length,
        itemBuilder: (context, index) {
          final period = periods[index];
          final selected = _selectedPeriodId == period.id;
          final color =
              Color(int.parse('FF${period.colorHex}', radix: 16));

          return GestureDetector(
            onTap: () => setState(() => _selectedPeriodId =
                selected ? null : period.id),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              child: Column(
                children: [
                  // Period bar
                  Container(
                    width: 60,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected
                          ? color
                          : color.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: selected
                          ? Border.all(color: color, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${period.yearStart < 0 ? "${period.yearStart.abs()}" : period.yearStart}',
                        style: GoogleFonts.manrope(
                          color: selected
                              ? Colors.white
                              : t.textSecondary.withOpacity(0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 60,
                    child: Text(
                      period.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: selected
                            ? t.textPrimary
                            : t.textSecondary.withOpacity(0.5),
                        fontSize: 8,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BibleReaderThemeData t) {
    // Search mode
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults(t);
    }

    // Selected period detail
    if (_selectedPeriodId != null) {
      return _buildPeriodDetail(t);
    }

    // Default: all periods overview
    return _buildAllPeriodsOverview(t);
  }

  Widget _buildSearchResults(BibleReaderThemeData t) {
    final results = BibleTimelineService.I.search(_searchQuery);
    if (results.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.4),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        if (item is TimelineEvent) {
          return _buildEventTile(t, item);
        }
        if (item is TimelineCharacter) {
          return _buildCharacterTile(t, item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAllPeriodsOverview(BibleReaderThemeData t) {
    final periods = BibleTimelineService.I.periods;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      itemCount: periods.length,
      itemBuilder: (context, index) {
        final period = periods[index];
        final color =
            Color(int.parse('FF${period.colorHex}', radix: 16));
        final eventCount =
            BibleTimelineService.I.eventsForPeriod(period.id).length;
        final charCount =
            BibleTimelineService.I.charactersForPeriod(period.id).length;

        return GestureDetector(
          onTap: () =>
              setState(() => _selectedPeriodId = period.id),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 50,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        period.name,
                        style: GoogleFonts.manrope(
                          color: t.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        period.yearRange,
                        style: GoogleFonts.manrope(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        period.description,
                        style: GoogleFonts.manrope(
                          color: t.textSecondary.withOpacity(0.5),
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '$eventCount eventos',
                            style: GoogleFonts.manrope(
                              color: t.textSecondary.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$charCount personajes',
                            style: GoogleFonts.manrope(
                              color: t.textSecondary.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: t.textSecondary.withOpacity(0.3), size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodDetail(BibleReaderThemeData t) {
    final period = BibleTimelineService.I.getPeriod(_selectedPeriodId!);
    if (period == null) return const SizedBox.shrink();

    final events = BibleTimelineService.I.eventsForPeriod(period.id);
    final chars = BibleTimelineService.I.charactersForPeriod(period.id);
    final color = Color(int.parse('FF${period.colorHex}', radix: 16));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      children: [
        // Period header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period.name,
                style: GoogleFonts.cinzel(
                  color: t.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                period.yearRange,
                style: GoogleFonts.manrope(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                period.description,
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        // Events section
        if (events.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: Text(
              'EVENTOS',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.4),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ...events.map((e) => _buildEventTile(t, e)),
        ],

        // Characters section
        if (chars.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: Text(
              'PERSONAJES',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.4),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ...chars.map((c) => _buildCharacterTile(t, c)),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildEventTile(BibleReaderThemeData t, TimelineEvent event) {
    final period = BibleTimelineService.I.getPeriod(event.periodId);
    final color = period != null
        ? Color(int.parse('FF${period.colorHex}', radix: 16))
        : t.accent;

    return GestureDetector(
      onTap: () => _showEventSheet(t, event),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline dot + line
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: color.withOpacity(0.2),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: GoogleFonts.manrope(
                            color: t.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        event.yearFormatted,
                        style: GoogleFonts.manrope(
                          color: color.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.description,
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.5),
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterTile(
      BibleReaderThemeData t, TimelineCharacter character) {
    final period = BibleTimelineService.I.getPeriod(character.periodId);
    final color = period != null
        ? Color(int.parse('FF${period.colorHex}', radix: 16))
        : t.accent;

    return GestureDetector(
      onTap: () => _showCharacterSheet(t, character),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  character.name[0],
                  style: GoogleFonts.cinzel(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: GoogleFonts.manrope(
                      color: t.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (character.roles.isNotEmpty)
                    Text(
                      character.roles.join(' · '),
                      style: GoogleFonts.manrope(
                        color: color.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (character.lifespan.isNotEmpty)
              Text(
                character.lifespan,
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.4),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEventSheet(BibleReaderThemeData t, TimelineEvent event) {
    final version = BibleUserDataService.I.preferredVersionNotifier.value;

    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 2,
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              event.title,
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.yearFormatted,
              style: GoogleFonts.manrope(
                color: t.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              event.description,
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.7),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            if (event.references.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'REFERENCIAS',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: event.references.map((ref) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigateToReference(ref, version);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: t.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ref.display,
                        style: GoogleFonts.manrope(
                          color: t.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCharacterSheet(
      BibleReaderThemeData t, TimelineCharacter character) {
    final version = BibleUserDataService.I.preferredVersionNotifier.value;
    final period = BibleTimelineService.I.getPeriod(character.periodId);
    final color = period != null
        ? Color(int.parse('FF${period.colorHex}', radix: 16))
        : t.accent;

    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 2,
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      character.name[0],
                      style: GoogleFonts.cinzel(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        character.name,
                        style: GoogleFonts.cinzel(
                          color: t.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (character.roles.isNotEmpty)
                        Text(
                          character.roles.join(' · '),
                          style: GoogleFonts.manrope(
                            color: color.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (character.lifespan.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                character.lifespan,
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              character.description,
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.7),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            if (character.references.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'REFERENCIAS',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: character.references.map((ref) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _navigateToReference(ref, version);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: t.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ref.display,
                        style: GoogleFonts.manrope(
                          color: t.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _navigateToReference(TimelineReference ref, BibleVersion version) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a1, a2) => BibleReaderScreen(
          bookNumber: ref.bookNumber,
          bookName: ref.bookName,
          chapter: ref.chapter,
          version: version,
        ),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (ctx, a, sa, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }
}
