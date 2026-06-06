class StudyTextSegment {
  final String text;
  final bool bold;
  final bool underline;
  final double? fontSize;

  const StudyTextSegment({
    required this.text,
    this.bold = false,
    this.underline = false,
    this.fontSize,
  });

  StudyTextSegment copyWith({
    String? text,
    bool? bold,
    bool? underline,
    double? fontSize,
  }) {
    return StudyTextSegment(
      text: text ?? this.text,
      bold: bold ?? this.bold,
      underline: underline ?? this.underline,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

List<StudyTextSegment> parseStudyNoteMarkup(String source) {
  return _parseRange(source, 0, source.length, const _MarkupStyle()).segments;
}

String stripStudyNoteMarkup(String source) {
  return parseStudyNoteMarkup(source).map((segment) => segment.text).join();
}

String wrapStudyNoteSelection({
  required String text,
  required int start,
  required int end,
  required StudyNoteFormat format,
  double? fontSize,
}) {
  final lo = start.clamp(0, text.length);
  final hi = end.clamp(lo, text.length);
  if (lo == hi) return text;
  final selected = text.substring(lo, hi);
  final wrapped = switch (format) {
    StudyNoteFormat.bold => '**$selected**',
    StudyNoteFormat.underline => '__${selected}__',
    StudyNoteFormat.size =>
      '<size:${(fontSize ?? 16).round()}>$selected</size>',
  };
  return '${text.substring(0, lo)}$wrapped${text.substring(hi)}';
}

enum StudyNoteFormat { bold, underline, size }

class _MarkupStyle {
  final bool bold;
  final bool underline;
  final double? fontSize;

  const _MarkupStyle({
    this.bold = false,
    this.underline = false,
    this.fontSize,
  });

  _MarkupStyle copyWith({bool? bold, bool? underline, double? fontSize}) {
    return _MarkupStyle(
      bold: bold ?? this.bold,
      underline: underline ?? this.underline,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

class _ParseResult {
  final List<StudyTextSegment> segments;
  final int index;

  const _ParseResult(this.segments, this.index);
}

_ParseResult _parseRange(
  String source,
  int start,
  int end,
  _MarkupStyle style, {
  String? closingTag,
}) {
  final segments = <StudyTextSegment>[];
  final buffer = StringBuffer();
  var index = start;

  void flush() {
    if (buffer.isEmpty) return;
    segments.add(
      StudyTextSegment(
        text: buffer.toString(),
        bold: style.bold,
        underline: style.underline,
        fontSize: style.fontSize,
      ),
    );
    buffer.clear();
  }

  while (index < end) {
    if (closingTag != null && source.startsWith(closingTag, index)) {
      flush();
      return _ParseResult(_mergeAdjacent(segments), index + closingTag.length);
    }

    if (source.startsWith('**', index)) {
      flush();
      final inner = _parseRange(
        source,
        index + 2,
        end,
        style.copyWith(bold: true),
        closingTag: '**',
      );
      segments.addAll(inner.segments);
      index = inner.index;
      continue;
    }

    if (source.startsWith('__', index)) {
      flush();
      final inner = _parseRange(
        source,
        index + 2,
        end,
        style.copyWith(underline: true),
        closingTag: '__',
      );
      segments.addAll(inner.segments);
      index = inner.index;
      continue;
    }

    final sizeMatch = RegExp(
      r'^<size:(\d{1,2})>',
    ).firstMatch(source.substring(index));
    if (sizeMatch != null) {
      flush();
      final size = double.tryParse(
        sizeMatch.group(1) ?? '',
      )?.clamp(10, 28).toDouble();
      final inner = _parseRange(
        source,
        index + sizeMatch.group(0)!.length,
        end,
        style.copyWith(fontSize: size),
        closingTag: '</size>',
      );
      segments.addAll(inner.segments);
      index = inner.index;
      continue;
    }

    buffer.write(source[index]);
    index++;
  }

  flush();
  return _ParseResult(_mergeAdjacent(segments), index);
}

List<StudyTextSegment> _mergeAdjacent(List<StudyTextSegment> source) {
  final merged = <StudyTextSegment>[];
  for (final segment in source) {
    if (segment.text.isEmpty) continue;
    if (merged.isNotEmpty) {
      final last = merged.last;
      if (last.bold == segment.bold &&
          last.underline == segment.underline &&
          last.fontSize == segment.fontSize) {
        merged[merged.length - 1] = last.copyWith(
          text: last.text + segment.text,
        );
        continue;
      }
    }
    merged.add(segment);
  }
  return merged;
}
