import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../models/bible/bosquejo_sermon.dart';
import 'estilo_pdf.dart';
import 'pdf_file_writer.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BOSQUEJO EXPORT SERVICE
///
/// Exporta un bosquejo de sermón a Markdown (texto para compartir) y a PDF
/// con el estilo de papel de la app. Todo se arma en el teléfono: funciona
/// sin conexión (los versículos ya van guardados en el bosquejo).
/// ═══════════════════════════════════════════════════════════════════════════
class BosquejoExportService {
  BosquejoExportService._();
  static final BosquejoExportService I = BosquejoExportService._();

  /// Letra del subpunto: a, b, c… (y aa, ab… si hubiera más de 26).
  static String letraSubpunto(int indice) {
    const letras = 'abcdefghijklmnopqrstuvwxyz';
    if (indice < letras.length) return letras[indice];
    return '${letras[(indice ~/ letras.length) - 1]}${letras[indice % letras.length]}';
  }

  /// El bosquejo en Markdown.
  static String aMarkdown(BosquejoSermon b) {
    final out = StringBuffer();
    out.writeln('# ${b.tituloVisible}');
    if (b.textoPrincipal.trim().isNotEmpty) {
      out
        ..writeln()
        ..writeln('**Texto:** ${b.textoPrincipal.trim()}');
    }
    void seccion(String titulo, String texto) {
      if (texto.trim().isEmpty) return;
      out
        ..writeln()
        ..writeln('## $titulo')
        ..writeln()
        ..writeln(texto.trim());
    }

    void versiculos(List<VersiculoBosquejo> lista, {String sangria = ''}) {
      for (final v in lista) {
        final texto = v.texto.trim();
        out.writeln(
          texto.isEmpty
              ? '$sangria> ${v.referencia}'
              : '$sangria> ${v.referencia} — ${texto.replaceAll('\n', ' ')}',
        );
      }
    }

    seccion('Introducción', b.introduccion);
    for (var i = 0; i < b.puntos.length; i++) {
      final p = b.puntos[i];
      out
        ..writeln()
        ..writeln(
          '## ${i + 1}. ${p.titulo.trim().isEmpty ? 'Punto ${i + 1}' : p.titulo.trim()}',
        );
      if (p.notas.trim().isNotEmpty) {
        out
          ..writeln()
          ..writeln(p.notas.trim());
      }
      if (p.versiculos.isNotEmpty) {
        out.writeln();
        versiculos(p.versiculos);
      }
      if (p.subpuntos.isNotEmpty) out.writeln();
      for (var j = 0; j < p.subpuntos.length; j++) {
        final s = p.subpuntos[j];
        out.writeln('- ${letraSubpunto(j)}. ${s.texto.trim()}');
        if (s.versiculos.isNotEmpty) versiculos(s.versiculos, sangria: '  ');
      }
    }
    seccion('Ilustración', b.ilustracion);
    seccion('Conclusión', b.conclusion);
    return '${out.toString().trimRight()}\n';
  }

  /// Comparte el bosquejo como archivo `.md` (y el texto, para apps que no
  /// aceptan archivos).
  Future<void> compartirMarkdown(BosquejoSermon b) async {
    final texto = aMarkdown(b);
    try {
      final dir = await getTemporaryDirectory();
      final archivo = File('${dir.path}/${_nombreArchivo(b)}.md');
      await archivo.writeAsString(texto, flush: true);
      await Share.shareXFiles(
        [XFile(archivo.path, mimeType: 'text/markdown')],
        subject: b.tituloVisible,
        text: texto,
      );
    } catch (_) {
      await Share.share(texto, subject: b.tituloVisible);
    }
  }

