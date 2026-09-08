import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const requiredPages = <String>[
    'docs/privacy_policy.html',
    'docs/terms.html',
    'docs/cookie_policy.html',
    'docs/refund_policy.html',
    'docs/data_deletion.html',
    'docs/third_party_notices.html',
  ];

  test('all public legal pages exist and contain substantive content', () {
    for (final path in requiredPages) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path does not exist');
      expect(file.readAsStringSync().length, greaterThan(500), reason: path);
    }
  });

  test('legal site does not introduce tracking or third-party embeds', () {
    for (final path in requiredPages) {
      final html = File(path).readAsStringSync().toLowerCase();
      expect(html, isNot(contains('<script')), reason: path);
      expect(html, isNot(contains('<iframe')), reason: path);
    }
  });

  test('legal index links every policy page', () {
    final index = File('docs/index.html').readAsStringSync();
    for (final path in requiredPages) {
      expect(index, contains(path.replaceFirst('docs/', '')), reason: path);
    }
  });
}
