import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/storia_spacing.dart';
import '../../../routing/journey/journey_actions.dart';
import '../../child/data/child_profile_providers.dart';
import '../../reader/data/reading_checkpoint_provider.dart';
import '../../reader/domain/reader_capabilities.dart';
import '../../reader/domain/reading_checkpoint.dart';
import '../data/entry_flow_provider.dart';

/// Parent-only, explicit copy from this device's guest bookmark to one child.
class SaveStoryScreen extends ConsumerStatefulWidget {
  const SaveStoryScreen({super.key});

  @override
  ConsumerState<SaveStoryScreen> createState() => _SaveStoryScreenState();
}

class _SaveStoryScreenState extends ConsumerState<SaveStoryScreen> {
  bool _saving = false;
  bool _conflict = false;
  String? _error;

  Future<void> _save({
    bool replaceExisting = false,
    bool keepExisting = false,
  }) async {
    if (_saving) return;
    final entry = ref.read(entryFlowProvider);
    final owner = ref.read(readingOwnerProvider);
    if (!entry.isParentAuthorized ||
        !entry.isAdultVerified ||
        !entry.hasPendingSampleSave ||
        owner == null ||
        owner.isGuest) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = await ref.read(
        readingCheckpointRepositoryProvider.future,
      );
      if (keepExisting) {
        final existing = await repository.load(owner, sampleBookId);
        if (existing == null) {
          throw StateError('The saved position is no longer available.');
        }
      } else {
        final result = await repository.claimSample(
          child: owner,
          bookId: sampleBookId,
          replaceExisting: replaceExisting,
        );
        if (result == CheckpointClaimResult.existingProgress) {
          if (mounted) setState(() => _conflict = true);
          return;
        }
      }
      if (!mounted) return;
      // An account/profile switch or expired gate cannot finish an old claim UI.
      final currentEntry = ref.read(entryFlowProvider);
      if (ref.read(readingOwnerProvider) != owner ||
          !currentEntry.isParentAuthorized ||
          !currentEntry.isAdultVerified) {
        return;
      }
      ref.invalidate(
        readingCheckpointProvider((owner: owner, bookId: sampleBookId)),
      );
      ref.invalidate(readerOpeningCheckpointProvider(sampleBookId));
      ref.invalidate(readingContinuationProvider);
      confirmSampleSave(ref, context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save on this device. Your guest reading place is still here. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(entryFlowProvider);
    final owner = ref.watch(readingOwnerProvider);
    final child = ref.watch(activeChildProfileProvider).valueOrNull;
    if (!entry.isParentAuthorized ||
        !entry.isAdultVerified ||
        !entry.hasPendingSampleSave ||
        owner == null ||
        owner.isGuest ||
        child == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Save your story')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(StoriaSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Save for ${child.displayName}?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: StoriaSpacing.md),
              const Text(
                'Reading place is saved on this device, not synced to other devices.',
              ),
              if (_conflict) ...[
                const SizedBox(height: StoriaSpacing.lg),
                const Text(
                  'This child already has a different reading place. Which one should we keep?',
                ),
                FilledButton(
                  onPressed: _saving ? null : () => _save(keepExisting: true),
                  child: const Text('Keep existing position'),
                ),
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => _save(replaceExisting: true),
                  child: const Text('Use this reading position'),
                ),
              ] else ...[
                const SizedBox(height: StoriaSpacing.lg),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save and return to story'),
                ),
              ],
              if (_saving)
                const Padding(
                  padding: EdgeInsets.all(StoriaSpacing.md),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: StoriaSpacing.md),
                  child: Text(_error!),
                ),
              TextButton(
                onPressed: _saving ? null : () => continueJourney(ref, context),
                child: const Text('Choose a different child'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
