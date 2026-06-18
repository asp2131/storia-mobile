import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../library/game/character/character_selection.dart';
import '../../library/game/character/character_types.dart';
import '../../library/game/player_component.dart';

/// Owns the player's chosen character look, persisted locally via
/// [SharedPreferences]. Also mirrors the current selection into
/// [PlayerComponent.activeSelection] so the library map picks it up on
/// (re)build without threading selection through the engine port.
class CharacterSelectionNotifier extends ChangeNotifier {
  CharacterSelectionNotifier() {
    PlayerComponent.activeSelection = _selection;
    _load();
  }

  static const _key = 'character_selection';

  SharedPreferences? _preferences;
  CharacterSelection _selection = CharacterSelection.defaults();
  bool _disposed = false;

  CharacterSelection get selection => _selection;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await _prefs;
    if (_disposed) return;
    final stored = prefs.getString(_key);
    if (stored == null) return;
    try {
      _selection = CharacterSelection.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
      PlayerComponent.activeSelection = _selection;
      notifyListeners();
    } catch (_) {
      // Corrupt value: keep defaults.
    }
  }

  /// Change one slot (null clears it) and persist.
  Future<void> setLayer(CharacterLayer layer, String? value) async {
    _selection = _selection.copyWith(layer, value);
    PlayerComponent.activeSelection = _selection;
    notifyListeners();
    final prefs = await _prefs;
    await prefs.setString(_key, jsonEncode(_selection.toJson()));
  }

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();
}

/// Owns the persisted character selection.
final characterSelectionNotifierProvider =
    ChangeNotifierProvider<CharacterSelectionNotifier>((ref) {
  return CharacterSelectionNotifier();
});
