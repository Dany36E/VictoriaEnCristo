import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/services/bible/bible_download_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all configured bible xml assets are bundled', () async {
    for (final version in BibleVersion.values) {
      final assetPath = 'assets/bible/${version.fileName}';
      final bytes = await rootBundle.load(assetPath);
      expect(bytes.lengthInBytes, greaterThan(1024), reason: assetPath);
    }
  });

  test('download service treats local bible xml files as bundled sources', () {
    final service = BibleDownloadService.I;
    for (final version in BibleVersion.values) {
      expect(service.isBundled(version), isTrue, reason: version.id);
    }
  });
}
