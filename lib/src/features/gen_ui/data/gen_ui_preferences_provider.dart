import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists parent-facing preferences for the gen-UI ("Story Spark") activity
/// cards shown while reading.
///
/// Story Sparks are **disabled by default**; a parent opts in from the reader's
/// Audio Mix sheet. The preference is stored locally via [SharedPreferences].
class GenUiPreferencesNotifier extends ChangeNotifier {
  GenUiPreferencesNotifier() {
    _load();
  }

  static const _storySparksEnabledKey = 'gen_ui_story_sparks_enabled';

  /// Default state: Story Sparks are off until a parent enables them.
  static const bool _defaultStorySparksEnabled = false;

  SharedPreferences? _preferences;
  bool _storySparksEnabled = _defaultStorySparksEnabled;
  bool _disposed = false;

  /// Whether Story Spark activity cards should appear during reading.
  bool get storySparksEnabled => _storySparksEnabled;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    final preferences = await _prefs;
    final stored = preferences.getBool(_storySparksEnabledKey);
    // The notifier can be disposed while the async read is in flight (e.g. the
    // reader unmounts before prefs resolve); never notify after disposal.
    if (_disposed) return;
    if (stored != null && stored != _storySparksEnabled) {
      _storySparksEnabled = stored;
      notifyListeners();
    }
  }

  /// Enables or disables Story Spark activity cards and persists the choice.
  Future<void> setStorySparksEnabled(bool enabled) async {
    if (_disposed || _storySparksEnabled == enabled) return;
    _storySparksEnabled = enabled;
    notifyListeners();
    final preferences = await _prefs;
    await preferences.setBool(_storySparksEnabledKey, enabled);
  }

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }
}

/// Owns the persisted gen-UI preferences.
final genUiPreferencesNotifierProvider =
    ChangeNotifierProvider<GenUiPreferencesNotifier>((ref) {
      // ChangeNotifierProvider disposes the returned notifier automatically.
      return GenUiPreferencesNotifier();
    });

/// Whether Story Spark activity cards are enabled (defaults to `false`).
final storySparksEnabledProvider = Provider<bool>((ref) {
  return ref.watch(genUiPreferencesNotifierProvider).storySparksEnabled;
});
