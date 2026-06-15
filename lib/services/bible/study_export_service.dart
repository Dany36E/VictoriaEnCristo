import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';

import 'pdf_file_writer.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../models/bible/bible_verse.dart';
import '../../models/bible/rich_note_document.dart';
import '../../models/bible/study_chapter_answers.dart';
import '../../models/bible/study_room.dart';
import '../../models/bible/study_word_highlight.dart';

/// Conjunto de datos por participante de una sala de estudio para exportar al
/// PDF combinado. Cada `StudyParticipantBundle` agrupa los resaltados de cada
/// versión que el usuario leyó y sus respuestas privadas.
class StudyParticipantBundle {
  final String uid;
  final String displayName;
  final List<StudyParticipantVersion> versions;
  final Map<String, String> answers;
  final String hopeMessage;
  final String mainVerseReference;
  final String generalNotes;
  final String currentVersionId;

  const StudyParticipantBundle({
    required this.uid,
    required this.displayName,
    required this.versions,
    required this.answers,
    required this.hopeMessage,
    required this.mainVerseReference,
    required this.generalNotes,
    required this.currentVersionId,
  });

  bool get hasAnyContent =>
      versions.any((v) => v.highlights.isNotEmpty || v.verses.isNotEmpty) ||
      answers.values.any((value) => value.trim().isNotEmpty) ||
      hopeMessage.trim().isNotEmpty ||
      generalNotes.trim().isNotEmpty;
}

class StudyParticipantVersion {
  final String versionId;
  final List<BibleVerse> verses;
  final List<StudyWordHighlight> highlights;

  const StudyParticipantVersion({
    required this.versionId,
    required this.verses,
    required this.highlights,
  });
}

class StudyExportService {
  StudyExportService._();
  static final StudyExportService I = StudyExportService._();

  bool get shouldSaveToDownloadsByDefault => Platform.isWindows;

