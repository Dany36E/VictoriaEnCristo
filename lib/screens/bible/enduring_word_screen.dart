import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_fonts.dart';

import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/enduring_word_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../widgets/bible/reader/guzik_attribution.dart';

/// Pantalla de comentario Enduring Word (David Guzik) para un capítulo.
class EnduringWordScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;

  const EnduringWordScreen({
    super.key,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
  });

  @override
  State<EnduringWordScreen> createState() => _EnduringWordScreenState();
}

class _EnduringWordScreenState extends State<EnduringWordScreen> {
  EWChapterCommentary? _commentary;
  bool _loading = true;
  String? _error;

  BibleReaderThemeData get t => BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await EnduringWordService.instance
          .getChapterCommentary(widget.bookNumber, widget.chapter);
      if (!mounted) return;
      setState(() {
        _commentary = result;
        _loading = false;
        if (result == null || result.isEmpty) {
          _error = 'Análisis no disponible para este capítulo.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.pageBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        foregroundColor: t.textPrimary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.bookName} ${widget.chapter}',
              style: AppFonts.cinzel(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: t.accent,
              ),
            ),
            Text(
              'Comentario de David Guzik · Enduring Word',
              style: AppFonts.manrope(
                fontSize: 11,
                color: t.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: t.accent))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 48,
                color: t.accent.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppFonts.manrope(
                color: t.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final c = _commentary!;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      // +1 título, +1 atribución al final
      itemCount: c.sections.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _buildTitle(c.title);
        if (index == c.sections.length + 1) {
          return GuzikAttributionCard(theme: t);
        }
        return _buildSection(c.sections[index - 1]);
      },
    );
  }

  Widget _buildTitle(String title) {
    if (title.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        title,
        style: AppFonts.cinzel(
          color: t.accent,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildSection(EWSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section heading
          GestureDetector(
            onLongPress: () => _copySectionText(section),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(color: t.accent, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      section.heading,
                      style: AppFonts.cinzel(
                        color: t.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  // Se comparte solo esta sección, con atribución y enlace.
                  IconButton(
                    tooltip: 'Compartir esta sección',
                    icon: Icon(Icons.share_outlined, color: t.accent, size: 20),
                    onPressed: () => GuzikAttribution.shareSection(
                      '${widget.bookName} ${widget.chapter}',
                      section,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Paragraphs
          ...section.paragraphs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  p,
                  style: AppFonts.manrope(
                    color: t.textPrimary.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.7,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  void _copySectionText(EWSection section) {
    final text = GuzikAttribution.shareTextFor(
      '${widget.bookName} ${widget.chapter}',
      section,
    );
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sección copiada',
            style: AppFonts.manrope(color: t.textPrimary)),
        backgroundColor: t.surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
