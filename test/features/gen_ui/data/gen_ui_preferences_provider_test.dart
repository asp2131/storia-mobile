import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loratone/src/features/gen_ui/data/gen_ui_preferences_provider.dart';

void main() {
  group('GenUiPreferencesNotifier', () {
    test('Story Sparks are disabled by default', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final notifier = GenUiPreferencesNotifier();
      addTearDown(notifier.dispose);

      // Default is false before and after the async load resolves.
      expect(notifier.storySparksEnabled, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.storySparksEnabled, isFalse);
    });

    test('loads a previously persisted enabled preference', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'gen_ui_story_sparks_enabled': true,
      });
      final notifier = GenUiPreferencesNotifier();
      addTearDown(notifier.dispose);

      var notified = 0;
      notifier.addListener(() => notified++);

      await Future<void>.delayed(Duration.zero);

      expect(notifier.storySparksEnabled, isTrue);
      expect(notified, greaterThanOrEqualTo(1));
    });

    test('setStorySparksEnabled flips and persists the value', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final notifier = GenUiPreferencesNotifier();
      addTearDown(notifier.dispose);

      await notifier.setStorySparksEnabled(true);
      expect(notifier.storySparksEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('gen_ui_story_sparks_enabled'), isTrue);

      await notifier.setStorySparksEnabled(false);
      expect(notifier.storySparksEnabled, isFalse);
      expect(prefs.getBool('gen_ui_story_sparks_enabled'), isFalse);
    });

    test('does not notify after disposal', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'gen_ui_story_sparks_enabled': true,
      });
      final notifier = GenUiPreferencesNotifier();

      var notified = 0;
      notifier.addListener(() => notified++);

      // Dispose before the async load completes; must not throw or notify.
      notifier.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(notified, 0);
    });
  });
}
