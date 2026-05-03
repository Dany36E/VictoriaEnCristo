import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_quitar/models/content_enums.dart';
import 'package:app_quitar/models/devotional_entry.dart';
import 'package:app_quitar/models/plan_metadata.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('devotional_pool.json parses and covers all giants by stage', () async {
    final raw = await rootBundle.loadString('assets/content/devotional_pool.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final entries = (data['entries'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(DevotionalEntry.fromJson)
        .toList(growable: false);

    expect(entries, hasLength(24));
    expect(
      entries.every((entry) => entry.metadata.reviewLevel == PlanReviewLevel.approved),
      isTrue,
    );
    expect(entries.every((entry) => entry.challenge?.isNotEmpty == true), isTrue);

    for (final giant in GiantId.values) {
      for (final stage in ContentStage.values) {
        final hasCoverage = entries.any(
          (entry) => entry.metadata.giants.contains(giant) && entry.metadata.stage == stage,
        );
        expect(hasCoverage, isTrue, reason: 'Missing ${giant.id}/${stage.id} devotional');
      }
    }
  });
}
