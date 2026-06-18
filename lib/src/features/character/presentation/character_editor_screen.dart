import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/storia_colors.dart';
import '../../library/game/character/character_catalog.dart';
import '../../library/game/character/character_selection.dart';
import '../../library/game/character/character_types.dart';
import '../data/character_selection_store.dart';
import 'character_preview_game.dart';

/// Character customization screen: live preview + per-slot part pickers.
///
/// Parts come from the curated Supabase catalog; the chosen look persists
/// locally via [characterSelectionNotifierProvider].
class CharacterEditorScreen extends ConsumerStatefulWidget {
  const CharacterEditorScreen({super.key});

  @override
  ConsumerState<CharacterEditorScreen> createState() =>
      _CharacterEditorScreenState();
}

class _CharacterEditorScreenState
    extends ConsumerState<CharacterEditorScreen> {
  late final CharacterPreviewGame _game;
  late CharacterSelection _applied;
  CharacterLayer _slot = CharacterCatalog.slots.first;

  @override
  void initState() {
    super.initState();
    _applied = ref.read(characterSelectionNotifierProvider).selection;
    _game = CharacterPreviewGame(_applied);
  }

  void _select(CharacterLayer layer, String? value) {
    ref.read(characterSelectionNotifierProvider).setLayer(layer, value);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the option highlights as the selection changes.
    final selection = ref.watch(characterSelectionNotifierProvider).selection;

    // Sync the live preview whenever the look actually changes (taps here, or
    // the saved look resolving asynchronously on first open).
    if (selection != _applied) {
      _applied = selection;
      _game.updateSelection(selection);
    }

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      appBar: AppBar(
        title: const Text('Customize Character'),
        backgroundColor: StoriaColors.paper,
        foregroundColor: StoriaColors.ink,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Live preview ──
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: StoriaColors.paperAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StoriaColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: GameWidget(game: _game),
            ),
          ),

          // ── Slot tabs ──
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final slot in CharacterCatalog.slots)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(CharacterCatalog.slotLabel(slot)),
                      selected: _slot == slot,
                      onSelected: (_) => setState(() => _slot = slot),
                    ),
                  ),
              ],
            ),
          ),

          // ── Variant options for the active slot ──
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (CharacterCatalog.allowsNone(_slot))
                    _OptionChip(
                      label: 'None',
                      selected: selection[_slot] == null,
                      onTap: () => _select(_slot, null),
                    ),
                  for (final key in CharacterCatalog.variants[_slot]!)
                    _OptionChip(
                      label: CharacterCatalog.variantLabel(key),
                      selected: selection[_slot] == key,
                      onTap: () => _select(_slot, key),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
