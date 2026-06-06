import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/bible/rich_note_document.dart';

class NoteDecorationRange {
  final int start;
  final int end;

  const NoteDecorationRange({required this.start, required this.end});
}

class _RichNoteSnapshot {
  final RichNoteDocument document;
  final TextEditingValue value;

  const _RichNoteSnapshot({required this.document, required this.value});
}

class SermonRichTextController extends TextEditingController {
  SermonRichTextController({RichNoteDocument? document})
    : _document = document ?? RichNoteDocument.empty(),
      super(text: (document ?? RichNoteDocument.empty()).text);

  RichNoteDocument _document;
  List<SuggestionSpan> _spellSuggestions = const [];
  List<NoteDecorationRange> _referenceRanges = const [];
  bool _updatingProgrammatically = false;
  final List<_RichNoteSnapshot> _undoStack = <_RichNoteSnapshot>[];
  final List<_RichNoteSnapshot> _redoStack = <_RichNoteSnapshot>[];

  RichNoteDocument get document => _document;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void loadDocument(RichNoteDocument document) {
    _document = document;
    _undoStack.clear();
    _redoStack.clear();
    _updatingProgrammatically = true;
    value = TextEditingValue(
      text: document.text,
      selection: TextSelection.collapsed(
        offset: document.text.length.clamp(0, document.text.length),
      ),
    );
    _updatingProgrammatically = false;
    notifyListeners();
  }

  void applyFormat(RichNoteFormat format, {double? fontSize}) {
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    _pushUndoState();
    _document = _document.applyFormat(
      selection.start,
      selection.end,
      format,
      fontSize: fontSize,
    );
    notifyListeners();
  }

  bool undo() {
    if (_undoStack.isEmpty) return false;
    final current = _currentSnapshot();
    final previous = _undoStack.removeLast();
    _redoStack.add(current);
    _restoreSnapshot(previous);
    return true;
  }

  bool redo() {
    if (_redoStack.isEmpty) return false;
    final current = _currentSnapshot();
    final next = _redoStack.removeLast();
    _undoStack.add(current);
    _restoreSnapshot(next);
    return true;
  }

  void updateSpellSuggestions(List<SuggestionSpan> suggestions) {
    _spellSuggestions = List<SuggestionSpan>.unmodifiable(suggestions);
    notifyListeners();
  }

  void updateReferenceRanges(List<NoteDecorationRange> ranges) {
    _referenceRanges = List<NoteDecorationRange>.unmodifiable(ranges);
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    final oldValue = super.value;
    if (!_updatingProgrammatically && newValue.text != oldValue.text) {
      _pushUndoState(
        snapshot: _RichNoteSnapshot(document: _document, value: oldValue),
      );
      _document = _document.replaceText(newValue.text);
      _redoStack.clear();
    }
    super.value = newValue;
  }

  _RichNoteSnapshot _currentSnapshot() {
    return _RichNoteSnapshot(document: _document, value: super.value);
  }

  void _pushUndoState({_RichNoteSnapshot? snapshot}) {
    final current = snapshot ?? _currentSnapshot();
    if (_undoStack.isNotEmpty) {
      final previous = _undoStack.last;
      if (previous.document.toStorage() == current.document.toStorage() &&
          previous.value.text == current.value.text &&
          previous.value.selection == current.value.selection) {
        return;
      }
    }
    _undoStack.add(current);
    if (_undoStack.length > 100) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _restoreSnapshot(_RichNoteSnapshot snapshot) {
    _updatingProgrammatically = true;
    _document = snapshot.document;
    super.value = snapshot.value;
    _updatingProgrammatically = false;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    if (text.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    final breakpoints = <int>{0, text.length};
    for (final span in _document.spans) {
      breakpoints.add(span.start.clamp(0, text.length));
      breakpoints.add(span.end.clamp(0, text.length));
    }
    for (final suggestion in _spellSuggestions) {
      breakpoints.add(suggestion.range.start.clamp(0, text.length));
      breakpoints.add(suggestion.range.end.clamp(0, text.length));
    }
    for (final reference in _referenceRanges) {
      breakpoints.add(reference.start.clamp(0, text.length));
      breakpoints.add(reference.end.clamp(0, text.length));
    }
    if (withComposing && value.composing.isValid) {
      breakpoints.add(value.composing.start.clamp(0, text.length));
      breakpoints.add(value.composing.end.clamp(0, text.length));
    }

    final points = breakpoints.toList()..sort();
    final children = <InlineSpan>[];

    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      if (start >= end) continue;

      var bold = false;
      var underline = false;
      double? fontSize;
      for (final span in _document.spans) {
        if (start >= span.start && end <= span.end) {
          bold = bold || span.bold;
          underline = underline || span.underline;
          if (span.fontSize != null) fontSize = span.fontSize;
        }
      }

      final isMisspelled = _spellSuggestions.any(
        (suggestion) =>
            start >= suggestion.range.start && end <= suggestion.range.end,
      );
      final isReference = _referenceRanges.any(
        (reference) => start >= reference.start && end <= reference.end,
      );
      final isComposing =
          withComposing &&
          value.composing.isValid &&
          start >= value.composing.start &&
          end <= value.composing.end;

      TextDecoration? decoration;
      TextDecorationStyle? decorationStyle;
      Color? decorationColor;
      if (isMisspelled) {
        decoration = TextDecoration.underline;
        decorationStyle = TextDecorationStyle.wavy;
        decorationColor = const Color(0xFFD64045);
      } else if (isReference) {
        decoration = TextDecoration.underline;
        decorationStyle = TextDecorationStyle.solid;
        decorationColor = const Color(0xFFC78D1B);
      } else if (underline) {
        decoration = TextDecoration.underline;
      } else if (isComposing) {
        decoration = TextDecoration.underline;
      }

      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: style?.copyWith(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w800 : style.fontWeight,
            decoration: decoration,
            decorationStyle: decorationStyle,
            decorationColor: decorationColor,
          ),
        ),
      );
    }

    return TextSpan(style: style, children: children);
  }
}
