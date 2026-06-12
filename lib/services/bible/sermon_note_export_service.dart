import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../models/bible/bible_verse.dart';
import '../../models/bible/rich_note_document.dart';
import '../../models/bible/sermon_note.dart';

class SermonNoteExportService {
  SermonNoteExportService._();
  static final SermonNoteExportService I = SermonNoteExportService._();

  bool get shouldSaveToDownloadsByDefault => Platform.isWindows;

  Future<File> exportSermonNoteToPdf({
    required SermonNote note,
    required List<BibleVerse> chapterVerses,
    List<BibleVerse> secondaryChapterVerses = const [],
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

    if (cleanCover) {
      doc.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 42),
            theme: pdfTheme,
          ),
          build: (_) => _coverPage(note),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 42),
          theme: pdfTheme,
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Victoria en Cristo · Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          if (!cleanCover) ...[
            _header(note, cleanCover: false),
            pw.SizedBox(height: 18),
          ],
          if (note.centralPassage != null) ...[
            _sectionTitle('Pasaje central'),
            pw.SizedBox(height: 8),
            ..._centralPassage(
              note,
              chapterVerses: chapterVerses,
              secondaryChapterVerses: secondaryChapterVerses,
            ),
            pw.SizedBox(height: 16),
          ],
          _sectionTitle('Notas'),
          pw.SizedBox(height: 8),
          note.notes.trim().isEmpty
              ? _emptyText('Sin notas registradas todavia.')
              : _formattedStudyText(note.notes.trim()),
          if (note.verses.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _sectionTitle('Versiculos agregados'),
            pw.SizedBox(height: 8),
            ...note.verses.map(_verseReferenceBlock),
          ],
          pw.SizedBox(height: 18),
          _sectionTitle('¿Con que me quedo?'),
          pw.SizedBox(height: 8),
          note.takeaway.trim().isEmpty
              ? _emptyText('Sin reflexion final registrada.')
              : _takeawayBlock(note.takeaway.trim()),
        ],
      ),
    );

    return _writePdf(await doc.save(), note, saveToDownloads: saveToDownloads);
  }

  Future<File> exportAndShareSermonNote({
    required SermonNote note,
    required List<BibleVerse> chapterVerses,
    List<BibleVerse> secondaryChapterVerses = const [],
    bool cleanCover = false,
  }) async {
    final file = await exportSermonNoteToPdf(
      note: note,
      chapterVerses: chapterVerses,
      secondaryChapterVerses: secondaryChapterVerses,
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
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.70, 0.58, 0.24),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.fromLTRB(42, 54, 42, 44),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Spacer(flex: 2),
          pw.Text(
            _pdfTitle(note),
            style: pw.TextStyle(
              fontSize: 28,
              lineSpacing: 4,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor(0.16, 0.13, 0.09),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            note.centralPassage?.label ?? 'Sin pasaje central',
            style: pw.TextStyle(
              fontSize: 13,
              color: const PdfColor(0.24, 0.19, 0.12),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 22),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip('Fecha', _formatDate(note.sermonDate)),
              _metaChip(
                'Predicador',
                note.speaker.trim().isEmpty
                    ? 'No especificado'
                    : note.speaker.trim(),
              ),
              _metaChip('Principal', note.primaryVersionId),
              _metaChip('Secundaria', note.secondaryVersionId),
            ],
          ),
          pw.Spacer(flex: 5),
          pw.Container(
            width: 56,
            height: 5,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(999),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Victoria en Cristo',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
          ),
        ],
      ),
    );
  }

  pw.Widget _header(SermonNote note, {required bool cleanCover}) {
    if (cleanCover) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(
            color: const PdfColor(0.86, 0.82, 0.74),
            width: 0.7,
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 42,
              height: 4,
              decoration: pw.BoxDecoration(
                color: const PdfColor(0.72, 0.58, 0.20),
                borderRadius: pw.BorderRadius.circular(999),
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              _pdfTitle(note),
              style: pw.TextStyle(
                fontSize: 19,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor(0.24, 0.20, 0.14),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              note.centralPassage?.label ?? 'Sin pasaje central',
              style: pw.TextStyle(
                fontSize: 11.4,
                color: const PdfColor(0.45, 0.36, 0.20),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip('Fecha', _formatDate(note.sermonDate)),
                _metaChip(
                  'Predicador',
                  note.speaker.trim().isEmpty
                      ? 'No especificado'
                      : note.speaker.trim(),
                ),
                _metaChip('Principal', note.primaryVersionId),
                _metaChip('Secundaria', note.secondaryVersionId),
              ],
            ),
          ],
        ),
      );
    }
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.97, 0.95, 0.90),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: const PdfColor(0.82, 0.72, 0.48),
          width: 0.8,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _pdfTitle(note),
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor(0.28, 0.22, 0.12),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _metaChip('Fecha', _formatDate(note.sermonDate)),
              _metaChip(
                'Predicador',
                note.speaker.trim().isEmpty
                    ? 'No especificado'
                    : note.speaker.trim(),
              ),
              _metaChip('Principal', note.primaryVersionId),
              _metaChip('Secundaria', note.secondaryVersionId),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _metaChip(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(
          color: const PdfColor(0.86, 0.82, 0.72),
          width: 0.6,
        ),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor(0.45, 0.36, 0.20),
              ),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(
                fontSize: 10.5,
                color: PdfColors.grey900,
              ),
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
      pw.Text(
        central.label,
        style: pw.TextStyle(
          fontSize: 12,
          color: const PdfColor(0.45, 0.36, 0.20),
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 6),
      ...primary.map(
        (verse) => _versePairParagraph(
          primary: verse,
          secondary: secondary.cast<BibleVerse?>().firstWhere(
            (candidate) => candidate?.verse == verse.verse,
            orElse: () => null,
          ),
        ),
      ),
    ];
  }

  pw.Widget _versePairParagraph({
    required BibleVerse primary,
    BibleVerse? secondary,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: const PdfColor(0.90, 0.88, 0.82),
          width: 0.5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${primary.bookName} ${primary.chapter}:${primary.verse}',
            style: pw.TextStyle(
              fontSize: 10.8,
              color: const PdfColor(0.45, 0.36, 0.20),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            primary.text,
            style: const pw.TextStyle(
              fontSize: 11,
              lineSpacing: 2,
              color: PdfColors.grey900,
            ),
            overflow: pw.TextOverflow.span,
          ),
          if (secondary != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              secondary.text,
              style: pw.TextStyle(
                fontSize: 10.4,
                lineSpacing: 2,
                color: PdfColors.grey700,
                fontStyle: pw.FontStyle.italic,
              ),
              overflow: pw.TextOverflow.span,
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _verseReferenceBlock(SermonVerseReference verse) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.985, 0.985, 0.975),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: const PdfColor(0.88, 0.88, 0.84),
          width: 0.5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${verse.reference} (${verse.versionId})',
            style: pw.TextStyle(
              fontSize: 10.8,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor(0.45, 0.36, 0.20),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            verse.text,
            style: const pw.TextStyle(
              fontSize: 10.8,
              lineSpacing: 2,
              color: PdfColors.grey900,
            ),
            overflow: pw.TextOverflow.span,
          ),
        ],
      ),
    );
  }

  pw.Widget _takeawayBlock(String takeaway) {
    return pw.Text(
      takeaway,
      style: pw.TextStyle(
        fontSize: 11.4,
        lineSpacing: 2.2,
        color: const PdfColor(0.23, 0.18, 0.11),
        fontWeight: pw.FontWeight.bold,
      ),
      overflow: pw.TextOverflow.span,
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor(0.34, 0.27, 0.16),
      ),
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
    return pw.RichText(
      overflow: pw.TextOverflow.span,
      text: pw.TextSpan(
        children: [
          for (final segment in segments)
            pw.TextSpan(
              text: segment.text,
              style: pw.TextStyle(
                fontSize: segment.fontSize ?? 11,
                lineSpacing: 2,
                color: PdfColors.grey900,
                fontWeight: segment.bold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                decoration: segment.underline
                    ? pw.TextDecoration.underline
                    : null,
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

  Future<File> _writePdf(
    List<int> bytes,
    SermonNote note, {
    required bool saveToDownloads,
  }) async {
    final fileName = '${_safeFileBaseName(note)}.pdf';
    if (saveToDownloads) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return _writeInDirectory(downloads, fileName, bytes);
      }
    }
    return _writeInDirectory(
      await _appDocumentsExportDirectory(),
      fileName,
      bytes,
    );
  }

  Future<Directory> _appDocumentsExportDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}${Platform.pathSeparator}exports');
  }

  Future<File> _writeInDirectory(
    Directory directory,
    String fileName,
    List<int> bytes,
  ) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}
