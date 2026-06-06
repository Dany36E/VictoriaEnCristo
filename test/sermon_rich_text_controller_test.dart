import 'package:app_quitar/models/bible/rich_note_document.dart';
import 'package:app_quitar/widgets/bible/sermon/sermon_rich_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renderiza estilos, cita detectada y palabra mal escrita inline',
    (tester) async {
      var document = const RichNoteDocument(
        text: 'Romanos 8:1 esperansa',
        spans: [],
      );
      document = document.applyFormat(0, 11, RichNoteFormat.bold);

      final controller = SermonRichTextController(document: document)
        ..updateReferenceRanges(const [NoteDecorationRange(start: 0, end: 11)])
        ..updateSpellSuggestions(const [
          SuggestionSpan(TextRange(start: 12, end: 21), <String>['esperanza']),
        ]);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final span = controller.buildTextSpan(
        context: capturedContext,
        style: const TextStyle(fontSize: 14),
        withComposing: false,
      );
      final children = span.children!.whereType<TextSpan>().toList();

      expect(children[0].text, 'Romanos 8:1');
      expect(children[0].style?.fontWeight, FontWeight.w800);
      expect(children[0].style?.decoration, TextDecoration.underline);
      expect(children[0].style?.decorationColor, const Color(0xFFC78D1B));

      expect(children.last.text, 'esperansa');
      expect(children.last.style?.decorationStyle, TextDecorationStyle.wavy);
      expect(children.last.style?.decorationColor, const Color(0xFFD64045));
    },
  );

  testWidgets('deshacer y rehacer restauran texto y formato', (tester) async {
    final controller = SermonRichTextController(
      document: const RichNoteDocument(text: 'hola mundo', spans: []),
    );

    late BuildContext capturedContext;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    controller.applyFormat(RichNoteFormat.bold);
    expect(controller.canUndo, isTrue);
    expect(
      controller
          .buildTextSpan(
            context: capturedContext,
            style: const TextStyle(fontSize: 14),
            withComposing: false,
          )
          .children!
          .whereType<TextSpan>()
          .first
          .style
          ?.fontWeight,
      FontWeight.w800,
    );

    expect(controller.undo(), isTrue);
    expect(controller.document.spans, isEmpty);
    expect(controller.canRedo, isTrue);
    expect(controller.canUndo, isFalse);

    expect(controller.redo(), isTrue);
    expect(controller.document.spans, isNotEmpty);
  });

  testWidgets('undo revierte inserciones de texto y redo las recupera', (
    tester,
  ) async {
    final controller = SermonRichTextController(
      document: const RichNoteDocument(text: 'hola', spans: []),
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.shrink(),
      ),
    );

    controller.value = const TextEditingValue(
      text: 'hola mundo',
      selection: TextSelection.collapsed(offset: 10),
    );
    expect(controller.text, 'hola mundo');

    expect(controller.undo(), isTrue);
    expect(controller.text, 'hola');

    expect(controller.redo(), isTrue);
    expect(controller.text, 'hola mundo');
  });
}
