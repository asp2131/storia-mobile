import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../../core/widgets/watercolor_scaffold.dart';
import '../data/child_profile_providers.dart';
import '../domain/child_profile.dart';

class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(childProfilesProvider);
    final activeId = ref.watch(activeChildProfileIdProvider);
    final selectionState = ref.watch(activeChildProfileIdStateProvider);

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      appBar: AppBar(
        title: const Text('Choose Reader'),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
      ),
      body: WatercolorScaffold(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(childProfilesProvider.future),
            child: profiles.when(
              loading: () => const _ProfilePickerLoading(),
              error: (error, _) => _ProfilePickerError(
                message: '$error',
                onRetry: () => ref.invalidate(childProfilesProvider),
              ),
              data: (profiles) => _ProfilePickerContent(
                profiles: profiles,
                activeId: activeId,
                isSaving: selectionState.isLoading,
                onSelect: (profile) => _selectProfile(context, ref, profile),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectProfile(
    BuildContext context,
    WidgetRef ref,
    ChildProfile profile,
  ) async {
    try {
      await ref
          .read(activeChildProfileIdStateProvider.notifier)
          .setActiveChildProfileId(profile.id);
      if (!context.mounted) {
        return;
      }
      context.go('/library');
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that reader.')),
      );
    }
  }
}

class _ProfilePickerContent extends StatelessWidget {
  const _ProfilePickerContent({
    required this.profiles,
    required this.activeId,
    required this.isSaving,
    required this.onSelect,
  });

  final List<ChildProfile> profiles;
  final String? activeId;
  final bool isSaving;
  final ValueChanged<ChildProfile> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= 720 ? 640.0 : double.infinity;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            StoriaSpacing.xl,
            StoriaSpacing.xl,
            StoriaSpacing.xl,
            StoriaSpacing.xxl,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Who is reading today?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: StoriaColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: StoriaSpacing.sm),
                    Text(
                      'Pick a child profile so Storia can save reading progress and analytics to the right reader.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: StoriaColors.inkMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: StoriaSpacing.xl),
                    if (profiles.isEmpty)
                      const _NoProfilesCard()
                    else ...[
                      ...profiles.map(
                        (profile) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: StoriaSpacing.lg,
                          ),
                          child: _ProfileChoiceCard(
                            profile: profile,
                            isSelected: profile.id == activeId,
                            isSaving: isSaving,
                            onTap: () => onSelect(profile),
                          ),
                        ),
                      ),
                      const SizedBox(height: StoriaSpacing.sm),
                      SketchButton(
                        label: 'Add another child',
                        leading: const Icon(Icons.add_rounded),
                        tone: SketchButtonTone.secondary,
                        onPressed: isSaving
                            ? null
                            : () => context.push('/profiles/new'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileChoiceCard extends StatelessWidget {
  const _ProfileChoiceCard({
    required this.profile,
    required this.isSelected,
    required this.isSaving,
    required this.onTap,
  });

  final ChildProfile profile;
  final bool isSelected;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? StoriaColors.sageDeep : StoriaColors.line;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Choose ${profile.displayName}',
      child: SketchCard(
        borderColor: borderColor,
        color: isSelected ? const Color(0xFFF2F9E8) : StoriaColors.paperRaised,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isSaving ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(StoriaSpacing.sm),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: StoriaColors.mustard,
                  foregroundColor: StoriaColors.ink,
                  child: Text(
                    profile.initials,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: StoriaSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: StoriaColors.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (profile.isDefault) ...[
                            const SizedBox(width: StoriaSpacing.sm),
                            const _DefaultBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: StoriaSpacing.xs),
                      Text(
                        _subtitleFor(profile),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: StoriaColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: StoriaSpacing.md),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: isSelected ? StoriaColors.sageDeep : StoriaColors.ink,
                  semanticLabel: isSelected ? 'Selected' : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleFor(ChildProfile profile) {
    final parts = <String>[profile.ageBand];
    final readingLevel = profile.readingLevel;
    if (readingLevel != null && readingLevel.isNotEmpty) {
      parts.add(readingLevel);
    }
    return parts.join(' • ');
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StoriaColors.sage,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StoriaColors.sageDeep),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'Default',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: StoriaColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _NoProfilesCard extends StatelessWidget {
  const _NoProfilesCard();

  @override
  Widget build(BuildContext context) {
    return SketchCard(
      child: Column(
        children: [
          const Icon(
            Icons.child_care_rounded,
            size: 44,
            color: StoriaColors.inkMuted,
          ),
          const SizedBox(height: StoriaSpacing.md),
          const Text(
            'No child profiles yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: StoriaColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: StoriaSpacing.sm),
          const Text(
            'Create a child profile to start saving progress for this reader.',
            textAlign: TextAlign.center,
            style: TextStyle(color: StoriaColors.inkMuted, height: 1.35),
          ),
          const SizedBox(height: StoriaSpacing.xl),
          SketchButton(
            label: 'Add child profile',
            leading: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/profiles/new'),
          ),
        ],
      ),
    );
  }
}

class _ProfilePickerLoading extends StatelessWidget {
  const _ProfilePickerLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 220),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ProfilePickerError extends StatelessWidget {
  const _ProfilePickerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(StoriaSpacing.xl),
      children: [
        const SizedBox(height: 80),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SketchCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 44,
                    color: StoriaColors.danger,
                  ),
                  const SizedBox(height: StoriaSpacing.md),
                  Text(
                    'Could not load child profiles',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: StoriaColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: StoriaSpacing.sm),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: StoriaColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: StoriaSpacing.xl),
                  SketchButton(
                    label: 'Try Again',
                    leading: const Icon(Icons.refresh_rounded),
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
