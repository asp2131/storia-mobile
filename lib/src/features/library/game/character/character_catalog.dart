import 'character_types.dart';

/// The curated set of character parts available in Supabase Storage.
///
/// Each entry is a variant key = the asset filename stem
/// (e.g. `Layer5_Shirt_Blue`), present across all six bundled animations.
/// "None" for a slot is represented by a null selection, not a key here.
abstract final class CharacterCatalog {
  /// Available variants per slot, in display order. Only slots with choices
  /// appear; order follows [CharacterLayer] (z-order) for a stable UI.
  static const Map<CharacterLayer, List<String>> variants = {
    CharacterLayer.body: [
      'Layer0_Body_Skin1',
      'Layer0_Body_Skin2',
      'Layer0_Body_Skin3',
      'Layer0_Body_Skin4',
      'Layer0_Body_Skin5',
    ],
    CharacterLayer.face: [
      'Layer1_Face_Regular',
      'Layer1_Face_Happy',
      'Layer1_Face_Angry',
      'Layer1_Face_Tired',
    ],
    CharacterLayer.bodySuit: [
      'Layer2_BodySuit_Sky',
      'Layer2_BodySuit_Pink',
    ],
    CharacterLayer.pants: [
      'Layer3_Pants_Blue',
      'Layer3_Pants_Brown',
      'Layer3_Pants_Grey',
    ],
    CharacterLayer.shoes: [
      'Layer4_Shoes_Brown',
      'Layer4_Shoes_Blue',
      'Layer4_Shoes_Red',
    ],
    CharacterLayer.torso: [
      'Layer5_Shirt_Blue',
      'Layer5_Shirt_Red',
      'Layer5_Shirt_Green',
      'Layer5_Shirt_Yellow',
      'Layer5_Dress_Pink',
      'Layer5_Dress_Purple',
      'Layer5_Armor_Iron',
    ],
    CharacterLayer.sleeves: [
      'Layer6_Sleeves_Red',
    ],
    CharacterLayer.necklace: [
      'Layer7_Necklace_Gold',
      'Layer7_Necklace_Silver',
    ],
    CharacterLayer.bag: [
      'Layer8_Bag_Blue',
      'Layer8_Bag_Red',
    ],
    CharacterLayer.scarf: [
      'Layer9_Scarf_Sky',
      'Layer9_Scarf_Orange',
    ],
    CharacterLayer.bowtie: [
      'Layer10_Bowtie_Red',
      'Layer10_Bowtie_Blue',
    ],
    CharacterLayer.head: [
      'Layer11_ShortHair_Color1',
      'Layer11_LongHair_Color1',
      'Layer11_BunHair_Color1',
      'Layer11_CurlyHair_Color1',
      'Layer11_PonytailHair_Color1',
      'Layer11_WavesHair_Color1',
      'Layer11_SpikesHair_Color1',
      'Layer11_MohawkHair_Color1',
      'Layer11_Beanie_Olive',
      'Layer11_BambooHat_Beige',
      'Layer11_Hemlet_Gold',
    ],
    CharacterLayer.accessory: [
      'Layer12_Bow_Red',
      'Layer12_Horns_Red',
    ],
  };

  /// Slots that must always have a value (no "None" option).
  static const Set<CharacterLayer> requiredSlots = {
    CharacterLayer.body,
    CharacterLayer.face,
  };

  /// Slots shown in the editor, in z-order.
  static List<CharacterLayer> get slots => variants.keys.toList();

  /// Whether a slot offers a "None" option.
  static bool allowsNone(CharacterLayer layer) =>
      !requiredSlots.contains(layer);

  /// Friendly label for a slot, e.g. `bodySuit` -> "Body Suit".
  static String slotLabel(CharacterLayer layer) {
    final name = layer.name;
    final spaced = name.replaceAllMapped(
      RegExp('[A-Z]'),
      (m) => ' ${m[0]}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// Friendly label for a variant key, e.g. `Layer5_Shirt_Blue` -> "Shirt Blue",
  /// `Layer11_ShortHair_Color1` -> "Short Hair 1".
  static String variantLabel(String key) {
    final parts = key.split('_');
    if (parts.length < 2) return key;
    final words = parts.skip(1).map((w) {
      final m = RegExp(r'^Color(\d+)$').firstMatch(w);
      if (m != null) return m.group(1)!; // Color3 -> 3
      return w.replaceAllMapped(RegExp('(?<=.)[A-Z]'), (x) => ' ${x[0]}');
    });
    return words.join(' ');
  }
}
