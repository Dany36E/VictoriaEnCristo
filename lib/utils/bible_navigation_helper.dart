import 'package:flutter/material.dart';
import '../models/bible/bible_version.dart';
import '../services/bible/bible_user_data_service.dart';
import '../services/bible/treasury_service.dart';
import '../screens/bible/bible_reader_screen.dart';

/// Helper estático para navegar a un versículo bíblico desde cualquier contexto.
class BibleNavigationHelper {
  BibleNavigationHelper._();

  /// Navega al capítulo/versículo indicado por una referencia OSIS ("ROM.5.8").
  static void navigateToOsis(BuildContext context, String osisRef) {
    final parsed = TreasuryService.parseReference(osisRef);
    if (parsed == null) return;

    final bookName = TreasuryService.formatReference(osisRef).split(' ').first;
    final version = BibleUserDataService.I.preferredVersionNotifier.value;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          bookNumber: parsed.bookNumber,
          bookName: bookName,
          chapter: parsed.chapter,
          version: version,
        ),
      ),
    );
  }

  /// Navega directamente con bookNumber, bookName, chapter, version.
  static void navigateTo(
    BuildContext context, {
    required int bookNumber,
    required String bookName,
    required int chapter,
    BibleVersion? version,
  }) {
    final v = version ?? BibleUserDataService.I.preferredVersionNotifier.value;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          bookNumber: bookNumber,
          bookName: bookName,
          chapter: chapter,
          version: v,
        ),
      ),
    );
  }
}
