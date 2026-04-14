import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/verse_prayer.dart';
import '../../services/bible/bible_user_data_service.dart';

/// Bottom sheet para escribir/editar una oración sobre un versículo.
class PrayerSheet extends StatefulWidget {
  final BibleVerse verse;
  const PrayerSheet({super.key, required this.verse});

  @override
  State<PrayerSheet> createState() => _PrayerSheetState();
}

class _PrayerSheetState extends State<PrayerSheet> {
  late TextEditingController _controller;
  VersePrayer? _existing;

  @override
  void initState() {
    super.initState();
    _existing = BibleUserDataService.I.prayersNotifier.value[widget.verse.uniqueKey];
    _controller = TextEditingController(text: _existing?.prayerText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      await BibleUserDataService.I.deletePrayer(
        widget.verse.bookNumber,
        widget.verse.chapter,
        widget.verse.verse,
      );
    } else {
      await BibleUserDataService.I.savePrayer(
        bookNumber: widget.verse.bookNumber,
        chapter: widget.verse.chapter,
        verse: widget.verse.verse,
        bookName: widget.verse.bookName,
        prayerText: text,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  Icon(Icons.volunteer_activism, color: t.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Oración — ${widget.verse.reference}',
                      style: GoogleFonts.manrope(
                        color: t.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_existing != null)
                    GestureDetector(
                      onTap: () async {
                        final nav = Navigator.of(context);
                        await BibleUserDataService.I.deletePrayer(
                          widget.verse.bookNumber,
                          widget.verse.chapter,
                          widget.verse.verse,
                        );
                        if (mounted) nav.pop();
                      },
                      child: Icon(Icons.delete_outline,
                          color: const Color(0xFFE57373), size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Verse for context
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${widget.verse.text}"',
                  style: GoogleFonts.crimsonPro(
                    color: t.textSecondary.withOpacity(0.6),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              // Text field
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: t.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  minLines: 4,
                  autofocus: true,
                  style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 14, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Señor, con este versículo te pido...',
                    hintStyle: GoogleFonts.manrope(color: t.textSecondary.withOpacity(0.5), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent.withOpacity(0.2),
                    foregroundColor: t.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _existing != null ? 'Actualizar oración' : 'Guardar oración',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
