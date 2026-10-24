import 'package:app_quitar/models/prayer_map.dart';
import 'package:app_quitar/screens/journal_entry_editor.dart';
import 'package:app_quitar/services/journal_service.dart';
import 'package:app_quitar/theme/app_theme.dart';
import 'package:app_quitar/theme/app_theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('PrayerMapData con guía de escritura', () {
    test('guarda y recupera la guía y la respuesta', () {
      const data = PrayerMapData(
        guiaTitulo: 'Gratitud en la prueba',
        guia: '¿Qué puedes agradecer hoy aunque sea difícil?',
        respuestaGuia: 'Por mi familia.',
      );
      expect(data.isEmpty, isFalse);
      final leido = PrayerMapData.tryDecode(data.encode())!;
      expect(leido.guiaTitulo, 'Gratitud en la prueba');
      expect(leido.guia, startsWith('¿Qué puedes'));
      expect(leido.respuestaGuia, 'Por mi familia.');
      expect(leido.summary(), 'Gratitud en la prueba: Por mi familia.');
    });

    test('las entradas sin guía siguen igual', () {
      const data = PrayerMapData(gracias: 'Por la vida');
      final leido = PrayerMapData.tryDecode(data.encode())!;
      expect(leido.tieneGuia, isFalse);
      expect(leido.gracias, 'Por la vida');
      expect(data.toJson().containsKey('guia'), isFalse);
    });
  });

  testWidgets('«Escribir sobre esto» muestra la guía y la guarda', (
    tester,
  ) async {
    JournalEntry? guardada;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.paperTheme,
        builder: (context, child) =>
            AppThemeData.provider(theme: AppThemeData.paper, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => JournalEntryEditor(
                      initialPromptTitle: 'Gratitud en la prueba',
                      initialPrompt:
                          '¿Qué puedes agradecer hoy aunque sea difícil?',
                      onSave: (e) => guardada = e,
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // La guía se ve arriba, como título bajo el que se escribe.
    expect(find.text('Gratitud en la prueba'), findsOneWidget);
    expect(
      find.text('¿Qué puedes agradecer hoy aunque sea difícil?'),
      findsOneWidget,
    );
    expect(find.text('Tu respuesta'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('journal_respuesta_guia')),
      'Por mis hermanos de la iglesia.',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(guardada, isNotNull);
    final data = PrayerMapData.tryDecode(guardada!.content)!;
    expect(data.guiaTitulo, 'Gratitud en la prueba');
    expect(data.guia, '¿Qué puedes agradecer hoy aunque sea difícil?');
    expect(data.respuestaGuia, 'Por mis hermanos de la iglesia.');
  });

  testWidgets('al editar una entrada con guía, la guía vuelve a verse', (
    tester,
  ) async {
    final entrada = JournalEntry(
      id: 'x1',
      date: DateTime(2026, 10, 1),
      content: const PrayerMapData(
        guiaTitulo: 'Mi identidad',
        guia: '¿Quién dice Dios que eres?',
        respuestaGuia: 'Su hijo.',
      ).encode(),
      mood: 'grateful',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.paperTheme,
        home: JournalEntryEditor(existingEntry: entrada, onSave: (_) {}),
      ),
    );
    await tester.pump();
    expect(find.text('Mi identidad'), findsOneWidget);
    expect(find.text('¿Quién dice Dios que eres?'), findsOneWidget);
    expect(find.text('Su hijo.'), findsOneWidget);
  });
}
