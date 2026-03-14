import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bible_download_service.dart';
import 'bible_reader_screen.dart';
import 'saved_verses_screen.dart';
import 'all_notes_screen.dart';
import 'bible_settings_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE HOME SCREEN
/// Punto de entrada a La Biblia con selector de libro/capítulo,
/// accesos rápidos y búsqueda.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleHomeScreen extends StatefulWidget {
  const BibleHomeScreen({super.key});

  @override
  State<BibleHomeScreen> createState() => _BibleHomeScreenState();
}

class _BibleHomeScreenState extends State<BibleHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BibleBook> _otBooks = [];
  List<BibleBook> _ntBooks = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  BibleVersion get _version => BibleUserDataService.I.preferredVersionNotifier.value;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final ot = await BibleParserService.I.getOldTestament(_version);
    final nt = await BibleParserService.I.getNewTestament(_version);
    if (mounted) {
      setState(() {
        _otBooks = ot;
        _ntBooks = nt;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnightDeep,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppDesignSystem.gold))
          : Column(
              children: [
                _buildQuickActions(),
                _buildSearchBar(),
                _buildTabBar(),
                Expanded(child: _buildTabView()),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppDesignSystem.midnight,
      elevation: 0,
      title: Text(
        'LA BIBLIA',
        style: GoogleFonts.cinzel(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.0,
          color: AppDesignSystem.gold,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        ValueListenableBuilder<BibleVersion>(
          valueListenable: BibleUserDataService.I.preferredVersionNotifier,
          builder: (context, version, _) {
            return TextButton(
              onPressed: _showVersionPicker,
              child: Text(
                version.shortName,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.gold,
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 22),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BibleSettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _QuickActionChip(
            icon: Icons.bookmark_outline,
            label: 'Guardados',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedVersesScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _QuickActionChip(
            icon: Icons.note_outlined,
            label: 'Notas',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllNotesScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Buscar libro...',
            hintStyle: GoogleFonts.manrope(color: Colors.white38, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppDesignSystem.gold.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppDesignSystem.gold,
        unselectedLabelColor: Colors.white54,
        labelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
        dividerHeight: 0,
        tabs: [
          Tab(text: 'Antiguo Testamento (${_otBooks.length})'),
          Tab(text: 'Nuevo Testamento (${_ntBooks.length})'),
        ],
      ),
    );
  }

  Widget _buildTabView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildBookList(_otBooks),
        _buildBookList(_ntBooks),
      ],
    );
  }

  Widget _buildBookList(List<BibleBook> books) {
    final filtered = _searchQuery.isEmpty
        ? books
        : books.where((b) => b.name.toLowerCase().contains(_searchQuery)).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados',
          style: GoogleFonts.manrope(color: Colors.white38, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final book = filtered[index];
        return _BookTile(
          book: book,
          onChapterTap: (chapter) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BibleReaderScreen(
                  bookNumber: book.number,
                  bookName: book.name,
                  chapter: chapter,
                  version: _version,
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showVersionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDesignSystem.midnight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'VERSIÓN',
                style: GoogleFonts.cinzel(
                  color: AppDesignSystem.gold,
                  fontSize: 16,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),
              ...BibleVersion.values.map((v) {
                    final isDownloaded = BibleDownloadService.I.isDownloaded(v);
                    return ListTile(
                    leading: Icon(
                      v == _version ? Icons.check_circle : Icons.circle_outlined,
                      color: v == _version ? AppDesignSystem.gold : Colors.white24,
                    ),
                    title: Text(
                      v.displayName,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: v == _version ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      isDownloaded ? '${v.shortName} · Descargada' : '${v.shortName} · No descargada',
                      style: GoogleFonts.manrope(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: isDownloaded
                        ? const Icon(Icons.download_done, color: Color(0xFF4CAF50), size: 16)
                        : const Icon(Icons.cloud_download_outlined, color: Colors.white24, size: 16),
                    onTap: () async {
                      // Si no está descargada, descargarla primero
                      if (!isDownloaded) {
                        await BibleDownloadService.I.downloadVersion(v);
                      }
                      BibleUserDataService.I.setPreferredVersion(v);
                      if (context.mounted) Navigator.pop(context);
                      setState(() => _loading = true);
                      _loadBooks();
                    },
                  );
                  }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// WIDGETS INTERNOS
// ══════════════════════════════════════════════════════════════════════════

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppDesignSystem.gold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppDesignSystem.gold.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppDesignSystem.gold, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: AppDesignSystem.gold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookTile extends StatefulWidget {
  final BibleBook book;
  final void Function(int chapter) onChapterTap;
  const _BookTile({required this.book, required this.onChapterTap});

  @override
  State<_BookTile> createState() => _BookTileState();
}

class _BookTileState extends State<_BookTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: _expanded
                  ? AppDesignSystem.gold.withOpacity(0.08)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.book.number}',
                    style: GoogleFonts.manrope(
                      color: AppDesignSystem.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.book.name,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${widget.book.totalChapters} cap.',
                  style: GoogleFonts.manrope(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(widget.book.totalChapters, (i) {
                final chapter = i + 1;
                return GestureDetector(
                  onTap: () => widget.onChapterTap(chapter),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppDesignSystem.gold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppDesignSystem.gold.withOpacity(0.15),
                      ),
                    ),
                    child: Text(
                      '$chapter',
                      style: GoogleFonts.manrope(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
