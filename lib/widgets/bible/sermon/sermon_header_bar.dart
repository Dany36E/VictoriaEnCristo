import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_version.dart';
import '../../../theme/bible_reader_theme.dart';

enum _SermonHeaderAction {
  passage,
  versions,
  addVerses,
  savedNotes,
  exportPdf,
  text,
}

class SermonHeaderBar extends StatelessWidget {
  const SermonHeaderBar({
    super.key,
    required this.theme,
    required this.isWide,
    required this.bookName,
    required this.chapter,
    required this.primaryVersion,
    required this.secondaryVersion,
    required this.readingLabel,
    required this.onBack,
    required this.onOpenPassagePicker,
    required this.onOpenVersionPicker,
    required this.onOpenAddVersesPicker,
    required this.onOpenSavedNotes,
    required this.onExportPdf,
    required this.onOpenTypographySheet,
  });

  final BibleReaderThemeData theme;
  final bool isWide;
  final String bookName;
  final int chapter;
  final BibleVersion primaryVersion;
  final BibleVersion secondaryVersion;
  final String readingLabel;
  final VoidCallback onBack;
  final VoidCallback onOpenPassagePicker;
  final VoidCallback onOpenVersionPicker;
  final VoidCallback onOpenAddVersesPicker;
  final VoidCallback onOpenSavedNotes;
  final VoidCallback onExportPdf;
  final void Function(BibleReaderThemeData) onOpenTypographySheet;

  @override
  Widget build(BuildContext context) {
    return isWide ? _buildWide() : _buildCompact();
  }

  Widget _buildWide() {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: t.textSecondary, size: 18),
            onPressed: onBack,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onOpenPassagePicker,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Modo Predicacion',
                    style: GoogleFonts.cinzel(
                      color: t.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HeaderChip(
                    theme: t,
                    icon: Icons.menu_book_outlined,
                    label: readingLabel,
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onOpenVersionPicker,
            icon: Icon(Icons.compare_arrows, color: t.accent, size: 17),
            label: Text('${primaryVersion.shortName} / ${secondaryVersion.shortName}'),
            style: TextButton.styleFrom(
              foregroundColor: t.accent,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Agregar versiculos',
            icon: Icon(Icons.playlist_add, color: t.accent, size: 22),
            onPressed: onOpenAddVersesPicker,
          ),
          IconButton(
            tooltip: 'Apuntes guardados',
            icon: Icon(Icons.folder_open_outlined, color: t.accent, size: 20),
            onPressed: onOpenSavedNotes,
          ),
          IconButton(
            tooltip: 'Exportar PDF',
            icon: Icon(Icons.picture_as_pdf_outlined, color: t.accent, size: 21),
            onPressed: onExportPdf,
          ),
          TextButton.icon(
            onPressed: () => onOpenTypographySheet(t),
            icon: Icon(Icons.text_fields, color: t.accent, size: 17),
            label: const Text('Texto y colores'),
            style: TextButton.styleFrom(
              foregroundColor: t.accent,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: t.accent.withValues(alpha: 0.22)),
              ),
              textStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 6, 2),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.arrow_back_ios_new, color: t.textSecondary, size: 18),
            onPressed: onBack,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onOpenPassagePicker,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Modo Predicacion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cinzel(
                      color: t.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$bookName $chapter · ${primaryVersion.shortName}/${secondaryVersion.shortName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: t.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<_SermonHeaderAction>(
            tooltip: 'Opciones de apuntes',
            color: t.surface,
            icon: Icon(Icons.more_vert, color: t.textSecondary, size: 22),
            onSelected: (action) {
              switch (action) {
                case _SermonHeaderAction.passage:
                  onOpenPassagePicker();
                case _SermonHeaderAction.versions:
                  onOpenVersionPicker();
                case _SermonHeaderAction.addVerses:
                  onOpenAddVersesPicker();
                case _SermonHeaderAction.savedNotes:
                  onOpenSavedNotes();
                case _SermonHeaderAction.exportPdf:
                  onExportPdf();
                case _SermonHeaderAction.text:
                  onOpenTypographySheet(t);
              }
            },
            itemBuilder: (_) => [
              _menuItem(t, _SermonHeaderAction.passage, 'Cambiar lectura'),
              _menuItem(t, _SermonHeaderAction.versions, 'Versiones'),
              _menuItem(t, _SermonHeaderAction.addVerses, 'Agregar versiculos'),
              _menuItem(t, _SermonHeaderAction.savedNotes, 'Apuntes guardados'),
              _menuItem(t, _SermonHeaderAction.exportPdf, 'Exportar PDF'),
              _menuItem(t, _SermonHeaderAction.text, 'Texto y colores'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_SermonHeaderAction> _menuItem(
    BibleReaderThemeData t,
    _SermonHeaderAction value,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Text(label, style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13)),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icon;
  final String label;

  const _HeaderChip({required this.theme, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: t.accent, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.lora(
              color: t.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
