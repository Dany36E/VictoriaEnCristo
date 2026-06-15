import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';

import 'pdf_file_writer.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../models/bible/bible_verse.dart';
import '../../models/bible/rich_note_document.dart';
import '../../models/bible/sermon_note.dart';
import '../../models/bible/study_word_highlight.dart';

// Paleta del documento.
const _kGold = PdfColor(0.70, 0.58, 0.24);
const _kInk = PdfColor(0.20, 0.16, 0.10);
const _kInkSoft = PdfColor(0.34, 0.27, 0.16);
const _kLabel = PdfColor(0.45, 0.36, 0.20);
const _kBody = PdfColor(0.17, 0.17, 0.18);
const _kCardBg = PdfColor(0.985, 0.975, 0.955);
const _kCardBorder = PdfColor(0.88, 0.85, 0.77);

class SermonNoteExportService {
  SermonNoteExportService._();
  static final SermonNoteExportService I = SermonNoteExportService._();

  bool get shouldSaveToDownloadsByDefault => Platform.isWindows;

  Future<File> exportSermonNoteToPdf({
    required SermonNote note,
    required List<BibleVerse> chapterVerses,
    List<BibleVerse> secondaryChapterVerses = const [],
    List<StudyWordHighlight> highlights = const [],
    bool saveToDownloads = false,
    bool cleanCover = false,
  }) async {
    final fontRegular = pw.Font.ttf(
      await rootBundle.load('google_fonts/Lato-Regular.ttf'),
    );
    final fontBold = pw.Font.ttf(
      await rootBundle.load('google_fonts/Lato-Bold.ttf'),
    );
    final fontItalic = pw.Font.ttf(
      await rootBundle.load('google_fonts/Lato-Italic.ttf'),
    );

    final doc = pw.Document(
      title: _pdfTitle(note),
      author: 'Victoria en Cristo',
      creator: 'Victoria en Cristo',
    );
    final pdfTheme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      italic: fontItalic,
    );

    // Solo versiculos agregados con contenido real (evita tarjetas en blanco).
    final addedVerses = note.verses
        .where(
          (verse) =>
              verse.text.trim().isNotEmpty && verse.bookName.trim().isNotEmpty,
        )
        .toList(growable: false);

