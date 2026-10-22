import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;


/// Paleta y letras de los PDF de Apuntes y de Estudio.
///
/// Estilo «papel recortado» del kit victoria-en-cristo-estilo: hoja crema,
/// tinta café, terracota, cinta mostaza, títulos en Lilita One y notas a mano
/// en Caveat Brush. Siempre en el papel claro, aunque la app esté en un papel
/// oscuro: es un documento para imprimir o compartir.
class EstiloPdf {
  EstiloPdf._({
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
    this.ascensoMano = 0,
    this.altoMano = 0,
  });

  /// Medidas de la letra a mano en fracciones de su tamaño, como las usa el
  /// paquete pdf: de arriba de la línea a la base ([ascensoMano]) y alto de
  /// cada línea sin el interlineado ([altoMano]). Sirven para que los
  /// renglones de la hoja rayada caigan bajo cada línea escrita.
  final double ascensoMano;
  final double altoMano;

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

  /// Carga las letras del estilo.
  static Future<EstiloPdf> cargar() async {
    Future<pw.Font> fuente(String ruta) async =>
        pw.Font.ttf(await rootBundle.load(ruta));

    final datosMano = await rootBundle.load(
      'assets/vec/fuentes/CaveatBrush-Regular.ttf',
    );
    final medidasMano = TtfParser(datosMano);
    // Cuerpo en Lato: es la única con negrita y cursiva de verdad (los
    // Lora-*.ttf del proyecto son la fuente variable y el PDF solo usa su
    // peso normal). Los versículos van en Lora, como en la Biblia de la app.
    return EstiloPdf._(
      tema: pw.ThemeData.withFont(
        base: await fuente('google_fonts/Lato-Regular.ttf'),
        bold: await fuente('google_fonts/Lato-Bold.ttf'),
        italic: await fuente('google_fonts/Lato-Italic.ttf'),
      ),
      titulo: await fuente('assets/vec/fuentes/LilitaOne-Regular.ttf'),
      mano: pw.Font.ttf(datosMano),
      ascensoMano: medidasMano.ascent / medidasMano.unitsPerEm,
      altoMano:
          (medidasMano.ascent - medidasMano.descent) / medidasMano.unitsPerEm,
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
      buildBackground: (context) => pw.FullPage(
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
          style: estiloTitulo(fontSize: 16, color: acento),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: 46,
          height: 4,
          decoration: pw.BoxDecoration(
            color: _mostaza,
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
          style: estiloTitulo(fontSize: 9.5, color: tenue),
        ),
      ),
    );
  }

  /// Pastilla de dato (Fecha: …, Predicador: …).
  pw.Widget dato(String etiquetaTexto, String valor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _papel,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(
          color: _cremaOscuro,
          width: 0.6,
        ),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$etiquetaTexto: ',
              style: estiloTitulo(fontSize: 10.5, color: etiqueta),
            ),
            pw.TextSpan(
              text: valor,
              style: const pw.TextStyle(
                fontSize: 10.5,
                color: _tinta,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Si [texto] cabe con holgura en una página y puede ir en una sola pieza
  /// (renglones, título pegado). Si no, tiene que poder partirse entre
  /// páginas. Se cuentan las líneas a lo mucho 45 caracteres cada una, de
  /// más para que nunca se quede corto: 18 líneas de nota a mano miden unos
  /// 450 pt de los ~760 de la página.
  static bool cabeEnUnaPieza(String texto) {
    var lineas = 0;
    for (final parrafo in texto.split('\n')) {
      lineas += math.max(1, (parrafo.length / 45).ceil());
    }
    return lineas <= 18;
  }

  /// Nota a mano sobre hoja rayada (estilo HojaRayada del kit) para la
  /// reflexión final; en el clásico, recuadro dorado en negrita.
  pw.Widget notaAMano(String texto) {
    
    const tamano = 15.0;
    const interlineado = 6.0;
    final letra = pw.Text(
      texto,
      style: pw.TextStyle(
        font: mano,
        fontSize: tamano,
        lineSpacing: interlineado,
        color: _noche,
      ),
      overflow: pw.TextOverflow.span,
    );
    const relleno = pw.EdgeInsets.fromLTRB(16, 8, 16, 10);
    // Los renglones van en un Stack, que no se parte entre páginas.
    if (!cabeEnUnaPieza(texto)) {
      return tarjeta(padding: relleno, child: letra);
    }
    // Cada línea escrita baja su alto más el interlineado; el renglón va un
    // poco debajo de la base de cada una.
    final avance = altoMano * tamano + interlineado;
    final primeraBase = ascensoMano * tamano + 2;
    return tarjeta(
      padding: relleno,
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.CustomPaint(
              // En el PDF la y crece hacia arriba: se mide desde arriba y se
              // voltea.
              painter: (canvas, size) {
                canvas.setStrokeColor(const PdfColor.fromInt(0xFFC9D2E3));
                canvas.setLineWidth(0.8);
                for (var y = primeraBase; y < size.y; y += avance) {
                  canvas.drawLine(0, size.y - y, size.x, size.y - y);
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
