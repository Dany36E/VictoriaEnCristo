import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../theme/app_theme_data.dart';
import '../theme_service.dart';

/// Paleta y letras de los PDF de Apuntes y de Estudio.
///
/// Con el tema «papel recortado» el documento toma el estilo del kit
/// victoria-en-cristo-estilo: hoja crema, tinta café, terracota, cinta
/// mostaza, títulos en Lilita One y notas a mano en Caveat Brush. Con los
/// demás temas queda el estilo clásico dorado.
class EstiloPdf {
  EstiloPdf._({
    required this.papel,
    required this.tema,
    required this.titulo,
    required this.mano,
    required this.lectura,
    required this.lecturaCursiva,
    required this.acento,
    required this.tinta,
    required this.tintaSuave,
    required this.etiqueta,
    required this.cuerpo,
    required this.secundario,
    required this.tenue,
    required this.fondoTarjeta,
    required this.bordeTarjeta,
    required this.fondoDestacado,
    required this.bordeDestacado,
  });

  final bool papel;

  /// Letras del cuerpo (regular, negrita y cursiva).
  final pw.ThemeData tema;

  /// Títulos, referencias y etiquetas (Lilita One en papel).
  final pw.Font? titulo;

  /// Notas a mano (Caveat Brush en papel).
  final pw.Font? mano;

  /// Texto de los versículos (Lora en papel, como en la Biblia de la app);
  /// null usa la letra del cuerpo.
  final pw.Font? lectura;
  final pw.Font? lecturaCursiva;

  final PdfColor acento;
  final PdfColor tinta;
  final PdfColor tintaSuave;
  final PdfColor etiqueta;
  final PdfColor cuerpo;
  final PdfColor secundario;
  final PdfColor tenue;
  final PdfColor fondoTarjeta;
  final PdfColor bordeTarjeta;
  final PdfColor fondoDestacado;
  final PdfColor bordeDestacado;

  // Kit victoria-en-cristo-estilo (los mismos tonos de VecColores).
  static const _crema = PdfColor.fromInt(0xFFF3ECDF);
  static const _papel = PdfColor.fromInt(0xFFFBF7EE);
  static const _cremaOscuro = PdfColor.fromInt(0xFFEFE6D6);
  static const _tinta = PdfColor.fromInt(0xFF2B2622);
  static const _lapiz = PdfColor.fromInt(0xFF3A332C);
  static const _gris = PdfColor.fromInt(0xFF6F6150);
  static const _terracota = PdfColor.fromInt(0xFFA8452F);
  static const _mostaza = PdfColor.fromInt(0xFFE0A73A);
  static const _mostazaClaro = PdfColor.fromInt(0xFFEFC56A);
  static const _noche = PdfColor.fromInt(0xFF2F4A68);

  /// Color de la sombra sólida de las tarjetas de papel.
  static const sombraPapel = PdfColor.fromInt(0xFFD9CDB8);

  /// Fondo de la hoja en el tema papel (crema del kit).
  static const fondoPagina = _crema;

  /// ¿El tema activo de la app es papel?
  static bool get temaPapelActivo =>
      ThemeService().themeId == AppThemeData.paper.id;

