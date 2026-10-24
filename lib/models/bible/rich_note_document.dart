import 'dart:convert';

import 'study_note_markup.dart';

enum RichNoteFormat { bold, underline, size, italic, strike, highlight, color }

/// Estilos de párrafo, como en Notas: se aplican a la línea completa.
enum RichNoteParagraphStyle { title, heading, subheading, body }

/// Colores de resaltado y de texto. Se guardan por nombre para que el tema
/// decida el tono exacto.
const List<String> richNoteHighlightColors = [
  'amarillo',
  'verde',
  'azul',
  'rosa',
  'naranja',
];
const List<String> richNoteTextColors = [
  'terracota',
  'azul',
  'verde',
  'mostaza',
  'morado',
  'gris',
];

/// Estado de formato "efectivo" de una seleccion (o del caret). Lo usa la barra
/// flotante para reflejar de forma inteligente —como Word— si el texto elegido
/// esta en negrita/subrayado y que tamaño tiene, mostrando el valor actual antes
/// de subirlo o bajarlo.
class RichNoteFormatState {
  final bool bold;
  final bool underline;
  final bool italic;
  final bool strike;
  final double? fontSize;
  final String? highlight;
  final String? color;

  const RichNoteFormatState({
    this.bold = false,
    this.underline = false,
    this.italic = false,
    this.strike = false,
    this.fontSize,
    this.highlight,
    this.color,
  });

  bool has(RichNoteFormat format) => switch (format) {
    RichNoteFormat.bold => bold,
    RichNoteFormat.underline => underline,
    RichNoteFormat.italic => italic,
    RichNoteFormat.strike => strike,
    RichNoteFormat.size => fontSize != null,
    RichNoteFormat.highlight => highlight != null,
    RichNoteFormat.color => color != null,
  };
}

class RichNoteTextSegment {
  final String text;
  final bool bold;
  final bool underline;
  final bool italic;
  final bool strike;
  final double? fontSize;
  final String? highlight;
  final String? color;

  const RichNoteTextSegment({
    required this.text,
    this.bold = false,
    this.underline = false,
    this.italic = false,
    this.strike = false,
    this.fontSize,
    this.highlight,
    this.color,
  });

  bool sameStyle(RichNoteTextSegment o) =>
      bold == o.bold &&
      underline == o.underline &&
      italic == o.italic &&
      strike == o.strike &&
      fontSize == o.fontSize &&
      highlight == o.highlight &&
      color == o.color;

  RichNoteTextSegment copyWith({String? text}) => RichNoteTextSegment(
    text: text ?? this.text,
    bold: bold,
    underline: underline,
    italic: italic,
    strike: strike,
    fontSize: fontSize,
    highlight: highlight,
    color: color,
  );
}

class RichNoteSpan {
  final int start;
  final int end;
  final bool bold;
  final bool underline;
  final bool italic;
  final bool strike;
  final double? fontSize;
  final String? highlight;
  final String? color;

  const RichNoteSpan({
    required this.start,
    required this.end,
    this.bold = false,
    this.underline = false,
    this.italic = false,
    this.strike = false,
    this.fontSize,
    this.highlight,
    this.color,
  });

  bool get hasFormatting =>
      bold ||
      underline ||
      italic ||
      strike ||
      fontSize != null ||
      highlight != null ||
      color != null;

  bool has(RichNoteFormat format) => switch (format) {
    RichNoteFormat.bold => bold,
    RichNoteFormat.underline => underline,
    RichNoteFormat.italic => italic,
    RichNoteFormat.strike => strike,
    RichNoteFormat.size => fontSize != null,
    RichNoteFormat.highlight => highlight != null,
    RichNoteFormat.color => color != null,
  };

  RichNoteSpan copyWith({
    int? start,
    int? end,
    bool? bold,
    bool? underline,
    bool? italic,
    bool? strike,
    double? fontSize,
  }) {
    return RichNoteSpan(
      start: start ?? this.start,
      end: end ?? this.end,
      bold: bold ?? this.bold,
      underline: underline ?? this.underline,
      italic: italic ?? this.italic,
      strike: strike ?? this.strike,
      fontSize: fontSize ?? this.fontSize,
      highlight: highlight,
      color: color,
    );
  }

