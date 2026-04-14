import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/harmony_section.dart';
import '../../services/bible/gospel_harmony_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';

/// Pantalla que muestra la Armonía de los Evangelios por categorías.
class GospelHarmonyScreen extends StatefulWidget {
  const GospelHarmonyScreen({super.key});

  @override
  State<GospelHarmonyScreen> createState() => _GospelHarmonyScreenState();
}

class _GospelHarmonyScreenState extends State<GospelHarmonyScreen> {
  final _service = GospelHarmonyService.instance;
  Map<String, List<HarmonySection>> _byCategory = {};
  List<String> _categories = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final byCategory = await _service.getByCategory();
    final categories = await _service.getCategories();
    if (mounted) {
      setState(() {
        _byCategory = byCategory;
        _categories = categories;
        _loading = false;
      });
    }
  }

  List<HarmonySection> _getFilteredSections(String category) {
    final sections = _byCategory[category] ?? [];
    if (_searchQuery.isEmpty) return sections;
    final q = _searchQuery.toLowerCase();
    return sections.where((s) => s.title.toLowerCase().contains(q)).toList();
  }

  static const _gospelHeaders = ['Mt', 'Mr', 'Lc', 'Jn'];
  static const _gospelKeys = ['matthew', 'mark', 'luke', 'john'];
  static const _gospelBooks = [40, 41, 42, 43];
  static const _gospelNames = ['Mateo', 'Marcos', 'Lucas', 'Juan'];

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text(
          'Armonía de los Evangelios',
          style: GoogleFonts.cinzel(
            color: t.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: t.accent))
          : Column(
              children: [
                // Search
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.manrope(
                        color: t.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar evento...',
                      hintStyle: GoogleFonts.manrope(
                          color: t.textPrimary.withOpacity(0.3)),
                      prefixIcon: Icon(Icons.search,
                          color: t.accent.withOpacity(0.5)),
                      filled: true,
                      fillColor: t.surface,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                // Column headers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          'Evento',
                          style: GoogleFonts.manrope(
                            color: t.textPrimary.withOpacity(0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ..._gospelHeaders.map((h) => SizedBox(
                            width: 40,
                            child: Text(
                              h,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cinzel(
                                color: t.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(
                    height: 1,
                    color: t.textPrimary.withOpacity(0.08)),
                // Categories list
                Expanded(
                  child: _categories.where((c) => _getFilteredSections(c).isNotEmpty).isEmpty && _searchQuery.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: t.textPrimary.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text('Sin resultados', style: GoogleFonts.manrope(color: t.textPrimary.withOpacity(0.5), fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: _categories.length,
                    itemBuilder: (_, i) =>
                        _buildCategory(_categories[i], t),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategory(String category, BibleReaderThemeData t) {
    final sections = _getFilteredSections(category);
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: t.accent.withOpacity(0.06),
          child: Text(
            category.toUpperCase(),
            style: GoogleFonts.cinzel(
              color: t.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        // Events
        ...sections.map((s) => _buildEventRow(s, t)),
      ],
    );
  }

  Widget _buildEventRow(HarmonySection section, BibleReaderThemeData t) {
    return InkWell(
      onTap: () => _showHarmonyDetail(section, t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: t.textPrimary.withOpacity(0.04),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                section.title,
                style: GoogleFonts.manrope(
                  color: t.textPrimary.withOpacity(0.85),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
            ...List.generate(4, (gi) {
              final ref = section.references[_gospelKeys[gi]];
              final has = ref != null && ref.isNotEmpty;
              return SizedBox(
                width: 40,
                child: Center(
                  child: has
                      ? GestureDetector(
                          onTap: () => _navigateToGospel(gi, ref),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: t.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                _formatChapter(ref),
                                style: GoogleFonts.manrope(
                                  color: t.accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Text(
                          '—',
                          style: TextStyle(
                            color:
                                t.textPrimary.withOpacity(0.12),
                            fontSize: 14,
                          ),
                        ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showHarmonyDetail(HarmonySection section, BibleReaderThemeData t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.7,
        builder: (context, controller) => Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: t.textPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                section.title,
                style: GoogleFonts.cinzel(
                  color: t.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                section.category,
                style: GoogleFonts.manrope(
                  color: t.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              // Gospel grid
              ...List.generate(4, (gi) {
                final ref = section.references[_gospelKeys[gi]];
                final has = ref != null && ref.isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: has ? () => _navigateToGospel(gi, ref) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: has
                            ? t.accent.withOpacity(0.08)
                            : t.textPrimary.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: has
                              ? t.accent.withOpacity(0.2)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _gospelNames[gi],
                            style: GoogleFonts.cinzel(
                              color: has
                                  ? t.accent
                                  : t.textPrimary.withOpacity(0.2),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (has)
                            Text(
                              _formatOsisDisplay(ref),
                              style: GoogleFonts.manrope(
                                color: t.textPrimary
                                    .withOpacity(0.6),
                                fontSize: 12,
                              ),
                            )
                          else
                            Text(
                              'No registrado',
                              style: GoogleFonts.manrope(
                                color: t.textPrimary
                                    .withOpacity(0.15),
                                fontSize: 12,
                              ),
                            ),
                          if (has)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(Icons.chevron_right,
                                  color: t.accent.withOpacity(0.4),
                                  size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToGospel(int gospelIndex, String? ref) {
    if (ref == null) return;
    final chapter = _parseChapter(ref);
    if (chapter == null) return;
    Navigator.pop(context); // Close bottom sheet if open
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          bookNumber: _gospelBooks[gospelIndex],
          bookName: _gospelNames[gospelIndex],
          chapter: chapter,
          version: BibleUserDataService.I.preferredVersionNotifier.value,
        ),
      ),
    );
  }

  String _formatChapter(String? osis) {
    if (osis == null) return '';
    final parts = osis.split('.');
    if (parts.length >= 2) return parts[1];
    return '';
  }

  String _formatOsisDisplay(String? osis) {
    if (osis == null) return '';
    final parts = osis.split('.');
    if (parts.length < 3) return osis;
    return parts.sublist(1).join(':');
  }

  int? _parseChapter(String osis) {
    final parts = osis.split('.');
    if (parts.length >= 2) return int.tryParse(parts[1]);
    return null;
  }
}
