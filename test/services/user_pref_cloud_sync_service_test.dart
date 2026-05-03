import 'package:flutter_test/flutter_test.dart';

import 'package:app_quitar/services/user_pref_cloud_sync_service.dart';

void main() {
  group('UserPrefCloudSyncService', () {
    test('covers cross-device preference keys', () {
      const keys = <String>[
        'widget_config_json',
        'sacred_alarm_config_v1',
        'sacred_alarm_events_v1',
        'victory_threshold',
        'last_broken_streak_v1',
        'last_break_date_iso_v1',
        'relapse_ack_date_iso_v1',
        'grace_tokens_v1',
        'grace_tokens_month_v1',
        'grace_days_used_v1',
        'journey_start_iso_v1',
        'feedback_haptics_enabled',
        'feedback_sfx_enabled',
        'feedback_sfx_volume',
        'battle.acceptingInvites',
        'battle.trustedPartnerUid',
        'recommendation_history_v1',
        'advanced_search_history',
        'bible_search_recent',
      ];

      for (final key in keys) {
        expect(
          UserPrefCloudSyncService.isSyncedKeyForTesting(key),
          isTrue,
          reason: '$key should follow the user across devices',
        );
      }
    });

    test('local snapshot removes deleted owned keys but preserves unknown remote prefs', () {
      final merged = UserPrefCloudSyncService.mergeOwnedPrefsForTesting(
        <String, dynamic>{
          'widget_config_json': '{"template":"old"}',
          'battle.trustedPartnerUid': 'old-partner',
          'daily_practice_v1:2026-05-01': '{"victory":true}',
          'server_owned_flag': true,
        },
        <String, dynamic>{
          'widget_config_json': '{"template":"new"}',
          'battle.acceptingInvites': false,
        },
      );

      expect(merged['widget_config_json'], '{"template":"new"}');
      expect(merged['battle.acceptingInvites'], isFalse);
      expect(merged.containsKey('battle.trustedPartnerUid'), isFalse);
      expect(merged.containsKey('daily_practice_v1:2026-05-01'), isFalse);
      expect(merged['server_owned_flag'], isTrue);
    });

    test('empty local snapshot clears all owned remote prefs', () {
      final merged = UserPrefCloudSyncService.mergeOwnedPrefsForTesting(<String, dynamic>{
        'widget_config_json': '{"template":"old"}',
        'daily_practice_v1:2026-05-01': '{"victory":true}',
        'server_owned_flag': true,
      }, const <String, dynamic>{});

      expect(merged, <String, dynamic>{'server_owned_flag': true});
    });

    test('newer remote snapshot removes missing local owned prefs', () {
      final missing = UserPrefCloudSyncService.ownedKeysMissingFromRemoteForTesting(
        <String>{
          'widget_config_json',
          'battle.trustedPartnerUid',
          'daily_practice_v1:2026-05-01',
          'unowned_cache_key',
        },
        <String>{'widget_config_json', 'server_owned_flag'},
      );

      expect(missing, <String>{'battle.trustedPartnerUid', 'daily_practice_v1:2026-05-01'});
    });
  });
}
