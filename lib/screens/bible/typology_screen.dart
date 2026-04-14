import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/typology.dart';
import '../../services/bible/typology_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../services/bible/bible_user_data_service.dart';
import 'typology_detail_screen.dart';

/// Pantalla que lista todas las tipologías AT→NT con búsqueda y filtro por tags.
class TypologyScreen extends StatefulWidget {
  const TypologyScreen({super.key});

  @override
  State<TypologyScreen> createState() => _TypologyScreenState();
}

class _TypologyScreenState extends State<TypologyScreen> {
  final _service = TypologyService.instance;
  List<Typology> _all = [];
  List<String> _allTags = [];
  bool _loading = true;
  String _searchQuery = '';
  String? _activeTag;
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
    final all = await _service.getAll();
    final tags = await _service.getAllTags();
    if (mounted) {
      setState(() {
        _all = all;
        _allTags = tags;
        _loading = false;
      });
    }
  }

  List<Typology> get _filtered {
    var list = _all;
    if (_activeTag != null) {
      list = list.where((t) => t.tags.contains(_activeTag)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.description.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

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
          'Tipologías Bíblicas',
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
                      hintText: 'Buscar tipología...',
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
                // Tag filter chips
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _tagChip('Todos', null, t),
                      ..._allTags.map((tag) => _tagChip(tag, tag, t)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filtered.length} tipologías',
                      style: GoogleFonts.manrope(
                        color: t.textPrimary.withOpacity(0.3),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // List
                Expanded(
                  child: _filtered.isEmpty
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
                    padding: const EdgeInsets.only(bottom: 40, left: 16, right: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildTypologyCard(_filtered[i], t),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tagChip(String label, String? tag, BibleReaderThemeData t) {
    final active = _activeTag == tag;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _activeTag = tag),
        labelStyle: GoogleFonts.manrope(
          color: active ? t.background : t.textPrimary.withOpacity(0.6),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: t.surface,
        selectedColor: t.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildTypologyCard(Typology typology, BibleReaderThemeData t) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TypologyDetailScreen(typology: typology),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border(
            left: BorderSide(
              color: const Color(0xFF26A69A).withOpacity(0.5),
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    typology.title,
                    style: GoogleFonts.cinzel(
                      color: t.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: t.textPrimary.withOpacity(0.2), size: 20),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              typology.description,
              style: GoogleFonts.manrope(
                color: t.textPrimary.withOpacity(0.5),
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // AT ref
                _refBadge(
                  'AT',
                  typology.oldTestament.reference,
                  const Color(0xFFFF7043),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward,
                      color: Color(0xFF555555), size: 14),
                ),
                // NT ref
                _refBadge(
                  'NT',
                  typology.newTestament.reference,
                  const Color(0xFF42A5F5),
                ),
                const Spacer(),
                // Tags
                ...typology.tags.take(2).map((tag) => Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.textPrimary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.manrope(
                          color: t.textPrimary.withOpacity(0.3),
                          fontSize: 9,
                        ),
                      ),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _refBadge(String testament, String osis, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$testament · ${_formatOsis(osis)}',
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatOsis(String osis) {
    final parts = osis.split('.');
    if (parts.length < 3) return osis;
    return '${parts[1]}:${parts.sublist(2).join(':')}';
  }
}