  /// Carga las letras del estilo que corresponde al tema activo.
  static Future<EstiloPdf> cargar({bool? papel}) async {
    final esPapel = papel ?? temaPapelActivo;
    Future<pw.Font> fuente(String ruta) async =>
        pw.Font.ttf(await rootBundle.load(ruta));

    if (!esPapel) {
      return EstiloPdf._(
        papel: false,
        tema: pw.ThemeData.withFont(
          base: await fuente('google_fonts/Lato-Regular.ttf'),
          bold: await fuente('google_fonts/Lato-Bold.ttf'),
          italic: await fuente('google_fonts/Lato-Italic.ttf'),
        ),
        titulo: null,
        mano: null,
        lectura: null,
        lecturaCursiva: null,
        acento: const PdfColor(0.70, 0.58, 0.24),
        tinta: const PdfColor(0.20, 0.16, 0.10),
        tintaSuave: const PdfColor(0.34, 0.27, 0.16),
        etiqueta: const PdfColor(0.45, 0.36, 0.20),
        cuerpo: const PdfColor(0.17, 0.17, 0.18),
        secundario: PdfColors.grey700,
        tenue: PdfColors.grey600,
        fondoTarjeta: const PdfColor(0.985, 0.975, 0.955),
        bordeTarjeta: const PdfColor(0.88, 0.85, 0.77),
        fondoDestacado: const PdfColor(0.97, 0.95, 0.90),
        bordeDestacado: const PdfColor(0.86, 0.78, 0.58),
      );
    }

    // Cuerpo en Lato: es la única con negrita y cursiva de verdad (los
    // Lora-*.ttf del proyecto son la fuente variable y el PDF solo usa su
    // peso normal). Los versículos van en Lora, como en la Biblia de la app.
    return EstiloPdf._(
      papel: true,
      tema: pw.ThemeData.withFont(
        base: await fuente('google_fonts/Lato-Regular.ttf'),
        bold: await fuente('google_fonts/Lato-Bold.ttf'),
        italic: await fuente('google_fonts/Lato-Italic.ttf'),
      ),
      titulo: await fuente('assets/vec/fuentes/LilitaOne-Regular.ttf'),
      mano: await fuente('assets/vec/fuentes/CaveatBrush-Regular.ttf'),
      lectura: await fuente('google_fonts/Lora-Regular.ttf'),
      lecturaCursiva: await fuente('google_fonts/Lora-Italic.ttf'),
      acento: _terracota,
      tinta: _tinta,
      tintaSuave: _lapiz,
      etiqueta: _terracota,
      cuerpo: _tinta,
      secundario: _lapiz,
      tenue: _gris,
      fondoTarjeta: _papel,
      bordeTarjeta: _cremaOscuro,
      fondoDestacado: _papel,
      bordeDestacado: _mostaza,
    );
  }

  /// Estilo de títulos y referencias: Lilita One en papel, negrita si no.
  pw.TextStyle estiloTitulo({
    required double fontSize,
    PdfColor? color,
    double? lineSpacing,
    double? letterSpacing,
  }) {
    return pw.TextStyle(
      font: titulo,
      fontWeight: titulo == null ? pw.FontWeight.bold : null,
      fontSize: fontSize,
      color: color ?? tinta,
      lineSpacing: lineSpacing,
      letterSpacing: letterSpacing,
    );
  }

  /// Página con la hoja crema del papel y, desde la segunda, una cinta
  /// mostaza en la esquina superior derecha (la primera ya lleva la del
  /// encabezado). Va casi toda en el margen para no tapar títulos.
  pw.PageTheme pagina({required pw.EdgeInsets margin}) {
    return pw.PageTheme(
      margin: margin,
      theme: tema,
      buildBackground: !papel
          ? null
          : (context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Stack(
                children: [
                  pw.Container(color: _crema),
                  if (context.pageNumber > 1)
                    pw.Positioned(
                      right: -20,
                      top: -10,
                      child: cinta(ancho: 64, alto: 18, giro: 35),
                    ),
                ],
              ),
            ),
    );
  }