  /// La misma porción sin [format].
  RichNoteSpan without(RichNoteFormat format) => RichNoteSpan(
    start: start,
    end: end,
    bold: format == RichNoteFormat.bold ? false : bold,
    underline: format == RichNoteFormat.underline ? false : underline,
    italic: format == RichNoteFormat.italic ? false : italic,
    strike: format == RichNoteFormat.strike ? false : strike,
    fontSize: format == RichNoteFormat.size ? null : fontSize,
    highlight: format == RichNoteFormat.highlight ? null : highlight,
    color: format == RichNoteFormat.color ? null : color,
  );

  Map<String, dynamic> toMap() => {
    'start': start,
    'end': end,
    if (bold) 'bold': true,
    if (underline) 'underline': true,
    if (italic) 'italic': true,
    if (strike) 'strike': true,
    if (fontSize != null) 'fontSize': fontSize,
    if (highlight != null) 'highlight': highlight,
    if (color != null) 'color': color,
  };

  factory RichNoteSpan.fromMap(Map<String, dynamic> map) {
    return RichNoteSpan(
      start: _asInt(map['start']),
      end: _asInt(map['end']),
      bold: map['bold'] == true,
      underline: map['underline'] == true,
      italic: map['italic'] == true,
      strike: map['strike'] == true,
      fontSize: (map['fontSize'] as num?)?.toDouble(),
      highlight: richNoteHighlightColors.contains(map['highlight'])
          ? map['highlight'] as String
          : null,
      color: richNoteTextColors.contains(map['color'])
          ? map['color'] as String
          : null,
    );
  }
}

/// Carácter que ocupa el lugar de una foto o un dibujo dentro del texto
/// (U+FFFC, «object replacement character»). Cada uno es un solo carácter,
/// así que el cursor y la selección funcionan igual que con letras.
const String kMarcaAdjunto = '\uFFFC';

/// Un trozo de la nota en orden: texto con formato o un adjunto en línea.
class RichNoteBloque {
  final List<RichNoteTextSegment> segmentos;

  /// Id del adjunto (foto o dibujo) que va en este lugar; null si es texto.
  final String? adjuntoId;

  const RichNoteBloque.texto(this.segmentos) : adjuntoId = null;
  const RichNoteBloque.adjunto(String id) : segmentos = const [], adjuntoId = id;

  bool get esAdjunto => adjuntoId != null;
}

class RichNoteDocument {
  static const _storageKind = 'victoria_rich_note_v1';

  final String text;
  final List<RichNoteSpan> spans;

  /// Ids de los adjuntos en línea: el i-ésimo [kMarcaAdjunto] del texto es
  /// `embeds[i]`. Las notas antiguas no tienen ninguno (sus fotos se ven al
  /// final, como antes). Un id vacío es una marca sin adjunto (se ignora).
  final List<String> embeds;

  const RichNoteDocument({
    required this.text,
    required this.spans,
    this.embeds = const [],
  });

  factory RichNoteDocument.empty() {
    return const RichNoteDocument(text: '', spans: <RichNoteSpan>[]);
  }

