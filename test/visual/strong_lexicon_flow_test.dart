import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_quitar/models/bible/interlinear_word.dart';
import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/screens/bible/bible_search_screen.dart';
import 'package:app_quitar/services/bible/advanced_search_service.dart';
import 'package:app_quitar/services/bible/bible_user_data_service.dart';
import 'package:app_quitar/services/bible/strong_lexicon_service.dart';
import 'package:app_quitar/widgets/bible/morphology_detail_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase's own test transport; no calls reach a remote backend.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Firebase.initializeApp();
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final entry in {
      'Manrope': 'google_fonts/Manrope-VariableFont_wght.ttf',
      'Cinzel': 'google_fonts/Cinzel-VariableFont_wght.ttf',
      'Lora': 'google_fonts/Lora-VariableFont_wght.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  testWidgets('phone: Hebrew morphology, Strong and occurrences fit', (
    tester,
  ) async {
    await _configurePhone(tester);
    final boundary = GlobalKey();
    await tester.runAsync(() => StrongLexiconService.I.lookupStrong('H430'));
    const word = InterlinearWord(
      position: 1,
      originalWord: 'אֱלֹהִים',
      lemma: 'אֱלֹהִים',
      strongNumber: 'H430',
      morphCode: 'HNcmpa',
      gloss: 'God',
      morphAnalysis: MorphAnalysis(
        partOfSpeech: 'Sustantivo',
        grammaticalNumber: 'Plural',
        gender: 'Masculino',
      ),
    );

    await tester.pumpWidget(
      _testApp(
        boundary,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    MorphologyDetailPanel.show(context, word, true),
                child: const Text('Abrir palabra'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir palabra'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('DICCIONARIO STRONG'), findsOneWidget);
    expect(find.text('Ver todas sus apariciones'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, boundary, 'build/qa/strong_lexicon_phone.png');
  });

  testWidgets('phone 160%: original-language search stays readable', (
    tester,
  ) async {
    await _configurePhone(tester);
    final boundary = GlobalKey();
    await tester.runAsync(
      () => AdvancedSearchService.I.searchByOriginalWord(
        'θεός',
        BibleVersion.rvr1960,
      ),
    );
    await tester.pumpWidget(
      _testApp(
        boundary,
        const BibleSearchScreen(initialAdvanced: true, initialQuery: 'θεός'),
        textScale: 1.6,
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('versículo'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _capture(tester, boundary, 'build/qa/original_search_160.png');
  });
}

Widget _testApp(GlobalKey boundary, Widget home, {double textScale = 1.0}) {
  BibleUserDataService.I.readerThemeNotifier.value = 'papel';
  return RepaintBoundary(
    key: boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

Future<void> _configurePhone(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  String path,
) async {
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