  Future<File> exportStudyToPdf({
    required StudyChapterAnswers study,
    required List<BibleVerse> chapterVerses,
    List<BibleVerse> secondaryChapterVerses = const [],
    String? secondaryVersionId,
    List<StudyWordHighlight> studyHighlights = const [],
    List<StudyRoomAnswerSnapshot> roomAnswerSnapshots = const [],
    bool saveToDownloads = false,
    bool cleanCover = false,
  }) async {
    final selectedVerses = _selectedVerses(study, chapterVerses);
    final selectedSecondary = _selectedVerses(study, secondaryChapterVerses);

    // Carga fuentes TTF embebidas para soportar caracteres latinos/españoles.
    // pw.Font.helvetica() es ASCII-only y produce cajas negras con á/é/ñ/etc.
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
      title: 'Estudio ${study.reference}',
      author: 'Victoria en Cristo',
      creator: 'Victoria en Cristo',
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 42),
          theme: pw.ThemeData.withFont(
            base: fontRegular,
            bold: fontBold,
            italic: fontItalic,
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
          _header(
            study,
            secondaryVersionId: secondaryVersionId,
            cleanCover: cleanCover,
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Texto bíblico'),
          pw.SizedBox(height: 8),
          if (selectedVerses.isEmpty)
            pw.Text('No se encontraron versículos para este rango.')
          else
            ...selectedVerses.map(
              (verse) => _versePairParagraph(
                primary: verse,
                secondary: _secondaryForVerse(selectedSecondary, verse),
                secondaryVersionId: secondaryVersionId,
                studyHighlights: studyHighlights,
              ),
            ),
          pw.SizedBox(height: 20),
          _sectionTitle('Preguntas y respuestas'),
          pw.SizedBox(height: 8),
          ..._answers(study),
          if (roomAnswerSnapshots.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Reflexión final de la sala'),
            pw.SizedBox(height: 8),
            ..._roomReflection(roomAnswerSnapshots),
          ],
          pw.SizedBox(height: 14),
          _sectionTitle('Mensaje de esperanza'),
          pw.SizedBox(height: 8),
          _hopeMessage(study),
          pw.SizedBox(height: 20),
          _sectionTitle('Notas generales'),
          pw.SizedBox(height: 8),
          _generalNotes(study),
        ],
      ),
    );

    return PdfFileWriter.write(
      bytes: await doc.save(),
      fileName: '${_fileName(study)}.pdf',
      appSubfolder: 'estudios',
      saveToDownloads: saveToDownloads,
    );
  }

  Future<File> exportAndShareStudy({
    required StudyChapterAnswers study,
    required List<BibleVerse> chapterVerses,
    List<BibleVerse> secondaryChapterVerses = const [],
    String? secondaryVersionId,
    List<StudyWordHighlight> studyHighlights = const [],
    List<StudyRoomAnswerSnapshot> roomAnswerSnapshots = const [],
    bool cleanCover = false,
  }) async {
    final file = await exportStudyToPdf(
      study: study,
      chapterVerses: chapterVerses,
      secondaryChapterVerses: secondaryChapterVerses,
      secondaryVersionId: secondaryVersionId,
      studyHighlights: studyHighlights,
      roomAnswerSnapshots: roomAnswerSnapshots,
      cleanCover: cleanCover,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Estudio ${study.reference}',
      text: 'Estudio bíblico ${study.reference}',
    );
    return file;
  }

  /// Exporta un PDF agrupado por participante de la sala. Cada participante
  /// aparece con todas las versiones que leyó (con sus resaltados privados)
  /// seguidas de sus respuestas, mensaje de esperanza y notas. Al final se
  /// añade una sección combinada "Todo junto" con las respuestas de todos.
  Future<File> exportRoomStudyToPdf({
    required StudyChapterAnswers study,
    required List<StudyParticipantBundle> participants,
    List<StudyRoomAnswerSnapshot> roomAnswerSnapshots = const [],
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

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      italic: fontItalic,
    );

    final doc = pw.Document(
      title: 'Estudio en grupo ${study.reference}',
      author: 'Victoria en Cristo',
      creator: 'Victoria en Cristo',
    );

    // Hoja de portada dedicada (participantes, versiones, pasajes + añadidos).
    doc.addPage(
      _roomCoverPage(study: study, participants: participants, theme: theme),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 42),
          theme: theme,
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Victoria en Cristo · Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          _sectionTitle('Detalle por participante'),
          pw.SizedBox(height: 4),
          pw.Text(
            'Estudio colaborativo · ${participants.length} '
            '${participants.length == 1 ? 'participante' : 'participantes'}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          if (participants.isEmpty)
            pw.Text(
              'Sin participantes registrados todavía.',
              style: pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            )
          else
            for (var i = 0; i < participants.length; i++)
              ..._participantSection(study, participants[i], index: i + 1),
          if (roomAnswerSnapshots.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Todo junto · Respuestas combinadas'),
            pw.SizedBox(height: 8),
            ..._roomReflection(roomAnswerSnapshots),
          ],
        ],
      ),
    );

    return PdfFileWriter.write(
      bytes: await doc.save(),
      fileName: '${_fileName(study)}.pdf',
      appSubfolder: 'estudios',
      saveToDownloads: saveToDownloads,
    );
  }

  Future<File> exportAndShareRoomStudy({
    required StudyChapterAnswers study,
    required List<StudyParticipantBundle> participants,
    List<StudyRoomAnswerSnapshot> roomAnswerSnapshots = const [],
    bool cleanCover = false,
  }) async {
    final file = await exportRoomStudyToPdf(
      study: study,
      participants: participants,
      roomAnswerSnapshots: roomAnswerSnapshots,
      cleanCover: cleanCover,
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Estudio en grupo ${study.reference}',
      text: 'Estudio bíblico colaborativo ${study.reference}',
    );
    return file;
  }

  List<pw.Widget> _participantSection(
    StudyChapterAnswers study,
    StudyParticipantBundle participant, {
    required int index,
  }) {
    return [
      pw.SizedBox(height: 14),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: pw.BoxDecoration(
          color: const PdfColor(0.96, 0.92, 0.78),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          'Usuario $index · ${participant.displayName}',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor(0.12, 0.16, 0.20),
          ),
        ),
      ),
      pw.SizedBox(height: 10),
      _sectionTitle('Texto bíblico con subrayados'),
      pw.SizedBox(height: 6),
      if (participant.versions.isEmpty)
        pw.Text(
          'Este participante no registró versiones todavía.',
          style: pw.TextStyle(
            fontSize: 10.8,
            color: PdfColors.grey600,
            fontStyle: pw.FontStyle.italic,
          ),
        )
      else
        for (final version in participant.versions)
          ..._participantVersionBlock(study, version),
      pw.SizedBox(height: 12),
      _sectionTitle('Preguntas y respuestas'),
      pw.SizedBox(height: 6),
      ..._participantAnswersBlock(participant),
      pw.SizedBox(height: 12),
      _sectionTitle('Mensaje de esperanza'),
      pw.SizedBox(height: 6),
      _participantHopeBlock(participant),
      pw.SizedBox(height: 12),
      _sectionTitle('Notas generales'),
      pw.SizedBox(height: 6),
      _participantNotesBlock(participant),
      pw.SizedBox(height: 6),
      pw.Divider(color: PdfColors.grey300, thickness: 0.5),
    ];
  }

  List<pw.Widget> _participantVersionBlock(
    StudyChapterAnswers study,
    StudyParticipantVersion version,
  ) {
    final selected = _selectedVerses(study, version.verses);
    return [
      pw.SizedBox(height: 6),
      pw.Text(
        'Versión: ${version.versionId}',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor(0.72, 0.58, 0.20),
        ),
      ),
      pw.SizedBox(height: 4),
      if (selected.isEmpty)
        pw.Text(
          'Sin versículos cargados para esta versión.',
          style: pw.TextStyle(
            fontSize: 10.8,
            color: PdfColors.grey600,
            fontStyle: pw.FontStyle.italic,
          ),
        )
      else
        for (final verse in selected)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: _highlightedVerseText(
              verse: verse,
              highlights: _highlightsForVerse(version.highlights, verse),
              fontSize: 11,
              numberColor: const PdfColor(0.72, 0.58, 0.20),
              textColor: PdfColors.grey900,
            ),
          ),
    ];
  }

  List<pw.Widget> _participantAnswersBlock(StudyParticipantBundle participant) {
    return [
      for (final question in kStudyQuestions)
        _answerCard(
          prompt: question.prompt,
          answer: (participant.answers[question.id] ?? '').trim(),
        ),
    ];
  }

  pw.Widget _answerCard({required String prompt, required String answer}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
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
            prompt,
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
            overflow: pw.TextOverflow.span,
          ),
        ],
      ),
    );
  }

  pw.Widget _participantHopeBlock(StudyParticipantBundle participant) {
    final message = participant.hopeMessage.trim();
    final mainReference = participant.mainVerseReference;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.98, 0.96, 0.90),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: const PdfColor(0.88, 0.78, 0.52),
          width: 0.5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            message.isEmpty ? 'Sin mensaje de esperanza todavía.' : message,
            style: pw.TextStyle(
              fontSize: 11,
              lineSpacing: 2,
              color: message.isEmpty ? PdfColors.grey600 : PdfColors.grey900,
              fontStyle: message.isEmpty
                  ? pw.FontStyle.italic
                  : pw.FontStyle.normal,
            ),
            overflow: pw.TextOverflow.span,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Verso Principal',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor(0.72, 0.58, 0.20),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            mainReference.isEmpty
                ? 'Sin verso principal seleccionado.'
                : mainReference,
            style: pw.TextStyle(
              fontSize: 10.8,
              color: mainReference.isEmpty
                  ? PdfColors.grey600
                  : PdfColors.grey900,
              fontStyle: mainReference.isEmpty
                  ? pw.FontStyle.italic
                  : pw.FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _participantNotesBlock(StudyParticipantBundle participant) {
    final notes = participant.generalNotes.trim();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.98, 0.96, 0.90),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: const PdfColor(0.88, 0.78, 0.52),
          width: 0.5,
        ),
      ),
      child: pw.Text(
        notes.isEmpty
            ? 'Sin notas generales todavía.'
            : richNotePlainText(notes),
        style: pw.TextStyle(
          fontSize: 11,
          lineSpacing: 2,
          color: notes.isEmpty ? PdfColors.grey600 : PdfColors.grey900,
          fontStyle: notes.isEmpty ? pw.FontStyle.italic : pw.FontStyle.normal,
        ),
        overflow: pw.TextOverflow.span,
      ),
    );
  }

  List<BibleVerse> _selectedVerses(
    StudyChapterAnswers study,
    List<BibleVerse> chapterVerses,
  ) {
    if (study.rangedPassages.isNotEmpty) {
      return chapterVerses
          .where(
            (v) =>
                (study.primaryPassage == null &&
                    v.bookNumber == study.bookNumber &&
                    v.chapter == study.chapter) ||
                study.coversVerse(v.bookNumber, v.chapter, v.verse),
          )
          .toList(growable: false);
    }
    final start = study.studyStartVerse;
    final end = study.studyEndVerse;
    if (start == null || end == null) return chapterVerses;
    final lo = start < end ? start : end;
    final hi = start < end ? end : start;
    return chapterVerses
        .where((v) => v.verse >= lo && v.verse <= hi)
        .toList(growable: false);
  }

  BibleVerse? _secondaryForVerse(List<BibleVerse> verses, BibleVerse primary) {
    for (final verse in verses) {
      if (verse.bookNumber == primary.bookNumber &&
          verse.chapter == primary.chapter &&
          verse.verse == primary.verse) {
        return verse;
      }
    }
    return null;
  }

  /// Etiquetas de los pasajes estudiados: el principal (con rango si lo hay)
  /// más los pasajes añadidos.
  List<String> _passageLabels(StudyChapterAnswers study) {
    final labels = <String>[];
    final s = study.studyStartVerse;
    final e = study.studyEndVerse;
    if (s != null && e != null) {
      labels.add(
        s == e
            ? '${study.bookName} ${study.chapter}:$s'
            : '${study.bookName} ${study.chapter}:$s-$e',
      );
    } else {
      labels.add('${study.bookName} ${study.chapter}');
    }
    labels.addAll(study.additionalPassages.map((p) => p.reference));
    return labels;
  }

  /// Hoja de portada para el PDF de sala: participantes, versiones usadas y
  /// los pasajes estudiados (incluyendo los añadidos).
  pw.Page _roomCoverPage({
    required StudyChapterAnswers study,
    required List<StudyParticipantBundle> participants,
    required pw.ThemeData theme,
  }) {
    const gold = PdfColor(0.72, 0.58, 0.20);
    const ink = PdfColor(0.12, 0.16, 0.20);
    final passages = _passageLabels(study);
    final versionsUsed =
        <String>{
          for (final p in participants)
            if (p.currentVersionId.trim().isNotEmpty) p.currentVersionId,
          if (study.versionId.trim().isNotEmpty) study.versionId,
        }.toList()..sort();

    pw.Widget sectionLabel(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8, top: 18),
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.4,
          color: gold,
        ),
      ),
    );

    return pw.Page(
      pageTheme: pw.PageTheme(
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(48, 56, 48, 48),
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 56,
            height: 4,
            decoration: pw.BoxDecoration(
              color: gold,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(height: 22),
          pw.Text(
            'VICTORIA EN CRISTO',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 3,
              color: gold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Estudio en grupo',
            style: pw.TextStyle(
              fontSize: 32,
              fontWeight: pw.FontWeight.bold,
              color: ink,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            study.reference,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: gold,
            ),
          ),
          pw.Divider(color: const PdfColor(0.86, 0.82, 0.72), height: 36),
          sectionLabel('Pasajes estudiados'),
          for (final p in passages)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                '•  $p',
                style: const pw.TextStyle(fontSize: 13, color: ink),
              ),
            ),
          sectionLabel('Versiones usadas'),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in versionsUsed) _metaChip('Versión', v),
            ],
          ),
          sectionLabel('Participantes (${participants.length})'),
          for (final p in participants)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 6,
                    height: 6,
                    margin: const pw.EdgeInsets.only(right: 10),
                    decoration: const pw.BoxDecoration(
                      color: gold,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      p.displayName,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: ink,
                      ),
                    ),
                  ),
                  pw.Text(
                    p.currentVersionId,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
          pw.Spacer(),
          pw.Text(
            'Generado el ${_date(study.updatedAt)} · Victoria en Cristo',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _header(
    StudyChapterAnswers study, {
    String? secondaryVersionId,
    bool cleanCover = false,
  }) {
    final versions = secondaryVersionId == null
        ? study.versionId
        : '${study.versionId} + $secondaryVersionId';
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
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Estudio bíblico',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor(0.12, 0.16, 0.20),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              study.reference,
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor(0.72, 0.58, 0.20),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip('Versión principal', study.versionId),
                if (secondaryVersionId != null)
                  _metaChip('Versión secundaria', secondaryVersionId),
                _metaChip('Actualizado', _date(study.updatedAt)),
              ],
            ),
          ],
        ),
      );
    }
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
            'Versiones: $versions · Actualizado: ${_date(study.updatedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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
                fontSize: 10.3,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor(0.45, 0.36, 0.20),
              ),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(
                fontSize: 10.3,
                color: PdfColors.grey900,
              ),
            ),
          ],
        ),
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

  pw.Widget _versePairParagraph({
    required BibleVerse primary,
    required BibleVerse? secondary,
    required String? secondaryVersionId,
    required List<StudyWordHighlight> studyHighlights,
  }) {
    final primaryHighlights = _highlightsForVerse(studyHighlights, primary);
    final secondaryHighlights = secondary == null
        ? const <StudyWordHighlight>[]
        : _highlightsForVerse(studyHighlights, secondary);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            primary.version,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor(0.72, 0.58, 0.20),
            ),
          ),
          pw.SizedBox(height: 2),
          _highlightedVerseText(
            verse: primary,
            highlights: primaryHighlights,
            fontSize: 11.5,
            numberColor: const PdfColor(0.72, 0.58, 0.20),
            textColor: PdfColors.grey900,
          ),
          if (secondary != null && secondaryVersionId != null) ...[
            pw.SizedBox(height: 5),
            pw.Text(
              secondaryVersionId,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 2),
            _highlightedVerseText(
              verse: secondary,
              highlights: secondaryHighlights,
              fontSize: 10.8,
              numberColor: PdfColors.grey600,
              textColor: PdfColors.grey800,
            ),
          ],
        ],
      ),
    );
  }

  List<StudyWordHighlight> _highlightsForVerse(
    List<StudyWordHighlight> highlights,
    BibleVerse verse,
  ) {
    return highlights
        .where(
          (h) =>
              h.versionId == verse.version &&
              h.bookNumber == verse.bookNumber &&
              h.chapter == verse.chapter &&
              h.verse == verse.verse,
        )
        .toList(growable: false);
  }

  pw.Widget _highlightedVerseText({
    required BibleVerse verse,
    required List<StudyWordHighlight> highlights,
    required double fontSize,
    required PdfColor numberColor,
    required PdfColor textColor,
  }) {
    final tokens = verse.text
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    return pw.Wrap(
      runSpacing: 2,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(right: 3, bottom: 2),
          child: pw.Text(
            '${verse.verse}',
            style: pw.TextStyle(
              fontSize: fontSize * 0.78,
              fontWeight: pw.FontWeight.bold,
              color: numberColor,
            ),
          ),
        ),
        for (var i = 0; i < tokens.length; i++)
          _wordSpan(
            text: tokens[i],
            colors: _highlightColorsForWord(highlights, i),
            fontSize: fontSize,
            textColor: textColor,
          ),
      ],
    );
  }

  pw.Widget _wordSpan({
    required String text,
    required List<PdfColor> colors,
    required double fontSize,
    required PdfColor textColor,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      lineSpacing: 2,
      color: textColor,
    );
    final child = pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$text ', style: style),
        if (colors.isNotEmpty)
          pw.Container(
            width: (text.length * fontSize * 0.42).clamp(10.0, 58.0),
            height: 2,
            child: pw.Row(
              children: [
                for (final color in colors)
                  pw.Expanded(child: pw.Container(height: 2, color: color)),
              ],
            ),
          ),
      ],
    );
    if (colors.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(right: 1, bottom: 2),
        child: child,
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(right: 1, bottom: 2),
      padding: const pw.EdgeInsets.symmetric(horizontal: 1.5, vertical: 1),
      decoration: pw.BoxDecoration(
        color: colors.last,
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: child,
    );
  }

  List<PdfColor> _highlightColorsForWord(
    List<StudyWordHighlight> highlights,
    int wordIndex,
  ) {
    final colors = <PdfColor>[];
    for (final highlight in highlights) {
      if (highlight.overlapsWord(wordIndex)) {
        colors.add(_softPdfColor(highlight.codeEnum.colorHex));
      }
    }
    return colors;
  }

  PdfColor _softPdfColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    final rgb = clean.length == 6 ? clean : 'FFEE58';
    final red = int.parse(rgb.substring(0, 2), radix: 16) / 255;
    final green = int.parse(rgb.substring(2, 4), radix: 16) / 255;
    final blue = int.parse(rgb.substring(4, 6), radix: 16) / 255;
    const alpha = 0.34;
    double blend(double channel) => 1 - ((1 - channel) * alpha);
    return PdfColor(blend(red), blend(green), blend(blue));
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

  pw.Widget _generalNotes(StudyChapterAnswers study) {
    final notes = study.generalNotes.trim();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.98, 0.96, 0.90),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: const PdfColor(0.88, 0.78, 0.52),
          width: 0.5,
        ),
      ),
      child: notes.isEmpty
          ? _emptyText('Sin notas generales todavía.')
          : _formattedStudyText(notes),
    );
  }

  pw.Widget _hopeMessage(StudyChapterAnswers study) {
    final message = study.hopeMessage.trim();
    final mainReference = study.mainVerseReference;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.98, 0.96, 0.90),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: const PdfColor(0.88, 0.78, 0.52),
          width: 0.5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            message.isEmpty ? 'Sin mensaje de esperanza todavía.' : message,
            style: pw.TextStyle(
              fontSize: 11,
              lineSpacing: 2,
              color: message.isEmpty ? PdfColors.grey600 : PdfColors.grey900,
              fontStyle: message.isEmpty
                  ? pw.FontStyle.italic
                  : pw.FontStyle.normal,
            ),
            overflow: pw.TextOverflow.span,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Verso Principal',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor(0.72, 0.58, 0.20),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            mainReference.isEmpty
                ? 'Sin verso principal seleccionado.'
                : mainReference,
            style: pw.TextStyle(
              fontSize: 10.8,
              color: mainReference.isEmpty
                  ? PdfColors.grey600
                  : PdfColors.grey900,
              fontStyle: mainReference.isEmpty
                  ? pw.FontStyle.italic
                  : pw.FontStyle.normal,
            ),
          ),
        ],
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
                overflow: pw.TextOverflow.span,
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  List<pw.Widget> _roomReflection(List<StudyRoomAnswerSnapshot> snapshots) {
    final participants = [...snapshots]
      ..sort((a, b) => _participantName(a).compareTo(_participantName(b)));
    final widgets = <pw.Widget>[];
    for (final question in kStudyQuestions) {
      final answers = participants
          .map(
            (snapshot) =>
                MapEntry(snapshot, snapshot.answers[question.id]?.trim() ?? ''),
          )
          .where((entry) => entry.value.isNotEmpty)
          .toList(growable: false);
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: const PdfColor(0.98, 0.96, 0.90),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(
              color: const PdfColor(0.88, 0.78, 0.52),
              width: 0.5,
            ),
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
              pw.SizedBox(height: 6),
              if (answers.isEmpty)
                pw.Text(
                  'Sin respuestas compartidas todavía.',
                  style: pw.TextStyle(
                    fontSize: 10.8,
                    color: PdfColors.grey600,
                    fontStyle: pw.FontStyle.italic,
                  ),
                )
              else
                ...answers.map(
                  (entry) => _participantAnswer(entry.key, entry.value),
                ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  pw.Widget _participantAnswer(
    StudyRoomAnswerSnapshot snapshot,
    String answer,
  ) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${_participantName(snapshot)} · ${snapshot.versionId}',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor(0.72, 0.58, 0.20),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            answer,
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

  String _participantName(StudyRoomAnswerSnapshot snapshot) {
    final name = snapshot.displayName.trim();
    return name.isEmpty ? 'Compañero' : name;
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