    if (cleanCover) {
      doc.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            margin: pw.EdgeInsets.zero,
            theme: pdfTheme,
          ),
          build: (_) => _coverPage(note),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(38, 36, 38, 44),
          theme: pdfTheme,
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Victoria en Cristo · Pagina ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
        ),
        build: (_) => [
          if (!cleanCover) ...[
            _header(note),
            pw.SizedBox(height: 20),
          ],
          if (note.centralPassage != null) ...[
            _sectionTitle('Pasaje central'),
            pw.SizedBox(height: 10),
            ..._centralPassage(
              note,
              chapterVerses: chapterVerses,
              secondaryChapterVerses: secondaryChapterVerses,
              highlights: highlights,
            ),
            pw.SizedBox(height: 18),
          ],
          _sectionTitle('Notas'),
          pw.SizedBox(height: 10),
          note.notes.trim().isEmpty
              ? _emptyText('Sin notas registradas todavia.')
              : _formattedStudyText(note.notes.trim()),
          if (addedVerses.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Versiculos agregados'),
            pw.SizedBox(height: 10),
            for (final verse in addedVerses)
              _verseReferenceBlock(verse, highlights),
          ],
          pw.SizedBox(height: 20),
          _sectionTitle('¿Con que me quedo?'),
          pw.SizedBox(height: 10),
          note.takeaway.trim().isEmpty
              ? _emptyText('Sin reflexion final registrada.')
              : _takeawayBlock(note.takeaway.trim()),
        ],
      ),
    );

    return PdfFileWriter.write(
      bytes: await doc.save(),
      fileName: '${_safeFileBaseName(note)}.pdf',
      appSubfolder: 'exports',
      saveToDownloads: saveToDownloads,
    );
  }

  Future<File> exportAndShareSermonNote({
    required SermonNote note,
    required List<BibleVerse> chapterVerses,
    List<BibleVerse> secondaryChapterVerses = const [],
    List<StudyWordHighlight> highlights = const [],
    bool cleanCover = false,
  }) async {
    final file = await exportSermonNoteToPdf(
      note: note,
      chapterVerses: chapterVerses,
      secondaryChapterVerses: secondaryChapterVerses,
      highlights: highlights,
      cleanCover: cleanCover,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: _pdfTitle(note),
      text: _pdfTitle(note),
    );
    return file;
  }

  String _pdfTitle(SermonNote note) {
    final title = note.title.trim();
    return title.isEmpty ? 'Apunte de predicacion' : title;
  }

  pw.Widget _coverPage(SermonNote note) {
    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      color: _kGold,
      padding: const pw.EdgeInsets.fromLTRB(48, 56, 48, 48),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 64,
            height: 6,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(3),
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Text(
            _pdfTitle(note),
            style: pw.TextStyle(
              fontSize: 26,
              lineSpacing: 5,
              fontWeight: pw.FontWeight.bold,
              color: _kInk,
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            note.centralPassage?.label ?? 'Sin pasaje central',
            style: pw.TextStyle(
              fontSize: 13,
              color: const PdfColor(0.26, 0.21, 0.13),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _metaChips(note),
          ),
          pw.Spacer(),
          pw.Text(
            'Victoria en Cristo',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
          ),
        ],
      ),
    );
  }

  pw.Widget _header(SermonNote note) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.97, 0.95, 0.90),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: const PdfColor(0.82, 0.72, 0.48), width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 42,
            height: 4,
            decoration: pw.BoxDecoration(
              color: _kGold,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            _pdfTitle(note),
            style: pw.TextStyle(
              fontSize: 20,
              lineSpacing: 3,
              fontWeight: pw.FontWeight.bold,
              color: _kInk,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            note.centralPassage?.label ?? 'Sin pasaje central',
            style: pw.TextStyle(
              fontSize: 11.4,
              color: _kLabel,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Wrap(spacing: 8, runSpacing: 8, children: _metaChips(note)),
        ],
      ),
    );
  }

  List<pw.Widget> _metaChips(SermonNote note) {
    return [
      _metaChip('Fecha', _formatDate(note.sermonDate)),
      _metaChip(
        'Predicador',
        note.speaker.trim().isEmpty ? 'No especificado' : note.speaker.trim(),
      ),
      _metaChip('Principal', note.primaryVersionId),
      _metaChip('Secundaria', note.secondaryVersionId),
    ];
  }

  pw.Widget _metaChip(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: const PdfColor(0.86, 0.82, 0.72), width: 0.6),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: _kLabel,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey900),
            ),
          ],
        ),
      ),
    );
  }

  List<pw.Widget> _centralPassage(
    SermonNote note, {
    required List<BibleVerse> chapterVerses,
    required List<BibleVerse> secondaryChapterVerses,
    required List<StudyWordHighlight> highlights,
  }) {
    final central = note.centralPassage;
    if (central == null) return const [];
    final lo = central.startVerse < central.endVerse
        ? central.startVerse
        : central.endVerse;
    final hi = central.startVerse < central.endVerse
        ? central.endVerse
        : central.startVerse;
    final primary = chapterVerses
        .where((verse) => verse.verse >= lo && verse.verse <= hi)
        .toList(growable: false);
    final secondary = secondaryChapterVerses
        .where((verse) => verse.verse >= lo && verse.verse <= hi)
        .toList(growable: false);
    if (primary.isEmpty) {
      return [
        _emptyText('No se encontraron versiculos para el pasaje central.'),
      ];
    }
    return [
      ...primary.map(
        (verse) => _versePairParagraph(
          primary: verse,
          secondary: secondary.cast<BibleVerse?>().firstWhere(
            (candidate) => candidate?.verse == verse.verse,
            orElse: () => null,
          ),
          primaryHighlights: _highlightsFor(
            highlights,
            note.primaryVersionId,
            verse.bookNumber,
            verse.chapter,
            verse.verse,
          ),
          secondaryHighlights: _highlightsFor(
            highlights,
            note.secondaryVersionId,
            verse.bookNumber,
            verse.chapter,
            verse.verse,
          ),
        ),
      ),
    ];
  }

  pw.Widget _versePairParagraph({
    required BibleVerse primary,
    BibleVerse? secondary,
    List<StudyWordHighlight> primaryHighlights = const [],
    List<StudyWordHighlight> secondaryHighlights = const [],
  }) {
    return _verseCard(
      reference: '${primary.bookName} ${primary.chapter}:${primary.verse}',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _verseRichText(
            primary.text,
            fontSize: 11,
            color: _kBody,
            highlights: primaryHighlights,
          ),
          if (secondary != null) ...[
            pw.SizedBox(height: 7),
            _verseRichText(
              secondary.text,
              fontSize: 10.4,
              color: PdfColors.grey700,
              italic: true,
              highlights: secondaryHighlights,
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _verseReferenceBlock(
    SermonVerseReference verse,
    List<StudyWordHighlight> highlights,
  ) {
    return _verseCard(
      reference: '${verse.reference} (${verse.versionId})',
      child: _verseRichText(
        verse.text,
        fontSize: 10.8,
        color: _kBody,
        highlights: _highlightsFor(
          highlights,
          verse.versionId,
          verse.bookNumber,
          verse.chapter,
          verse.verse,
        ),
      ),
    );
  }

  /// Tarjeta uniforme para versiculos (pasaje central y agregados).
  pw.Widget _verseCard({required String reference, required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 9),
      padding: const pw.EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: pw.BoxDecoration(
        color: _kCardBg,
        borderRadius: pw.BorderRadius.circular(7),
        border: pw.Border.all(color: _kCardBorder, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            reference,
            style: pw.TextStyle(
              fontSize: 10.6,
              fontWeight: pw.FontWeight.bold,
              color: _kLabel,
            ),
          ),
          pw.SizedBox(height: 5),
          child,
        ],
      ),
    );
  }

  /// Renderiza el texto de un versiculo subrayando las palabras resaltadas
  /// (con el color del resaltado) para que coincida con la lectura en la app.
  pw.Widget _verseRichText(
    String text, {
    required double fontSize,
    required PdfColor color,
    bool italic = false,
    List<StudyWordHighlight> highlights = const [],
  }) {
    final baseStyle = pw.TextStyle(
      fontSize: fontSize,
      lineSpacing: 3,
      color: color,
      fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
    );
    if (highlights.isEmpty) {
      return pw.Text(text, style: baseStyle, overflow: pw.TextOverflow.span);
    }
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final spans = <pw.InlineSpan>[];
    for (var i = 0; i < tokens.length; i++) {
      final overlapping = highlights
          .where((highlight) => highlight.overlapsWord(i))
          .toList();
      if (overlapping.isNotEmpty) {
        spans.add(
          pw.TextSpan(
            text: tokens[i],
            style: baseStyle.copyWith(
              decoration: pw.TextDecoration.underline,
              decorationColor: _codeColor(overlapping.last),
              decorationThickness: 2.2,
            ),
          ),
        );
      } else {
        spans.add(pw.TextSpan(text: tokens[i], style: baseStyle));
      }
      if (i < tokens.length - 1) {
        spans.add(pw.TextSpan(text: ' ', style: baseStyle));
      }
    }
    return pw.RichText(
      overflow: pw.TextOverflow.span,
      text: pw.TextSpan(style: baseStyle, children: spans),
    );
  }

  PdfColor _codeColor(StudyWordHighlight highlight) {
    final hex = highlight.codeEnum.colorHex.replaceFirst('#', '');
    return PdfColor.fromInt(int.parse('FF$hex', radix: 16));
  }

  List<StudyWordHighlight> _highlightsFor(
    List<StudyWordHighlight> all,
    String versionId,
    int bookNumber,
    int chapter,
    int verse,
  ) {
    return all
        .where(
          (highlight) =>
              highlight.versionId == versionId &&
              highlight.bookNumber == bookNumber &&
              highlight.chapter == chapter &&
              highlight.verse == verse,
        )
        .toList(growable: false);
  }

  pw.Widget _takeawayBlock(String takeaway) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.97, 0.95, 0.90),
        borderRadius: pw.BorderRadius.circular(7),
        border: pw.Border.all(color: const PdfColor(0.86, 0.78, 0.58), width: 0.6),
      ),
      child: pw.Text(
        takeaway,
        style: pw.TextStyle(
          fontSize: 11.4,
          lineSpacing: 3.5,
          color: _kInk,
          fontWeight: pw.FontWeight.bold,
        ),
        overflow: pw.TextOverflow.span,
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _kInkSoft,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: 38,
          height: 2.5,
          decoration: pw.BoxDecoration(
            color: _kGold,
            borderRadius: pw.BorderRadius.circular(1.25),
          ),
        ),
      ],
    );
  }

  pw.Widget _emptyText(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 11,
        lineSpacing: 2,
        color: PdfColors.grey600,
        fontStyle: pw.FontStyle.italic,
      ),
      overflow: pw.TextOverflow.span,
    );
  }

  pw.Widget _formattedStudyText(String source) {
    final segments = richNoteSegments(source);
    if (segments.isEmpty) {
      return _emptyText('Sin notas registradas todavia.');
    }
    return pw.RichText(
      overflow: pw.TextOverflow.span,
      text: pw.TextSpan(
        style: const pw.TextStyle(
          fontSize: 11,
          lineSpacing: 3.6,
          color: _kBody,
        ),
        children: [
          for (final segment in segments)
            pw.TextSpan(
              text: segment.text,
              style: pw.TextStyle(
                fontSize: segment.fontSize ?? 11,
                lineSpacing: 3.6,
                color: _kBody,
                fontWeight: segment.bold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                decoration: segment.underline
                    ? pw.TextDecoration.underline
                    : null,
                decorationColor: segment.underline ? _kGold : null,
                decorationThickness: segment.underline ? 1.8 : null,
              ),
            ),
        ],
      ),
    );
  }

  String _safeFileBaseName(SermonNote note) {
    final title = note.title.trim().isEmpty
        ? 'ApuntePredicacion'
        : note.title.trim();
    final sanitized = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? 'ApuntePredicacion' : sanitized;
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}