  factory RichNoteDocument.fromStorage(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return RichNoteDocument.empty();
    final decoded = _tryDecodeMap(trimmed);
    if (decoded != null && decoded['kind'] == _storageKind) {
      final text = decoded['text'] as String? ?? '';
      final spans = (decoded['spans'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((map) => RichNoteSpan.fromMap(Map<String, dynamic>.from(map)))
          .toList(growable: false);
      final embeds = [
        for (final e in decoded['embeds'] as List<dynamic>? ?? const [])
          e is String ? e : '',
      ];
      return RichNoteDocument(
        text: text,
        spans: _clampSpans(spans, text.length),
        embeds: _ajustarEmbeds(embeds, text),
      );
    }
    return _fromLegacyMarkup(source);
  }

  static RichNoteDocument _fromLegacyMarkup(String source) {
    final legacySegments = parseStudyNoteMarkup(source);
    final buffer = StringBuffer();
    final spans = <RichNoteSpan>[];
    var offset = 0;
    for (final segment in legacySegments) {
      buffer.write(segment.text);
      final nextOffset = offset + segment.text.length;
      if (segment.text.isNotEmpty &&
          (segment.bold || segment.underline || segment.fontSize != null)) {
        spans.add(
          RichNoteSpan(
            start: offset,
            end: nextOffset,
            bold: segment.bold,
            underline: segment.underline,
            fontSize: segment.fontSize,
          ),
        );
      }
      offset = nextOffset;
    }
    final text = buffer.toString();
    if (text == source && spans.isEmpty) {
      return RichNoteDocument(text: source, spans: const []);
    }
    return RichNoteDocument(text: text, spans: spans);
  }

  String toStorage() {
    return jsonEncode({
      'kind': _storageKind,
      'text': text,
      'spans': [for (final span in spans) span.toMap()],
      if (embeds.any((e) => e.isNotEmpty)) 'embeds': embeds,
    });
  }

  RichNoteDocument copyWith({
    String? text,
    List<RichNoteSpan>? spans,
    List<String>? embeds,
  }) {
    final nextText = text ?? this.text;
    return RichNoteDocument(
      text: nextText,
      spans: _clampSpans(spans ?? this.spans, nextText.length),
      embeds: _ajustarEmbeds(embeds ?? this.embeds, nextText),
    );
  }

  /// Ids de los adjuntos que están dentro del texto, en orden.
  List<String> get idsEnLinea => [
    for (final e in embeds)
      if (e.isNotEmpty) e,
  ];

  /// Texto sin las marcas de los adjuntos (vistas previas, búsqueda).
  String get textoPlano => text.replaceAll(kMarcaAdjunto, '');

  /// Inserta el adjunto [id] en [offset], en su propia línea, para poder
  /// seguir escribiendo debajo (p. ej. la foto de una diapositiva y luego los
  /// comentarios). Devuelve el documento y dónde queda el cursor.
  (RichNoteDocument, int) insertarAdjunto(int offset, String id) {
    final pos = offset < 0 || offset > text.length ? text.length : offset;
    final antes = pos > 0 && text[pos - 1] != '\n' ? '\n' : '';
    final siguienteEsSalto = pos < text.length && text[pos] == '\n';
    final despues = siguienteEsSalto ? '' : '\n';
    final insercion = '$antes$kMarcaAdjunto$despues';
    final nuevoTexto = text.replaceRange(pos, pos, insercion);
    final indice = _contarMarcas(text, pos);
    final nuevosEmbeds = [..._ajustarEmbeds(embeds, text)]..insert(indice, id);
    final movido = replaceText(nuevoTexto);
    final cursor = pos + insercion.length + (siguienteEsSalto ? 1 : 0);
    return (
      RichNoteDocument(
        text: nuevoTexto,
        spans: movido.spans,
        embeds: nuevosEmbeds,
      ),
      cursor.clamp(0, nuevoTexto.length),
    );
  }

  /// Quita del texto la marca del adjunto [id] (y el salto de línea que se
  /// agregó con ella). El adjunto en sí no se toca.
  RichNoteDocument quitarAdjunto(String id) {
    final i = embeds.indexOf(id);
    if (i < 0) return this;
    var pos = -1;
    for (var n = 0; n <= i; n++) {
      pos = text.indexOf(kMarcaAdjunto, pos + 1);
      if (pos < 0) return this;
    }
    var fin = pos + 1;
    if (fin < text.length && text[fin] == '\n') fin++;
    final nuevoTexto = text.replaceRange(pos, fin, '');
    final movido = replaceText(nuevoTexto);
    return RichNoteDocument(
      text: nuevoTexto,
      spans: movido.spans,
      embeds: [...embeds]..removeAt(i),
    );
  }

  /// La nota en orden: trozos de texto y adjuntos en línea.
  List<RichNoteBloque> bloques() {
    final bloques = <RichNoteBloque>[];
    var actual = <RichNoteTextSegment>[];
    var indice = 0;
    for (final segmento in toSegments()) {
      final partes = segmento.text.split(kMarcaAdjunto);
      for (var i = 0; i < partes.length; i++) {
        if (i > 0) {
          final id = indice < embeds.length ? embeds[indice] : '';
          indice++;
          if (id.isNotEmpty) {
            if (actual.isNotEmpty) bloques.add(RichNoteBloque.texto(actual));
            actual = <RichNoteTextSegment>[];
            bloques.add(RichNoteBloque.adjunto(id));
          }
        }
        if (partes[i].isNotEmpty) actual.add(segmento.copyWith(text: partes[i]));
      }
    }
    if (actual.isNotEmpty) bloques.add(RichNoteBloque.texto(actual));
    return bloques;
  }

  /// Aplica un formato al rango, como en Notas:
  /// - negrita, cursiva, subrayado y tachado se alternan (si todo el rango ya
  ///   lo tiene, se quita);
  /// - tamaño, resaltado y color se reemplazan; con valor null se quitan.
  RichNoteDocument applyFormat(
    int start,
    int end,
    RichNoteFormat format, {
    double? fontSize,
    String? value,
  }) {
    final lo = start.clamp(0, text.length);
    final hi = end.clamp(lo, text.length);
    if (lo == hi) return this;
    final cleared = _clearInRange(lo, hi, format);
    final RichNoteSpan? added = switch (format) {
      RichNoteFormat.bold ||
      RichNoteFormat.underline ||
      RichNoteFormat.italic ||
      RichNoteFormat.strike => formatIn(lo, hi).has(format)
          ? null
          : RichNoteSpan(
              start: lo,
              end: hi,
              bold: format == RichNoteFormat.bold,
              underline: format == RichNoteFormat.underline,
              italic: format == RichNoteFormat.italic,
              strike: format == RichNoteFormat.strike,
            ),
      RichNoteFormat.size =>
        fontSize == null
            ? null
            : RichNoteSpan(
                start: lo,
                end: hi,
                fontSize: fontSize.clamp(10, 28).toDouble(),
              ),
      RichNoteFormat.highlight =>
        value == null ? null : RichNoteSpan(start: lo, end: hi, highlight: value),
      RichNoteFormat.color =>
        value == null ? null : RichNoteSpan(start: lo, end: hi, color: value),
    };
    return copyWith(spans: [...cleared, ?added]);
  }

  /// Estilo de párrafo sobre las líneas completas que toca el rango.
  RichNoteDocument applyParagraphStyle(
    int start,
    int end,
    RichNoteParagraphStyle style,
  ) {
    if (text.isEmpty) return this;
    final inicio = start.clamp(0, text.length);
    final from = inicio == 0 ? 0 : text.lastIndexOf('\n', inicio - 1) + 1;
    final next = text.indexOf('\n', end.clamp(inicio, text.length));
    final hi = next == -1 ? text.length : next;
    if (from >= hi) return this;
    var spans = _clearInRange(from, hi, RichNoteFormat.size);
    spans = RichNoteDocument(text: text, spans: spans)
        ._clearInRange(from, hi, RichNoteFormat.bold);
    final size = switch (style) {
      RichNoteParagraphStyle.title => 24.0,
      RichNoteParagraphStyle.heading => 20.0,
      RichNoteParagraphStyle.subheading => 17.0,
      RichNoteParagraphStyle.body => null,
    };
    return copyWith(
      spans: [
        ...spans,
        if (size != null)
          RichNoteSpan(start: from, end: hi, bold: true, fontSize: size),
      ],
    );
  }

  /// Spans sin [format] dentro de [lo, hi); fuera del rango no cambian.
  List<RichNoteSpan> _clearInRange(int lo, int hi, RichNoteFormat format) {
    final out = <RichNoteSpan>[];
    for (final span in spans) {
      if (!span.has(format) || span.end <= lo || span.start >= hi) {
        out.add(span);
        continue;
      }
      if (span.start < lo) out.add(span.copyWith(end: lo));
      out.add(
        span
            .without(format)
            .copyWith(
              start: span.start < lo ? lo : span.start,
              end: span.end > hi ? hi : span.end,
            ),
      );
      if (span.end > hi) out.add(span.copyWith(start: hi));
    }
    return out;
  }

  RichNoteDocument replaceText(String newText) {
    if (newText == text) return this;
    final change = _computeTextChange(text, newText);
    // Adjuntos en línea: los de antes del cambio se quedan, los del tramo
    // borrado salen (el adjunto pasa a verse al final de la nota, no se
    // pierde) y las marcas pegadas desde fuera no tienen adjunto.
    final previos = _ajustarEmbeds(embeds, text);
    final antes = _contarMarcas(text, change.start);
    final borradas = _contarMarcas(text, change.oldEnd) - antes;
    final insertadas = _contarMarcas(
      newText.substring(change.start, change.start + change.insertedLength),
      change.insertedLength,
    );
    final nuevosEmbeds = [
      ...previos.take(antes),
      for (var i = 0; i < insertadas; i++) '',
      ...previos.skip(antes + borradas),
    ];
    final nextSpans = <RichNoteSpan>[];
    for (final span in spans) {
      final adjusted = _adjustSpanForEdit(
        span,
        changeStart: change.start,
        oldEnd: change.oldEnd,
        insertedLength: change.insertedLength,
      );
      if (adjusted != null) nextSpans.add(adjusted);
    }
    return RichNoteDocument(
      text: newText,
      spans: _clampSpans(nextSpans, newText.length),
      embeds: _ajustarEmbeds(nuevosEmbeds, newText),
    );
  }

  /// Formato efectivo de un rango. Si el rango es un caret (colapsado) hereda
  /// el formato del caracter a la izquierda, tal como el cursor de Word toma el
  /// estilo del texto que le precede. Para una seleccion real, los formatos
  /// solo se consideran activos si el rango entero los tiene, y el tamaño,
  /// el resaltado y el color solo se reportan si son uniformes.
  RichNoteFormatState formatIn(int start, int end) {
    if (text.isEmpty) return const RichNoteFormatState();
    final lo = start.clamp(0, text.length);
    final hi = end.clamp(lo, text.length);
    if (lo == hi) {
      if (lo == 0) return const RichNoteFormatState();
      return _effectiveAt(lo - 1);
    }
    final first = _effectiveAt(lo);
    var bold = first.bold, underline = first.underline;
    var italic = first.italic, strike = first.strike;
    double? size = first.fontSize;
    String? highlight = first.highlight, color = first.color;
    for (var pos = lo + 1; pos < hi; pos++) {
      final f = _effectiveAt(pos);
      bold = bold && f.bold;
      underline = underline && f.underline;
      italic = italic && f.italic;
      strike = strike && f.strike;
      if (f.fontSize != size) size = null;
      if (f.highlight != highlight) highlight = null;
      if (f.color != color) color = null;
    }
    return RichNoteFormatState(
      bold: bold,
      underline: underline,
      italic: italic,
      strike: strike,
      fontSize: size,
      highlight: highlight,
      color: color,
    );
  }

  RichNoteFormatState _effectiveAt(int pos) {
    var bold = false, underline = false, italic = false, strike = false;
    double? fontSize;
    String? highlight, color;
    for (final span in spans) {
      if (pos >= span.start && pos < span.end) {
        bold = bold || span.bold;
        underline = underline || span.underline;
        italic = italic || span.italic;
        strike = strike || span.strike;
        if (span.fontSize != null) fontSize = span.fontSize;
        if (span.highlight != null) highlight = span.highlight;
        if (span.color != null) color = span.color;
      }
    }
    return RichNoteFormatState(
      bold: bold,
      underline: underline,
      italic: italic,
      strike: strike,
      fontSize: fontSize,
      highlight: highlight,
      color: color,
    );
  }

  List<RichNoteTextSegment> toSegments() {
    if (text.isEmpty) return const [];
    final breakpoints = <int>{0, text.length};
    for (final span in spans) {
      breakpoints.add(span.start.clamp(0, text.length));
      breakpoints.add(span.end.clamp(0, text.length));
    }
    final points = breakpoints.toList()..sort();
    final segments = <RichNoteTextSegment>[];
    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      if (start >= end) continue;
      final f = _effectiveAt(start);
      final piece = text.substring(start, end);
      if (piece.isEmpty) continue;
      final nextSegment = RichNoteTextSegment(
        text: piece,
        bold: f.bold,
        underline: f.underline,
        italic: f.italic,
        strike: f.strike,
        fontSize: f.fontSize,
        highlight: f.highlight,
        color: f.color,
      );
      if (segments.isNotEmpty && segments.last.sameStyle(nextSegment)) {
        segments[segments.length - 1] = segments.last.copyWith(
          text: segments.last.text + piece,
        );
        continue;
      }
      segments.add(nextSegment);
    }
    return segments;
  }
}

String richNotePlainText(String source) {
  return RichNoteDocument.fromStorage(source).textoPlano;
}

int _contarMarcas(String text, int hasta) {
  var n = 0;
  final fin = hasta.clamp(0, text.length);
  for (var i = 0; i < fin; i++) {
    if (text.codeUnitAt(i) == 0xFFFC) n++;
  }
  return n;
}

/// Deja tantos ids como marcas haya en [text] (vacíos si faltan).
List<String> _ajustarEmbeds(List<String> embeds, String text) {
  final marcas = _contarMarcas(text, text.length);
  if (marcas == 0) return const [];
  if (embeds.length == marcas) return List.unmodifiable(embeds);
  return List.unmodifiable([
    for (var i = 0; i < marcas; i++) i < embeds.length ? embeds[i] : '',
  ]);
}

List<RichNoteTextSegment> richNoteSegments(String source) {
  return RichNoteDocument.fromStorage(source).toSegments();
}

Map<String, dynamic>? _tryDecodeMap(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {
    return null;
  }
  return null;
}

List<RichNoteSpan> _clampSpans(List<RichNoteSpan> spans, int maxLength) {
  final clamped = <RichNoteSpan>[];
  for (final span in spans) {
    final start = span.start.clamp(0, maxLength);
    final end = span.end.clamp(0, maxLength);
    if (start >= end || !span.hasFormatting) continue;
    clamped.add(
      span.copyWith(
        start: start,
        end: end,
        fontSize: span.fontSize?.clamp(10, 28).toDouble(),
      ),
    );
  }
  return List<RichNoteSpan>.unmodifiable(clamped);
}

_TextChange _computeTextChange(String oldText, String newText) {
  var prefix = 0;
  final maxPrefix = oldText.length < newText.length
      ? oldText.length
      : newText.length;
  while (prefix < maxPrefix &&
      oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
    prefix++;
  }

  var suffix = 0;
  while (suffix < oldText.length - prefix &&
      suffix < newText.length - prefix &&
      oldText.codeUnitAt(oldText.length - 1 - suffix) ==
          newText.codeUnitAt(newText.length - 1 - suffix)) {
    suffix++;
  }

  return _TextChange(
    start: prefix,
    oldEnd: oldText.length - suffix,
    insertedLength: newText.length - prefix - suffix,
  );
}

RichNoteSpan? _adjustSpanForEdit(
  RichNoteSpan span, {
  required int changeStart,
  required int oldEnd,
  required int insertedLength,
}) {
  final delta = insertedLength - (oldEnd - changeStart);
  // Al escribir JUSTO al final de un span con formato (cursor en span.end),
  // los caracteres nuevos deben heredar ese formato —como en Word— en lugar
  // de volver al estilo estandar. Por eso usamos `<` en vez de `<=`: una
  // insercion exactamente en el borde final extiende el span.
  if (span.end < changeStart) return span;
  if (span.start >= oldEnd) {
    return span.copyWith(start: span.start + delta, end: span.end + delta);
  }

  final keptBeforeLength = changeStart > span.start
      ? changeStart - span.start
      : 0;
  final keptAfterLength = span.end > oldEnd ? span.end - oldEnd : 0;
  final inheritsInsertedText =
      insertedLength > 0 &&
      ((changeStart >= span.start && changeStart <= span.end) ||
          (changeStart <= span.start && oldEnd >= span.end));

  int? newStart;
  if (keptBeforeLength > 0) {
    newStart = span.start;
  } else if (inheritsInsertedText) {
    newStart = changeStart;
  } else if (keptAfterLength > 0) {
    newStart = changeStart + insertedLength;
  }
  if (newStart == null) return null;

  final newLength =
      keptBeforeLength +
      keptAfterLength +
      (inheritsInsertedText ? insertedLength : 0);
  if (newLength <= 0) return null;
  return span.copyWith(start: newStart, end: newStart + newLength);
}

class _TextChange {
  final int start;
  final int oldEnd;
  final int insertedLength;

  const _TextChange({
    required this.start,
    required this.oldEnd,
    required this.insertedLength,
  });
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
