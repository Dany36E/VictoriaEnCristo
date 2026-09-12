import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/services/bible/bible_download_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bundledVersions = [
    BibleVersion.rvr1960,
    BibleVersion.nvi,
    BibleVersion.lbla,
    BibleVersion.ntv,
    BibleVersion.tla,
  ];

  test('configured offline bible xml assets are bundled', () async {
    for (final version in bundledVersions) {
      final assetPath = 'assets/bible/${version.fileName}';
      final bytes = await rootBundle.load(assetPath);
      expect(bytes.lengthInBytes, greaterThan(1024), reason: assetPath);
    }
  });

  test(
    'download service distinguishes bundled and licensed remote sources',
    () {
      final service = BibleDownloadService.I;
      for (final version in bundledVersions) {
        expect(service.isBundled(version), isTrue, reason: version.id);
      }
      expect(service.isBundled(BibleVersion.nlt), isFalse);
      expect(service.isBundled(BibleVersion.nkjv), isFalse);
      expect(service.isBundled(BibleVersion.nivEnglish), isFalse);
    },
  );
}
