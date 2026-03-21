import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/bible_verse.dart';
import '../../services/bible/bible_share_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';

/// Pantalla de selección de plantilla para compartir como imagen.
/// Layout 60/40: preview arriba, controles abajo con 3 tabs.
class TemplatePickerScreen extends StatefulWidget {
  final BibleVerse verse;
  const TemplatePickerScreen({super.key, required this.verse});

  @override
  State<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends State<TemplatePickerScreen>
    with SingleTickerProviderStateMixin {
  ShareTemplate _selectedTemplate = ShareTemplate.minimalDark;
  ShareDimension _selectedDimension = ShareDimension.square;
  bool _showLogo = true;
  bool _showVersion = true;
  TextAlign _textAlign = TextAlign.center;
  final _repaintKey = GlobalKey();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(BibleReaderThemeData.migrateId(BibleUserDataService.I.readerThemeNotifier.value));
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios,
                        color: t.textSecondary, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    'COMPARTIR',
                    style: GoogleFonts.cinzel(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: t.accent,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            // ── 60% Preview ──
            Expanded(
              flex: 6,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: BibleShareService.buildTemplate(
                        template: _selectedTemplate,
                        verse: widget.verse,
                        dimension: _selectedDimension,
                        showLogo: _showLogo,
                        showVersion: _showVersion,
                        textAlign: _textAlign,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── 40% Controls ──
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: t.surface.withOpacity(0.5),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      indicatorColor: t.accent,
                      indicatorWeight: 2,
                      labelColor: t.accent,
                      unselectedLabelColor: t.textSecondary.withOpacity(0.4),
                      labelStyle: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                      tabs: const [
                        Tab(text: 'PLANTILLA'),
                        Tab(text: 'TAMAÑO'),
                        Tab(text: 'AJUSTES'),
                      ],
                    ),
                    // Tab views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTemplateTab(t),
                          _buildSizeTab(t),
                          _buildSettingsTab(t),
                        ],
                      ),
                    ),
                    // Share button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              BibleShareService.shareAsImage(_repaintKey),
                          icon: const Icon(Icons.share, size: 18),
                          label: Text(
                            'Compartir imagen',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: t.accent,
                            foregroundColor: t.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Template selection ──
  Widget _buildTemplateTab(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: ShareTemplate.values.length,
        itemBuilder: (_, i) {
          final tmpl = ShareTemplate.values[i];
          final isSelected = tmpl == _selectedTemplate;
          return GestureDetector(
            onTap: () => setState(() => _selectedTemplate = tmpl),
            child: Container(
              decoration: BoxDecoration(
                color: tmpl.previewColor,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: t.accent, width: 2)
                    : Border.all(color: t.textSecondary.withOpacity(0.12)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 2,
                    color: tmpl.isDark ? Colors.white38 : Colors.black26,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      tmpl.displayName,
                      style: GoogleFonts.manrope(
                        fontSize: 8,
                        color: tmpl.isDark ? Colors.white54 : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
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

  // ── Tab 2: Dimension selection ──
  Widget _buildSizeTab(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROPORCIONES',
            style: GoogleFonts.manrope(
              color: t.textSecondary.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: ShareDimension.values.map((dim) {
              final isSelected = dim == _selectedDimension;
              final double w;
              final double h;
              switch (dim) {
                case ShareDimension.square:
                  w = 40;
                  h = 40;
                case ShareDimension.story:
                  w = 28;
                  h = 50;
                case ShareDimension.landscape:
                  w = 54;
                  h = 30;
              }
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDimension = dim),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? t.accent.withOpacity(0.15)
                          : t.textPrimary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: t.accent, width: 1.5)
                          : Border.all(color: t.textSecondary.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: w,
                          height: h,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? t.accent
                                  : t.textSecondary.withOpacity(0.24),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dim.label,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? t.accent
                                : t.textSecondary.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Settings ──
  Widget _buildSettingsTab(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          // Alignment selector
          Row(
            children: [
              Text(
                'ALINEACIÓN',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              _alignButton(Icons.format_align_left, TextAlign.left, t),
              const SizedBox(width: 8),
              _alignButton(Icons.format_align_center, TextAlign.center, t),
              const SizedBox(width: 8),
              _alignButton(Icons.format_align_right, TextAlign.right, t),
            ],
          ),
          const SizedBox(height: 16),
          // Toggles
          _toggleRow('Mostrar logo', _showLogo,
              (v) => setState(() => _showLogo = v), t),
          const SizedBox(height: 8),
          _toggleRow('Mostrar versión', _showVersion,
              (v) => setState(() => _showVersion = v), t),
        ],
      ),
    );
  }

  Widget _alignButton(IconData icon, TextAlign align, BibleReaderThemeData t) {
    final isSelected = _textAlign == align;
    return GestureDetector(
      onTap: () => setState(() => _textAlign = align),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? t.accent.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: t.accent, width: 1)
              : Border.all(color: t.textSecondary.withOpacity(0.12)),
        ),
        child: Icon(icon,
            color: isSelected ? t.accent : t.textSecondary.withOpacity(0.4),
            size: 18),
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged, BibleReaderThemeData t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: t.accent,
          inactiveTrackColor: t.textSecondary.withOpacity(0.12),
        ),
      ],
    );
  }
}