  /// Cinta adhesiva (washi tape) a rayas mostaza, como Cinta del kit.
  pw.Widget cinta({double ancho = 76, double alto = 22, double giro = -24}) {
    return pw.Transform.rotate(
      angle: giro * math.pi / 180,
      child: pw.ClipRect(
        child: pw.Container(
          width: ancho,
          height: alto,
          color: _mostaza,
          child: pw.Row(
            children: [
              for (var i = 0; i < (ancho / 10).ceil(); i++)
                pw.Container(
                  width: 10,
                  height: alto,
                  color: i.isEven ? _mostaza : _mostazaClaro,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta de papel con sombra sólida (en el estilo clásico, tarjeta con
  /// borde fino).
  pw.Widget tarjeta({
    required pw.Widget child,
    pw.EdgeInsets padding = const pw.EdgeInsets.fromLTRB(12, 9, 12, 10),
    pw.EdgeInsets margin = pw.EdgeInsets.zero,
    PdfColor? fondo,
    PdfColor? borde,
    PdfColor? franja,
    double radio = 7,
  }) {
    final caja = pw.Container(
      width: double.infinity,
      padding: padding,
      decoration: pw.BoxDecoration(
        color: fondo ?? fondoTarjeta,
        borderRadius: pw.BorderRadius.circular(radio),
        border: pw.Border.all(color: borde ?? bordeTarjeta, width: 0.6),
      ),
      child: child,
    );
    final conFranja = franja == null
        ? caja
        : pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(radio),
              color: franja,
            ),
            padding: const pw.EdgeInsets.only(left: 3.5),
            child: caja,
          );
    if (!papel) {
      return pw.Container(margin: margin, child: conFranja);
    }
    // Sombra sólida del papel grueso: una copia más oscura desplazada.
    return pw.Container(
      margin: margin,
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: pw.BoxDecoration(
        color: sombraPapel,
        borderRadius: pw.BorderRadius.circular(radio),
      ),
      child: conFranja,
    );
  }

  /// Título de sección: subrayado dorado en el clásico; en papel, Lilita One
  /// en terracota con una rayita mostaza.
  pw.Widget tituloSeccion(String texto) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          texto,
          style: papel
              ? estiloTitulo(fontSize: 16, color: acento)
              : pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: tintaSuave,
                ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: papel ? 46 : 38,
          height: papel ? 4 : 2.5,
          decoration: pw.BoxDecoration(
            color: papel ? _mostaza : acento,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  /// Pie de página con la marca y el número de página.
  pw.Widget pie(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Victoria en Cristo · Página ${context.pageNumber} de ${context.pagesCount}',
          style: papel
              ? estiloTitulo(fontSize: 9.5, color: tenue)
              : const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
    );
  }

  /// Pastilla de dato (Fecha: …, Predicador: …).
  pw.Widget dato(String etiquetaTexto, String valor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: papel ? _papel : PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(
          color: papel ? _cremaOscuro : const PdfColor(0.86, 0.82, 0.72),
          width: 0.6,
        ),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$etiquetaTexto: ',
              style: papel
                  ? estiloTitulo(fontSize: 10.5, color: etiqueta)
                  : pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      color: etiqueta,
                    ),
            ),
            pw.TextSpan(
              text: valor,
              style: pw.TextStyle(
                fontSize: 10.5,
                color: papel ? _tinta : PdfColors.grey900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hasta este largo una nota cabe con holgura en una página y puede ir en
  /// una sola pieza (renglones, título pegado). Más larga tiene que poder
  /// partirse entre páginas.
  static const largoEnUnaPieza = 900;

  /// Nota a mano sobre hoja rayada (estilo HojaRayada del kit) para la
  /// reflexión final; en el clásico, recuadro dorado en negrita.
  pw.Widget notaAMano(String texto) {
    if (!papel) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 11),
        decoration: pw.BoxDecoration(
          color: fondoDestacado,
          borderRadius: pw.BorderRadius.circular(7),
          border: pw.Border.all(color: bordeDestacado, width: 0.6),
        ),
        child: pw.Text(
          texto,
          style: pw.TextStyle(
            fontSize: 11.4,
            lineSpacing: 3.5,
            color: tinta,
            fontWeight: pw.FontWeight.bold,
          ),
          overflow: pw.TextOverflow.span,
        ),
      );
    }
    const renglon = 22.0;
    final letra = pw.Text(
      texto,
      style: pw.TextStyle(
        font: mano,
        fontSize: 15,
        lineSpacing: renglon - 15,
        color: _noche,
      ),
      overflow: pw.TextOverflow.span,
    );
    const relleno = pw.EdgeInsets.fromLTRB(16, 8, 16, 10);
    // Los renglones van en un Stack, que no se parte entre páginas.
    if (texto.length > largoEnUnaPieza) {
      return tarjeta(padding: relleno, child: letra);
    }
    return tarjeta(
      padding: relleno,
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.CustomPaint(
              // En el PDF la y crece hacia arriba: un renglón bajo cada línea
              // de texto, de arriba hacia abajo.
              painter: (canvas, size) {
                canvas.setStrokeColor(const PdfColor.fromInt(0xFFC9D2E3));
                canvas.setLineWidth(0.8);
                for (var y = size.y - renglon + 4; y > -1; y -= renglon) {
                  canvas.drawLine(0, y, size.x, y);
                }
                canvas.strokePath();
              },
            ),
          ),
          letra,
        ],
      ),
    );
  }
}
