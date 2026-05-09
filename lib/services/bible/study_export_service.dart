import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../models/bible/bible_verse.dart';
import '../../models/bible/study_chapter_answers.dart';

class StudyExportService {
  StudyExportService._();
  static final StudyExportService I = StudyExportService._();

  Future<File> exportStudyToPdf({
    required StudyChapterAnswers study,
    required List<BibleVerse> chapterVerses,
  }) async {
    final selectedVerses = _selectedVerses(study, chapterVerses);
    final doc = pw.Document(
      title: 'Estudio ${study.reference}',
      author: 'Victoria en Cristo',
      creator: 'Victoria en Cristo',
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 42),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
            italic: pw.Font.helveticaOblique(),
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Victoria en Cristo · Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          _header(study),
          pw.SizedBox(height: 18),
          _sectionTitle('Texto bíblico'),
          pw.SizedBox(height: 8),
          if (selectedVerses.isEmpty)
            pw.Text('No se encontraron versículos para este rango.')
          else
            ...selectedVerses.map(_verseParagraph),
          pw.SizedBox(height: 20),
          _sectionTitle('Preguntas y respuestas'),
          pw.SizedBox(height: 8),
          ..._answers(study),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}${Platform.pathSeparator}estudios');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File(
      '${exportDir.path}${Platform.pathSeparator}${_fileName(study)}.pdf',
    );
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  Future<File> exportAndShareStudy({
    required StudyChapterAnswers study,
    required List<BibleVerse> chapterVerses,
  }) async {
    final file = await exportStudyToPdf(
      study: study,
      chapterVerses: chapterVerses,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Estudio ${study.reference}',
      text: 'Estudio bíblico ${study.reference}',
    );
    return file;
  }

  List<BibleVerse> _selectedVerses(
    StudyChapterAnswers study,
    List<BibleVerse> chapterVerses,
  ) {
    final start = study.studyStartVerse;
    final end = study.studyEndVerse;
    if (start == null || end == null) return chapterVerses;
    final lo = start < end ? start : end;
    final hi = start < end ? end : start;
    return chapterVerses
        .where((v) => v.verse >= lo && v.verse <= hi)
        .toList(growable: false);
  }

  pw.Widget _header(StudyChapterAnswers study) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor(0.72, 0.58, 0.20), width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Estudio bíblico',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor(0.12, 0.16, 0.20),
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            study.reference,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor(0.72, 0.58, 0.20),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Versión: ${study.versionId} · Actualizado: ${_date(study.updatedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor(0.12, 0.16, 0.20),
      ),
    );
  }

  pw.Widget _verseParagraph(BibleVerse verse) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '${verse.verse} ',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor(0.72, 0.58, 0.20),
              ),
            ),
            pw.TextSpan(text: verse.text),
          ],
          style: const pw.TextStyle(
            fontSize: 11.5,
            lineSpacing: 2,
            color: PdfColors.grey900,
          ),
        ),
      ),
    );
  }

  List<pw.Widget> _answers(StudyChapterAnswers study) {
    final widgets = <pw.Widget>[];
    for (final question in kStudyQuestions) {
      final answer = study.answers[question.id]?.trim() ?? '';
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                question.prompt,
                style: pw.TextStyle(
                  fontSize: 11.5,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor(0.12, 0.16, 0.20),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                answer.isEmpty ? 'Sin respuesta todavía.' : answer,
                style: pw.TextStyle(
                  fontSize: 11,
                  lineSpacing: 2,
                  color: answer.isEmpty ? PdfColors.grey600 : PdfColors.grey900,
                  fontStyle: answer.isEmpty
                      ? pw.FontStyle.italic
                      : pw.FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  String _fileName(StudyChapterAnswers study) {
    final raw = 'estudio_${study.reference}_${study.versionId}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü]+', unicode: true), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return raw.isEmpty ? 'estudio_biblico' : raw;
  }

  String _date(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }
}