  /// Crea el PDF. Con [guardarEnDescargas] lo deja en Descargas.
  Future<File> exportarPdf(
    BosquejoSermon b, {
    bool guardarEnDescargas = false,
  }) async {
    final e = await EstiloPdf.cargar();
    final doc = pw.Document(
      title: b.tituloVisible,
      author: 'Victoria en Cristo',
      creator: 'Victoria en Cristo',
    );

    pw.Widget cuerpo(String texto) => pw.Text(
      texto.trim(),
      style: pw.TextStyle(fontSize: 11, lineSpacing: 3.4, color: e.cuerpo),
      overflow: pw.TextOverflow.span,
    );

    pw.Widget versiculo(VersiculoBosquejo v) => e.tarjeta(
      margin: const pw.EdgeInsets.only(top: 6),
      franja: e.acento,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${v.referencia} (${v.versionId})',
            style: e.estiloTitulo(fontSize: 10.5, color: e.etiqueta),
          ),
          if (v.texto.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              v.texto.trim(),
              style: pw.TextStyle(
                font: e.lectura,
                fontSize: 10.5,
                lineSpacing: 3,
                color: e.cuerpo,
              ),
              overflow: pw.TextOverflow.span,
            ),
          ],
        ],
      ),
    );

    List<pw.Widget> seccion(String titulo, String texto) {
      if (texto.trim().isEmpty) return const [];
      return [
        pw.SizedBox(height: 16),
        e.tituloSeccion(titulo),
        pw.SizedBox(height: 8),
        cuerpo(texto),
      ];
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: e.pagina(
          margin: const pw.EdgeInsets.fromLTRB(38, 36, 38, 44),
        ),
        footer: e.pie,
        build: (_) => [
          pw.Stack(
            overflow: pw.Overflow.visible,
            children: [
              e.tarjeta(
                radio: 10,
                padding: const pw.EdgeInsets.all(18),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      b.tituloVisible,
                      style: e.estiloTitulo(fontSize: 22, lineSpacing: 3),
                    ),
                    if (b.textoPrincipal.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        b.textoPrincipal.trim(),
                        style: e.estiloTitulo(fontSize: 13, color: e.acento),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Positioned(right: -12, top: -10, child: e.cinta(giro: 22)),
            ],
          ),
          ...seccion('Introducción', b.introduccion),
          for (var i = 0; i < b.puntos.length; i++) ...[
            pw.SizedBox(height: 16),
            e.tituloSeccion(
              '${i + 1}. ${b.puntos[i].titulo.trim().isEmpty ? 'Punto ${i + 1}' : b.puntos[i].titulo.trim()}',
            ),
            if (b.puntos[i].notas.trim().isNotEmpty) ...[
              pw.SizedBox(height: 6),
              cuerpo(b.puntos[i].notas),
            ],
            for (final v in b.puntos[i].versiculos) versiculo(v),
            for (var j = 0; j < b.puntos[i].subpuntos.length; j++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 14, top: 7),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${letraSubpunto(j)}. ${b.puntos[i].subpuntos[j].texto.trim()}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        lineSpacing: 3,
                        color: e.cuerpo,
                      ),
                      overflow: pw.TextOverflow.span,
                    ),
                    for (final v in b.puntos[i].subpuntos[j].versiculos)
                      versiculo(v),
                  ],
                ),
              ),
          ],
          ...seccion('Ilustración', b.ilustracion),
          ...seccion('Conclusión', b.conclusion),
        ],
      ),
    );

    return PdfFileWriter.write(
      bytes: await doc.save(),
      fileName: '${_nombreArchivo(b)}.pdf',
      appSubfolder: 'exports',
      saveToDownloads: guardarEnDescargas,
    );
  }

  /// Crea el PDF y abre el menú de compartir.
  Future<File> compartirPdf(BosquejoSermon b) async {
    final archivo = await exportarPdf(b);
    await Share.shareXFiles(
      [XFile(archivo.path, mimeType: 'application/pdf')],
      subject: b.tituloVisible,
      text: b.tituloVisible,
    );
    return archivo;
  }

  static String _nombreArchivo(BosquejoSermon b) {
    final limpio = b.tituloVisible
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return limpio.isEmpty ? 'Bosquejo' : 'Bosquejo_$limpio';
  }
}
