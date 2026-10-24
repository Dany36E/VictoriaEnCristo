import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/bible/colores_nota.dart';
import '../../../models/bible/etiquetas_nota.dart';
import '../../../models/bible/listas_nota.dart';
import '../../../models/bible/rich_note_document.dart';
import '../../../vec/vec_tema.dart';

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

  /// Color de viñetas, números y casillas de tareas.
  Color colorMarcas = VecColores.terracota;

  /// El fondo es oscuro: los colores de texto usan su variante clara.
  bool fondoOscuro = false;

  /// Dibuja la foto o el dibujo que va en el lugar de cada [kMarcaAdjunto].
  /// Sin él (o con un id desconocido) la marca no ocupa espacio.
  Widget? Function(String id)? constructorAdjunto;

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

  void applyFormat(RichNoteFormat format, {double? fontSize, String? value}) {
    final selection = this.value.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    _pushUndoState();
    _document = _document.applyFormat(
      selection.start,
      selection.end,
      format,
      fontSize: fontSize,
      value: value,
    );
    notifyListeners();
  }

  /// Título, encabezado, subencabezado o cuerpo para las líneas del cursor.
  void applyParagraphStyle(RichNoteParagraphStyle style) {
    final selection = value.selection;
    if (!selection.isValid) return;
    _pushUndoState();
    _document = _document.applyParagraphStyle(
      selection.start,
      selection.end,
      style,
    );
    notifyListeners();
  }

  /// Aplica varias ediciones de texto (listas, tareas) como un solo paso de
  /// deshacer, ajustando el formato de cada una por separado.
  void aplicarEdiciones(ResultadoEdicion resultado) {
    if (resultado.ediciones.isEmpty) return;
    _pushUndoState();
    var texto = text;
    for (final e in resultado.ediciones) {
      texto = texto.replaceRange(e.inicio, e.fin, e.texto);
      _document = _document.replaceText(texto);
    }
    _updatingProgrammatically = true;
    super.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(
        offset: resultado.cursor.clamp(0, texto.length),
      ),
    );
    _updatingProgrammatically = false;
    _redoStack.clear();
    notifyListeners();
  }

  /// Inserta el adjunto [id] donde está el cursor (o al final si el editor
  /// no tiene cursor), en su propia línea, y deja el cursor debajo.
  void insertarAdjunto(String id) {
    _pushUndoState();
    final sel = value.selection;
    final offset = sel.isValid ? sel.end : text.length;
    final (doc, cursor) = _document.insertarAdjunto(offset, id);
    _document = doc;
    _updatingProgrammatically = true;
    super.value = TextEditingValue(
      text: doc.text,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _updatingProgrammatically = false;
    _redoStack.clear();
    notifyListeners();
  }

  /// Quita del texto la marca del adjunto [id].
  void quitarAdjunto(String id) {
    if (!_document.embeds.contains(id)) return;
    _pushUndoState();
    final doc = _document.quitarAdjunto(id);
    final cursor = value.selection.isValid
        ? value.selection.end.clamp(0, doc.text.length)
        : doc.text.length;
    _document = doc;
    _updatingProgrammatically = true;
    super.value = TextEditingValue(
      text: doc.text,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _updatingProgrammatically = false;
    _redoStack.clear();
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

    // Marcas de lista al inicio de cada línea y líneas de tareas hechas.
    final marcas = <NoteDecorationRange>[];
    final hechas = <NoteDecorationRange>[];
    var inicio = 0;
    while (inicio <= text.length) {
      final fin = finDeLinea(text, inicio);
      final lista = listaEn(text, inicio);
      if (lista != null) {
        marcas.add(NoteDecorationRange(start: inicio, end: inicio + lista.largo));
        if (lista.hecha && fin > inicio + lista.largo) {
          hechas.add(NoteDecorationRange(start: inicio + lista.largo, end: fin));
        }
      }
      if (fin >= text.length) break;
      inicio = fin + 1;
    }

    // #etiquetas en color, como en Notas de Apple.
    final etiquetas = [
      for (final (a, b) in rangosEtiquetas(text))
        NoteDecorationRange(start: a, end: b),
    ];

    final breakpoints = <int>{0, text.length};
    void agregar(int a, int b) {
      breakpoints.add(a.clamp(0, text.length));
      breakpoints.add(b.clamp(0, text.length));
    }

    for (final span in _document.spans) {
      agregar(span.start, span.end);
    }
    for (final suggestion in _spellSuggestions) {
      agregar(suggestion.range.start, suggestion.range.end);
    }
    for (final r in [..._referenceRanges, ...marcas, ...hechas, ...etiquetas]) {
      agregar(r.start, r.end);
    }
    // Cada foto o dibujo en línea es su propio tramo.
    final indiceAdjunto = <int, int>{};
    for (var i = 0, n = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0xFFFC) {
        indiceAdjunto[i] = n++;
        agregar(i, i + 1);
      }
    }
    if (withComposing && value.composing.isValid) {
      agregar(value.composing.start, value.composing.end);
    }

    bool dentro(List<NoteDecorationRange> rangos, int a, int b) =>
        rangos.any((r) => a >= r.start && b <= r.end);

    final points = breakpoints.toList()..sort();
    final children = <InlineSpan>[];
    final colores = fondoOscuro ? coloresTextoOscuro : coloresTextoClaro;

    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      if (start >= end) continue;

      final indice = indiceAdjunto[start];
      if (indice != null && end == start + 1) {
        final embeds = _document.embeds;
        final id = indice < embeds.length ? embeds[indice] : '';
        final hijo = id.isEmpty ? null : constructorAdjunto?.call(id);
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            style: style,
            child: hijo ?? const SizedBox(width: 1, height: 1),
          ),
        );
        continue;
      }

      final f = _document.formatIn(start, end);
      final isMisspelled = _spellSuggestions.any(
        (suggestion) =>
            start >= suggestion.range.start && end <= suggestion.range.end,
      );
      final isReference = dentro(_referenceRanges, start, end);
      final isMarca = dentro(marcas, start, end);
      final isHecha = dentro(hechas, start, end);
      final isEtiqueta = dentro(etiquetas, start, end);
      final isComposing =
          withComposing &&
          value.composing.isValid &&
          start >= value.composing.start &&
          end <= value.composing.end;

      final decorations = <TextDecoration>[];
      TextDecorationStyle? decorationStyle;
      Color? decorationColor;
      if (isMisspelled) {
        decorations.add(TextDecoration.underline);
        decorationStyle = TextDecorationStyle.wavy;
        decorationColor = const Color(0xFFD64045);
      } else if (isReference) {
        decorations.add(TextDecoration.underline);
        decorationColor = const Color(0xFFC78D1B);
      } else if (f.underline || isComposing) {
        decorations.add(TextDecoration.underline);
      }
      if (f.strike || isHecha) decorations.add(TextDecoration.lineThrough);

      final baseColor = style?.color;
      Color? color = f.color != null && colores[f.color] != null
          ? Color(colores[f.color]!)
          : null;
      if (isMarca || (isEtiqueta && color == null)) color = colorMarcas;
      if (isHecha) color = (baseColor ?? VecColores.gris).withValues(alpha: 0.55);
      final highlight = f.highlight == null ? null : coloresResaltado[f.highlight];

      final estilo = style?.copyWith(
        fontSize: f.fontSize,
        fontWeight: f.bold || isMarca
            ? FontWeight.w800
            : isEtiqueta
            ? FontWeight.w600
            : style.fontWeight,
        fontStyle: f.italic ? FontStyle.italic : style.fontStyle,
        color: color,
        backgroundColor: highlight == null ? null : Color(highlight),
        decoration: decorations.isEmpty
            ? TextDecoration.none
            : TextDecoration.combine(decorations),
        decorationStyle: decorationStyle,
        decorationColor: decorationColor,
      );
      final trozo = text.substring(start, end);
      final casilla = isMarca ? _indiceCasilla(trozo) : -1;
      if (casilla >= 0) {
        // La casilla ocupa el mismo carácter que «☐»/«☑», así que el cursor
        // y la selección no cambian; solo se dibuja igual en todo teléfono.
        if (casilla > 0) {
          children.add(TextSpan(text: trozo.substring(0, casilla), style: estilo));
        }
        children.add(
          _casillaTarea(
            hecha: trozo[casilla] == tareaHecha[0],
            tamano: (f.fontSize ?? style?.fontSize ?? 15),
            style: estilo,
          ),
        );
        if (casilla + 1 < trozo.length) {
          children.add(TextSpan(text: trozo.substring(casilla + 1), style: estilo));
        }
        continue;
      }

      children.add(TextSpan(text: trozo, style: estilo));
    }

    return TextSpan(style: style, children: children);
  }

  static int _indiceCasilla(String trozo) {
    for (var i = 0; i < trozo.length; i++) {
      if (trozo[i] == tareaPendiente[0] || trozo[i] == tareaHecha[0]) return i;
    }
    return -1;
  }

  /// Casilla de tarea dibujada en lugar del carácter «☐»/«☑».
  InlineSpan _casillaTarea({
    required bool hecha,
    required double tamano,
    TextStyle? style,
  }) {
    final lado = (tamano * 1.05).roundToDouble();
    final color = colorMarcas;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      style: style,
      child: Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          color: hecha ? color : null,
          borderRadius: BorderRadius.circular(lado * 0.28),
          border: Border.all(color: color, width: 1.8),
        ),
        child: hecha
            ? Icon(Icons.check_rounded, size: lado * 0.8, color: Colors.white)
            : null,
      ),
    );
  }
}
