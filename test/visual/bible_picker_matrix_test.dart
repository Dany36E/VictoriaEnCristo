import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase's own test transport; no calls reach a remote backend.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/models/bible/bible_book.dart';
import 'package:app_quitar/services/bible/bible_parser_service.dart';
import 'package:app_quitar/services/bible/bible_user_data_service.dart';
import 'package:app_quitar/screens/bible/study_mode_screen.dart';
import 'package:app_quitar/widgets/bible/study/study_chapter_picker.dart';
import 'package:app_quitar/theme/bible_reader_theme.dart';
import 'series_matrix_test.dart' show profiles;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  late List<BibleBook> books;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Firebase.initializeApp();
    GoogleFonts.config.allowRuntimeFetching = false;
    books = await BibleParserService.I.getBooks(BibleVersion.rvr1960);
    for (final entry in {
      'Manrope': 'google_fonts/Manrope-VariableFont_wght.ttf',
      'Cinzel': 'google_fonts/Cinzel-VariableFont_wght.ttf',
      'Lora': 'google_fonts/Lora-VariableFont_wght.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
      if (entry.key != 'MaterialIcons') {
        for (final weight in FontWeight.values) {
          final family = GoogleFonts.getFont(
            entry.key,
            fontWeight: weight,
          ).fontFamily!;
          await (FontLoader(
            family,
          )..addFont(rootBundle.load(entry.value))).load();
        }
      }
    }
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  for (final profile in profiles.entries) {
    for (final scale in [1.0, 1.6]) {
      for (final theme in BibleReaderThemeData.all) {
        testWidgets(
          '${profile.key} $scale ${theme.id}: clipboard range and layout',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = profile.value;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            BibleUserDataService.I.readerThemeNotifier.value = theme.id;
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, (
                  call,
                ) async {
                  if (call.method == 'Clipboard.getData') {
                    return {'text': 'Juan 3:16-18'};
                  }
                  return null;
                });
            addTearDown(
              () => TestDefaultBinaryMessengerBinding
                  .instance
                  .defaultBinaryMessenger
                  .setMockMethodCallHandler(SystemChannels.platform, null),
            );
            StudyPickerResult? result;
            final boundary = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: TextButton(
                          child: const Text('Selector'),
                          onPressed: () async {
                            result =
                                await showModalBottomSheet<StudyPickerResult>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => StudyChapterPicker(
                                    books: books,
                                    version: BibleVersion.rvr1960,
                                    currentBookNumber: 43,
                                    currentChapter: 3,
                                  ),
                                );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Selector'));
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/qa/picker_${profile.key}_${scale}_${theme.id}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
            expect(tester.takeException(), isNull);
            await tester.tap(find.textContaining('Pegar', findRichText: true));
            await tester.pumpAndSettle();
            expect(result?.bookNumber, 43);
            expect(result?.chapter, 3);
            expect(result?.verse, 16);
            expect(result?.verseEnd, 18);
          },
        );
      }
    }
  }
}
