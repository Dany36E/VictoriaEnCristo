import 'package:app_quitar/models/bible/rich_note_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migra markup legado a texto plano con estilos', () {
    final document = RichNoteDocument.fromStorage(
      '**Titulo** __clave__ <size:22>grande</size>',
    );

    expect(document.text, 'Titulo clave grande');
    final segments = document.toSegments();
    expect(segments.map((segment) => segment.text), [
      'Titulo',
      ' ',
      'clave',
      ' ',
      'grande',
    ]);
    expect(segments[0].bold, isTrue);
    expect(segments[2].underline, isTrue);
    expect(segments[4].fontSize, 22);
  });

  test('serializa y restaura el documento enriquecido', () {
    var document = const RichNoteDocument(
      text: 'Romanos 8:1 esperanza',
      spans: [],
    );
    document = document.applyFormat(0, 11, RichNoteFormat.bold);
    document = document.applyFormat(12, 22, RichNoteFormat.underline);
    document = document.applyFormat(12, 22, RichNoteFormat.size, fontSize: 18);

    final restored = RichNoteDocument.fromStorage(document.toStorage());
    final segments = restored.toSegments();

    expect(restored.text, document.text);
    expect(segments.first.bold, isTrue);
    expect(segments.last.underline, isTrue);
    expect(segments.last.fontSize, 18);
  });

  test('conserva estilo al insertar texto dentro del rango formateado', () {
    var document = const RichNoteDocument(text: 'Fe viva', spans: []);
    document = document.applyFormat(0, 7, RichNoteFormat.bold);

    final updated = document.replaceText('Fe muy viva');
    final segments = updated.toSegments();

    expect(updated.text, 'Fe muy viva');
    expect(segments.single.text, 'Fe muy viva');
    expect(segments.single.bold, isTrue);
  });

  test('ajusta rangos al borrar parte del texto formateado', () {
    var document = const RichNoteDocument(text: 'gracia abundante', spans: []);
    document = document.applyFormat(0, 16, RichNoteFormat.underline);

    final updated = document.replaceText('gracia ante');
    final segments = updated.toSegments();

    expect(updated.text, 'gracia ante');
    expect(segments.single.underline, isTrue);
    expect(segments.single.text, 'gracia ante');
  });
}
