import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/ot_quote.dart';
import '../../services/bible/ot_quotes_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../widgets/bible/quote_detail_sheet.dart';
import 'bible_reader_screen.dart';

/// Pantalla que lista todas las citas del AT en el NT.
class OTQuotesScreen extends StatefulWidget {
  const OTQuotesScreen({super.key});

  @override
  State<OTQuotesScreen> createState() => _OTQuotesScreenState();
}

class _OTQuotesScreenState extends State<OTQuotesScreen> {
  final _service = OTQuotesService.instance;
  List<OTQuote> _all = [];
  bool _loading = true;
  String _searchQuery = '';
  QuoteType? _activeType;
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
    if (mounted) setState(() { _all = all; _loading = false; });
  }

  List<OTQuote> get _filtered {
    var list = _all;
    if (_activeType != null) {
      list = list.where((q) => q.quoteType == _activeType).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((qt) =>
        qt.ntReference.toLowerCase().contains(q) ||
        qt.otReference.toLowerCase().contains(q) ||
        qt.context.toLowerCase().contains(q) ||
        qt.significance.toLowerCase().contains(q)
      ).toList();
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
          'Citas del AT en el NT',
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
                      hintText: 'Buscar cita...',
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
                // Type filter
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _typeChip('Todas', null, t),
                      _typeChip('Directas', QuoteType.direct, t),
                      _typeChip('Paráfrasis', QuoteType.paraphrase, t),
                      _typeChip('Alusiones', QuoteType.allusion, t),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filtered.length} citas',
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
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 40, left: 16, right: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildQuoteCard(_filtered[i], t),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _typeChip(String label, QuoteType? type, BibleReaderThemeData t) {
    final active = _activeType == type;
    Color chipColor;
    switch (type) {
      case QuoteType.direct:
        chipColor = const Color(0xFF66BB6A);
        break;
      case QuoteType.paraphrase:
        chipColor = const Color(0xFFFFA726);
        break;
      case QuoteType.allusion:
        chipColor = const Color(0xFF42A5F5);
        break;
      case null:
        chipColor = t.accent;
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _activeType = type),
        labelStyle: GoogleFonts.manrope(
          color: active ? t.background : chipColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: chipColor.withOpacity(0.1),
        selectedColor: chipColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildQuoteCard(OTQuote quote, BibleReaderThemeData t) {
    Color typeColor;
    String typeLabel;
    switch (quote.quoteType) {
      case QuoteType.direct:
        typeColor = const Color(0xFF66BB6A);
        typeLabel = 'Directa';
        break;
      case QuoteType.paraphrase:
        typeColor = const Color(0xFFFFA726);
        typeLabel = 'Paráfrasis';
        break;
      case QuoteType.allusion:
        typeColor = const Color(0xFF42A5F5);
        typeLabel = 'Alusión';
        break;
    }
    
    return GestureDetector(
      onTap: () => _showQuoteDetail(quote),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // NT ref
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatOsis(quote.ntReference),
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF42A5F5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_back,
                      color: Color(0xFF555555), size: 12),
                ),
                // OT ref
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7043).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatOsis(quote.otReference),
                    style: GoogleFonts.manrope(
                      color: const Color(0xFFFF7043),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeLabel,
                    style: GoogleFonts.manrope(
                      color: typeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (quote.context.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                quote.context,
                style: GoogleFonts.manrope(
                  color: t.textPrimary.withOpacity(0.5),
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showQuoteDetail(OTQuote quote) {
    final readerTheme = BibleReaderThemeData.fromId(
      BibleUserDataService.I.readerThemeNotifier.value,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuoteDetailSheet(
        quote: quote,
        theme: readerTheme,
        onNavigate: (bookNumber, bookName, chapter) {
          Navigator.pop(context); // close sheet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BibleReaderScreen(
                bookNumber: bookNumber,
                bookName: bookName,
                chapter: chapter,
                version: BibleUserDataService.I.preferredVersionNotifier.value,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatOsis(String osis) {
    final parts = osis.split('.');
    if (parts.length < 3) return osis;
    final bookName = _osisToSpanish[parts[0]] ?? parts[0];
    return '$bookName ${parts.sublist(1).join(':')}';
  }

  static const _osisToSpanish = <String, String>{
    'GEN': 'Gén', 'EXO': 'Éxo', 'LEV': 'Lev', 'NUM': 'Núm',
    'DEU': 'Deu', 'JOS': 'Jos', 'JDG': 'Jue', 'RUT': 'Rut',
    '1SA': '1Sa', '2SA': '2Sa', '1KI': '1Re', '2KI': '2Re',
    '1CH': '1Cr', '2CH': '2Cr', 'EZR': 'Esd', 'NEH': 'Neh',
    'EST': 'Est', 'JOB': 'Job', 'PSA': 'Sal', 'PRO': 'Pro',
    'ECC': 'Ecl', 'SNG': 'Cnt', 'ISA': 'Isa', 'JER': 'Jer',
    'LAM': 'Lam', 'EZK': 'Eze', 'DAN': 'Dan', 'HOS': 'Ose',
    'JOL': 'Joe', 'AMO': 'Amó', 'OBA': 'Abd', 'JON': 'Jon',
    'MIC': 'Miq', 'NAM': 'Nah', 'HAB': 'Hab', 'ZEP': 'Sof',
    'HAG': 'Hag', 'ZEC': 'Zac', 'MAL': 'Mal',
    'MAT': 'Mat', 'MRK': 'Mar', 'LUK': 'Luc', 'JHN': 'Jua',
    'ACT': 'Hch', 'ROM': 'Rom', '1CO': '1Co', '2CO': '2Co',
    'GAL': 'Gál', 'EPH': 'Efe', 'PHP': 'Fil', 'COL': 'Col',
    '1TH': '1Ts', '2TH': '2Ts', '1TI': '1Ti', '2TI': '2Ti',
    'TIT': 'Tit', 'PHM': 'Flm', 'HEB': 'Heb', 'JAS': 'Stg',
    '1PE': '1Pe', '2PE': '2Pe', '1JN': '1Jn', '2JN': '2Jn',
    '3JN': '3Jn', 'JUD': 'Jud', 'REV': 'Apo',
  };
}
