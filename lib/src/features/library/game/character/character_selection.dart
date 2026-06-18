import 'character_types.dart';

class CharacterSelection {
  const CharacterSelection._(this._layers);

  factory CharacterSelection.from(Map<CharacterLayer, String?> layers) =>
      CharacterSelection._(Map.unmodifiable({...layers}));

  /// Bundled default outfit. Asset files for these keys are copied in Task 5.
  factory CharacterSelection.defaults() => CharacterSelection.from(const {
        CharacterLayer.body: 'Layer0_Body_Skin1',
        CharacterLayer.face: 'Layer1_Face_Regular',
        CharacterLayer.pants: 'Layer3_Pants_Blue',
        CharacterLayer.shoes: 'Layer4_Shoes_Brown',
        CharacterLayer.torso: 'Layer5_Shirt_Blue',
        CharacterLayer.head: 'Layer11_ShortHair_Color1',
      });

  /// Restore from a `{layerName: variantKey}` map (the [toJson] shape).
  factory CharacterSelection.fromJson(Map<String, dynamic> json) {
    final layers = <CharacterLayer, String?>{};
    for (final layer in CharacterLayer.values) {
      final value = json[layer.name];
      if (value is String) layers[layer] = value;
    }
    return CharacterSelection.from(layers);
  }

  final Map<CharacterLayer, String?> _layers;

  String? operator [](CharacterLayer layer) => _layers[layer];

  /// Serialize equipped (non-null) slots as `{layerName: variantKey}`.
  Map<String, String> toJson() => {
        for (final e in equipped) e.key.name: e.value!,
      };

  CharacterSelection copyWith(CharacterLayer layer, String? value) {
    final next = {..._layers};
    next[layer] = value;
    return CharacterSelection.from(next);
  }

  /// Non-null entries in z-order (CharacterLayer declaration order).
  Iterable<MapEntry<CharacterLayer, String?>> get equipped =>
      CharacterLayer.values
          .where((l) => _layers[l] != null)
          .map((l) => MapEntry(l, _layers[l]));

  @override
  bool operator ==(Object other) {
    if (other is! CharacterSelection) return false;
    if (other._layers.length != _layers.length) return false;
    for (final l in CharacterLayer.values) {
      if (other._layers[l] != _layers[l]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hashAll(CharacterLayer.values.map((l) => _layers[l]));
}
