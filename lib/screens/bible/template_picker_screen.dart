import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/bible/bible_verse.dart';
import '../../services/bible/bible_share_service.dart';

/// Pantalla de selección de plantilla para compartir como imagen.
class TemplatePickerScreen extends StatefulWidget {
  final BibleVerse verse;
  const TemplatePickerScreen({super.key, required this.verse});

  @override
  State<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends State<TemplatePickerScreen> {
  ShareTemplate _selected = ShareTemplate.midnight;
  final _repaintKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnightDeep,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.midnight,
        elevation: 0,
        title: Text(
          'PLANTILLA',
          style: GoogleFonts.cinzel(
            fontSize: 16,
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
          TextButton(
            onPressed: () => BibleShareService.shareAsImage(_repaintKey),
            child: Text(
              'Compartir',
              style: GoogleFonts.manrope(
                color: AppDesignSystem.gold,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: BibleShareService.buildTemplate(
                    template: _selected,
                    verse: widget.verse,
                  ),
                ),
              ),
            ),
          ),
          // Template selector
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ShareTemplate.values.map((t) {
                final isSelected = t == _selected;
                return GestureDetector(
                  onTap: () => setState(() => _selected = t),
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: t.previewColor,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: AppDesignSystem.gold, width: 2)
                          : Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 2,
                          color: t == ShareTemplate.parchment || t == ShareTemplate.minimal
                              ? Colors.black26
                              : Colors.white38,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.displayName,
                          style: GoogleFonts.manrope(
                            fontSize: 8,
                            color: t == ShareTemplate.parchment ||
                                    t == ShareTemplate.minimal
                                ? Colors.black54
                                : Colors.white54,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
