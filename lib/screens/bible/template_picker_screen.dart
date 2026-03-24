import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/share_template.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/share_cache_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../widgets/bible/share_card_renderer.dart';

/// Pantalla rediseñada para compartir versículos como imagen premium.
/// Preview grande arriba + selector horizontal de plantillas + personalización.
class TemplatePickerScreen extends StatefulWidget {
  final BibleVerse verse;
  final int initialTemplateIndex;
  const TemplatePickerScreen({
    super.key,
    required this.verse,
    this.initialTemplateIndex = 0,
  });

  @override
  State<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends State<TemplatePickerScreen> {
  late int _selectedIndex = widget.initialTemplateIndex;
  double _fontSize = 34;
  int _aspectIndex = 0; // 0=1:1, 1=9:16, 2=4:5
  bool _showLogo = true;
  TextAlign _textAlign = TextAlign.center;
  bool _customOpen = false;
  bool _sharing = false;
  final _repaintKey = GlobalKey();

  static const _aspects = [
    (label: '1:1', w: 1080.0, h: 1080.0),
    (label: '9:16', w: 1080.0, h: 1920.0),
    (label: '4:5', w: 1080.0, h: 1350.0),
  ];

  ShareCardTemplate get _template => kShareTemplates[_selectedIndex];
  Size get _cardSize => Size(_aspects[_aspectIndex].w, _aspects[_aspectIndex].h);

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
        BibleReaderThemeData.migrateId(
            BibleUserDataService.I.readerThemeNotifier.value));

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            _buildTopBar(t),

            // ── Preview (expandable) ──
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: ShareCardRenderer(
                        template: _template,
                        verseText: widget.verse.text,
                        reference: widget.verse.reference,
                        version: widget.verse.version,
                        customFontSize: _fontSize,
                        showLogo: _showLogo,
                        textAlign: _textAlign,
                        cardSize: _cardSize,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom controls ──
            Container(
              decoration: BoxDecoration(
                color: t.surface.withOpacity(0.6),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Template selector (horizontal scroll)
                  _buildTemplateSelector(t),
                  // Expandable customization
                  _buildCustomPanel(t),
                  // Action buttons
                  _buildActionButtons(t),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──
  Widget _buildTopBar(BibleReaderThemeData t) {
    return Padding(
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
    );
  }

  // ── Horizontal template thumbnails ──
  Widget _buildTemplateSelector(BibleReaderThemeData t) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kShareTemplates.length,
        itemBuilder: (_, i) {
          final tmpl = kShareTemplates[i];
          final isSelected = i == _selectedIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedIndex = i),
            child: Container(
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: t.accent, width: 2.5)
                    : Border.all(
                        color: t.textSecondary.withOpacity(0.15)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (tmpl.backgroundAsset != null)
                      Image.asset(
                        tmpl.backgroundAsset!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: tmpl.isDark
                              ? const Color(0xFF1A1A2E)
                              : const Color(0xFFF5F0E8),
                        ),
                      )
                    else
                      Container(
                        color: tmpl.isDark
                            ? const Color(0xFF1A1A2E)
                            : const Color(0xFFF5F0E8),
                      ),
                    // Name overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 3, horizontal: 2),
                        color: Colors.black54,
                        child: Text(
                          tmpl.name,
                          style: GoogleFonts.manrope(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Expandable customization panel ──
  Widget _buildCustomPanel(BibleReaderThemeData t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle header
        GestureDetector(
          onTap: () => setState(() => _customOpen = !_customOpen),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.tune,
                    size: 16, color: t.textSecondary.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  'Personalizar',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: t.textSecondary.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  _customOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: t.textSecondary.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),

        // Panel content
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Font size slider
                Row(
                  children: [
                    Text(
                      'TAMAÑO',
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_fontSize.round()}',
                      style: GoogleFonts.manrope(
                        color: t.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: t.accent,
                    inactiveTrackColor: t.textSecondary.withOpacity(0.12),
                    thumbColor: t.accent,
                    overlayColor: t.accent.withOpacity(0.1),
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _fontSize,
                    min: 34,
                    max: 56,
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),

                const SizedBox(height: 4),

                // Aspect ratio selector
                Row(
                  children: [
                    Text(
                      'PROPORCIÓN',
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    for (int i = 0; i < _aspects.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      _aspectChip(i, t),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Alignment + Logo toggle
                Row(
                  children: [
                    Text(
                      'ALINEACIÓN',
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _alignIcon(Icons.format_align_left, TextAlign.left, t),
                    const SizedBox(width: 6),
                    _alignIcon(
                        Icons.format_align_center, TextAlign.center, t),
                    const SizedBox(width: 6),
                    _alignIcon(
                        Icons.format_align_right, TextAlign.right, t),
                    const Spacer(),
                    Text(
                      'Logo',
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 28,
                      child: Switch(
                        value: _showLogo,
                        onChanged: (v) => setState(() => _showLogo = v),
                        activeColor: t.accent,
                        inactiveTrackColor:
                            t.textSecondary.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          crossFadeState: _customOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _aspectChip(int index, BibleReaderThemeData t) {
    final isSelected = _aspectIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _aspectIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? t.accent.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: t.accent, width: 1.5)
              : Border.all(color: t.textSecondary.withOpacity(0.15)),
        ),
        child: Text(
          _aspects[index].label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? t.accent
                : t.textSecondary.withOpacity(0.45),
          ),
        ),
      ),
    );
  }

  Widget _alignIcon(IconData icon, TextAlign align, BibleReaderThemeData t) {
    final isSelected = _textAlign == align;
    return GestureDetector(
      onTap: () => setState(() => _textAlign = align),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? t.accent.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: t.accent, width: 1)
              : Border.all(color: t.textSecondary.withOpacity(0.12)),
        ),
        child: Icon(icon,
            color: isSelected
                ? t.accent
                : t.textSecondary.withOpacity(0.4),
            size: 16),
      ),
    );
  }

  // ── Action buttons ──
  Widget _buildActionButtons(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          // Download button
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _sharing ? null : _downloadImage,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  'Guardar',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.accent,
                  side: BorderSide(color: t.accent.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Share button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _sharing ? null : _shareImage,
                icon: _sharing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.background,
                        ),
                      )
                    : const Icon(Icons.share, size: 18),
                label: Text(
                  'Compartir',
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
    );
  }

  // ── Image capture ──
  Future<File?> _captureImage() async {
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/victoria_verse_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('📖 [SHARE] Error capturing image: $e');
      return null;
    }
  }

  Future<void> _shareImage() async {
    setState(() => _sharing = true);
    try {
      // Intentar caché primero
      final cached = await ShareCacheService.I.getCachedCard(
        verseKey: widget.verse.uniqueKey,
        templateId: _template.id,
        cardSize: _cardSize,
      );
      final file = cached ?? await _captureImage();
      if (file == null) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Victoria en Cristo',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _downloadImage() async {
    final file = await _captureImage();
    if (file == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imagen guardada en: ${file.path}',
          style: GoogleFonts.manrope(fontSize: 12),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
