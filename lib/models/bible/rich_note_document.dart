import 'dart:convert';

import 'study_note_markup.dart';

enum RichNoteFormat { bold, underline, size }

/// Estado de formato "efectivo" de una seleccion (o del caret). Lo usa la barra
/// flotante para reflejar de forma inteligente —como Word— si el texto elegido
/// esta en negrita/subrayado y que tamaño tiene, mostrando el valor actual antes
/// de subirlo o bajarlo.
class RichNoteFormatState {
  final bool bold;
  final bool underline;
  final double? fontSize;

  const RichNoteFormatState({
    this.bold = false,
    this.underline = false,
    this.fontSize,
  });
}

class RichNoteTextSegment {
  final String text;
  final bool bold;
  final bool underline;
  final double? fontSize;

  const RichNoteTextSegment({
    required this.text,
    this.bold = false,
    this.underline = false,
    this.fontSize,
  });

  RichNoteTextSegment copyWith({
    String? text,
    bool? bold,
    bool? underline,
    double? fontSize,
  }) {
    return RichNoteTextSegment(
      text: text ?? this.text,
      bold: bold ?? this.bold,
      underline: underline ?? this.underline,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

class RichNoteSpan {
  final int start;
  final int end;
  final bool bold;
  final bool underline;
  final double? fontSize;

  const RichNoteSpan({
    required this.start,
    required this.end,
    this.bold = false,
    this.underline = false,
    this.fontSize,
  });

  bool get hasFormatting => bold || underline || fontSize != null;

  RichNoteSpan copyWith({
    int? start,
    int? end,
    bool? bold,
    bool? underline,
    double? fontSize,
  }) {
    return RichNoteSpan(
      start: start ?? this.start,
      end: end ?? this.end,
      bold: bold ?? this.bold,
      underline: underline ?? this.underline,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  Map<String, dynamic> toMap() => {
    'start': start,
    'end': end,
    if (bold) 'bold': true,
    if (underline) 'underline': true,
    if (fontSize != null) 'fontSize': fontSize,
  };

  factory RichNoteSpan.fromMap(Map<String, dynamic> map) {
    return RichNoteSpan(
      start: _asInt(map['start']),
      end: _asInt(map['end']),
      bold: map['bold'] == true,
      underline: map['underline'] == true,
      fontSize: (map['fontSize'] as num?)?.toDouble(),
    );
  }
}

class RichNoteDocument {
  static const _storageKind = 'victoria_rich_note_v1';

  final String text;
  final List<RichNoteSpan> spans;

  const RichNoteDocument({required this.text, required this.spans});

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
      return RichNoteDocument(
        text: text,
        spans: _clampSpans(spans, text.length),
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
    });
  }

  RichNoteDocument copyWith({String? text, List<RichNoteSpan>? spans}) {
    final nextText = text ?? this.text;
    return RichNoteDocument(
      text: nextText,
      spans: _clampSpans(spans ?? this.spans, nextText.length),
    );
  }

  RichNoteDocument applyFormat(
    int start,
    int end,
    RichNoteFormat format, {
    double? fontSize,
  }) {
    final lo = start.clamp(0, text.length);
    final hi = end.clamp(lo, text.length);
    if (lo == hi) return this;
    return copyWith(
      spans: [
        ...spans,
        RichNoteSpan(
          start: lo,
          end: hi,
          bold: format == RichNoteFormat.bold,
          underline: format == RichNoteFormat.underline,
          fontSize: format == RichNoteFormat.size
              ? (fontSize ?? 16).clamp(10, 28).toDouble()
              : null,
        ),
      ],
    );
  }

  RichNoteDocument replaceText(String newText) {
    if (newText == text) return this;
    final change = _computeTextChange(text, newText);
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
    );
  }

  /// Formato efectivo de un rango. Si el rango es un caret (colapsado) hereda
  /// el formato del caracter a la izquierda, tal como el cursor de Word toma el
  /// estilo del texto que le precede. Para una seleccion real, negrita/subrayado
  /// solo se consideran activos si el rango entero los tiene, y el tamaño solo
  /// se reporta si es uniforme (si mezcla tamaños devuelve null).
  RichNoteFormatState formatIn(int start, int end) {
    if (text.isEmpty) return const RichNoteFormatState();
    final lo = start.clamp(0, text.length);
    final hi = end.clamp(lo, text.length);
    if (lo == hi) {
      if (lo == 0) return const RichNoteFormatState();
      return _effectiveAt(lo - 1);
    }
    var allBold = true;
    var allUnderline = true;
    double? uniformSize;
    var sizeUniform = true;
    var first = true;
    for (var pos = lo; pos < hi; pos++) {
      final f = _effectiveAt(pos);
      allBold = allBold && f.bold;
      allUnderline = allUnderline && f.underline;
      if (first) {
        uniformSize = f.fontSize;
        first = false;
      } else if (f.fontSize != uniformSize) {
        sizeUniform = false;
      }
    }
    return RichNoteFormatState(
      bold: allBold,
      underline: allUnderline,
      fontSize: sizeUniform ? uniformSize : null,
    );
  }

  RichNoteFormatState _effectiveAt(int pos) {
    var bold = false;
    var underline = false;
    double? fontSize;
    for (final span in spans) {
      if (pos >= span.start && pos < span.end) {
        bold = bold || span.bold;
        underline = underline || span.underline;
        if (span.fontSize != null) fontSize = span.fontSize;
      }
    }
    return RichNoteFormatState(
      bold: bold,
      underline: underline,
      fontSize: fontSize,
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
      var bold = false;
      var underline = false;
      double? fontSize;
      for (final span in spans) {
        if (start >= span.start && end <= span.end) {
          bold = bold || span.bold;
          underline = underline || span.underline;
          if (span.fontSize != null) fontSize = span.fontSize;
        }
      }
      final piece = text.substring(start, end);
      if (piece.isEmpty) continue;
      final nextSegment = RichNoteTextSegment(
        text: piece,
        bold: bold,
        underline: underline,
        fontSize: fontSize,
      );
      if (segments.isNotEmpty) {
        final last = segments.last;
        if (last.bold == nextSegment.bold &&
            last.underline == nextSegment.underline &&
            last.fontSize == nextSegment.fontSize) {
          segments[segments.length - 1] = last.copyWith(
            text: last.text + piece,
          );
          continue;
        }
      }
      segments.add(nextSegment);
    }
    return segments;
  }
}

String richNotePlainText(String source) {
  return RichNoteDocument.fromStorage(source).text;
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
