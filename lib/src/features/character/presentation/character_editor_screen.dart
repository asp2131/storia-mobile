import 'package:flutter/material.dart';

import '../../../core/theme/storia_colors.dart';
import '../../library/game/character/character_selection.dart';

/// Character customization screen.
///
/// ponytail: scaffold only — lists the currently equipped parts. Real
/// per-slot/variant editing arrives with the Supabase asset pipeline
/// (sub-project 2) and the slot picker (sub-project 3); this screen is the
/// reachable entry point those build on.
class CharacterEditorScreen extends StatelessWidget {
  const CharacterEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Until persistence (sub-project 3) lands, show the bundled default look.
    final selection = CharacterSelection.defaults();
    final equipped = selection.equipped.toList();

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      appBar: AppBar(
        title: const Text('Customize Character'),
        backgroundColor: StoriaColors.paper,
        foregroundColor: StoriaColors.ink,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Your character',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final entry in equipped)
            ListTile(
              dense: true,
              title: Text(entry.key.name),
              trailing: Text(entry.value ?? '—'),
            ),
          const SizedBox(height: 24),
          const Text(
            'Pick-your-own parts arrive once the character pack loads.',
            style: TextStyle(color: StoriaColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
