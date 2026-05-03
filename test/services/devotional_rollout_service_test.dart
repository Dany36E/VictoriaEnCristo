import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_quitar/services/devotional_rollout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('assignment is deterministic for the same user key', () async {
    final first = await DevotionalRolloutService.I.assignment(userKey: 'uid-123');
    final second = await DevotionalRolloutService.I.assignment(userKey: 'uid-123');

    expect(second.bucket, first.bucket);
    expect(second.variant, first.variant);
  });

  test('rollout percent 0 assigns control minimal variant', () async {
    await DevotionalRolloutService.I.setRolloutPercent(0);

    final assignment = await DevotionalRolloutService.I.assignment(userKey: 'uid-123');

    expect(assignment.variant, DevotionalRolloutVariant.controlMinimal);
    expect(assignment.rolloutPercent, 0);
    expect(assignment.showAudioCard, isFalse);
  });

  test('forced variant wins over bucket and rollout percent', () async {
    await DevotionalRolloutService.I.setRolloutPercent(0);
    await DevotionalRolloutService.I.forceVariant(DevotionalRolloutVariant.audioGuided);

    final assignment = await DevotionalRolloutService.I.assignment(userKey: 'uid-123');

    expect(assignment.variant, DevotionalRolloutVariant.audioGuided);
    expect(assignment.forced, isTrue);
    expect(assignment.showAudioCard, isTrue);
  });

  test('setRolloutPercent clamps values to 0..100', () async {
    await DevotionalRolloutService.I.setRolloutPercent(150);
    final high = await DevotionalRolloutService.I.assignment(userKey: 'uid-high');
    expect(high.rolloutPercent, 100);

    await DevotionalRolloutService.I.setRolloutPercent(-10);
    final low = await DevotionalRolloutService.I.assignment(userKey: 'uid-low');
    expect(low.rolloutPercent, 0);
  });
}
