import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/loratone_entry_colors.dart';
import '../../../core/theme/storia_motion.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../auth/presentation/widgets/story_entry_widgets.dart';
import '../domain/onboarding_answers.dart';
import '../domain/review_onboarding_profile.dart';

/// Six-step parent onboarding: name, age, reading style, goal, interests,
/// reading time. Persistence is the caller's job ([onFinish]) so the same flow
/// serves backend accounts and the App Review bypass.
class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key, required this.onFinish, this.onExit});

  /// Throwing keeps the parent on the last step with an error and their answers.
  final Future<void> Function(OnboardingAnswers answers) onFinish;

  /// Back from the first step. Null hides Back there (first-run, nowhere to go).
  final VoidCallback? onExit;

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  static const _stepCount = 6;

  final _nameController = TextEditingController();
  int _step = 0;
  ChildAgeRange? _ageRange;
  ReadingStyle? _readingStyle;
  ParentGoal? _goal;
  final Set<ReadingInterest> _interests = {};
  ReadingTime? _readingTime;
  bool _isSaving = false;
  String? _error;

  String get _name => _nameController.text.trim();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    setState(() => _step++);
  }

  void _back() {
    if (_isSaving) return;
    if (_step == 0) {
      widget.onExit?.call();
      return;
    }
    setState(() {
      _step--;
      _error = null;
    });
  }

  /// Single-choice steps advance on tap, after a beat so the pick registers.
  /// A second tap or Back during the beat must not advance twice.
  void _pickThenNext(VoidCallback pick) {
    setState(pick);
    final step = _step;
    unawaited(
      Future<void>.delayed(StoriaMotion.medium, () {
        if (mounted && _step == step) _next();
      }),
    );
  }

  Future<void> _finish() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onFinish(
        OnboardingAnswers(
          nickname: _name,
          ageRange: _ageRange!,
          goal: _goal!,
          readingStyle: _readingStyle,
          interests: Set.of(_interests),
          readingTime: _readingTime,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save right now. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: LoratoneEntryColors.paper,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      StoriaSpacing.sm,
                      StoriaSpacing.md,
                      StoriaSpacing.xl,
                      0,
                    ),
                    child: Row(
                      children: [
                        if (_step > 0 || widget.onExit != null)
                          IconButton(
                            tooltip: 'Back',
                            onPressed: _isSaving ? null : _back,
                            color: LoratoneEntryColors.blue,
                            icon: const Icon(Icons.chevron_left_rounded),
                            iconSize: 30,
                          )
                        else
                          const SizedBox(width: StoriaSpacing.lg),
                        Expanded(
                          child: _ProgressBar(step: _step, count: _stepCount),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      StoriaSpacing.xl,
                      StoriaSpacing.lg,
                      StoriaSpacing.xl,
                      0,
                    ),
                    child: _ReaderCard(
                      name: _name,
                      ageRange: _ageRange,
                      readingStyle: _readingStyle,
                      interestCount: _interests.length,
                      readingTime: _readingTime,
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: StoriaMotion.medium,
                      switchInCurve: StoriaMotion.emphasized,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0.06, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _stepBody(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody() => switch (_step) {
    0 => _StepLayout(
      title: "What's your reader's name?",
      subtitle: 'A nickname is perfect. It shows on their bookshelf.',
      footer: StoryEntryButton(
        label: 'Continue',
        onPressed: _name.isEmpty ? null : _next,
      ),
      child: StoryEntryTextField(
        controller: _nameController,
        hintText: 'Nickname',
        semanticLabel: "Child's nickname",
        inputFormatters: [LengthLimitingTextInputFormatter(30)],
        onSubmitted: (_) {
          if (_name.isNotEmpty) _next();
        },
      ),
    ),
    1 => _StepLayout(
      title: 'How old is $_name?',
      subtitle: 'We use this to pick stories at the right level.',
      child: _OptionList(
        children: [
          for (final range in ChildAgeRange.values)
            _OptionTile(
              label: range.label,
              selected: _ageRange == range,
              large: true,
              onTap: () => _pickThenNext(() => _ageRange = range),
            ),
        ],
      ),
    ),
    2 => _StepLayout(
      title: 'How does $_name read?',
      subtitle: 'Every story can read aloud, so any answer works.',
      footer: _SkipButton(onPressed: _next),
      child: _OptionList(
        children: [
          for (final style in ReadingStyle.values)
            _OptionTile(
              label: style.label,
              icon: style.icon,
              selected: _readingStyle == style,
              onTap: () => _pickThenNext(() => _readingStyle = style),
            ),
        ],
      ),
    ),
    3 => _StepLayout(
      title: 'What are you hoping for?',
      subtitle: 'Pick the one that fits best.',
      footer: StoryEntryButton(
        label: 'Continue',
        onPressed: _goal == null ? null : _next,
      ),
      child: _OptionList(
        children: [
          for (final goal in ParentGoal.values)
            _OptionTile(
              label: goal.label,
              selected: _goal == goal,
              onTap: () => setState(() => _goal = goal),
            ),
          AnimatedSize(
            duration: StoriaMotion.medium,
            curve: StoriaMotion.emphasized,
            alignment: Alignment.topCenter,
            child: _goal == null
                ? const SizedBox(width: double.infinity)
                : _GoalPayoff(text: _goal!.description),
          ),
        ],
      ),
    ),
    4 => _StepLayout(
      title: 'What does $_name love?',
      subtitle:
          'Pick as many as you like. It helps us choose what to make next.',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StoryEntryButton(
            label: 'Continue',
            onPressed: _interests.isEmpty ? null : _next,
          ),
          if (_interests.isEmpty) _SkipButton(onPressed: _next),
        ],
      ),
      child: Wrap(
        spacing: StoriaSpacing.sm,
        runSpacing: StoriaSpacing.sm,
        children: [
          for (final interest in ReadingInterest.values)
            _InterestChip(
              interest: interest,
              selected: _interests.contains(interest),
              onTap: () => setState(() {
                if (!_interests.remove(interest)) _interests.add(interest);
              }),
            ),
        ],
      ),
    ),
    _ => _StepLayout(
      title: 'When does $_name usually read?',
      subtitle: 'Optional. You can change this later.',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: StoriaSpacing.md),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: storyEntryText(
                  size: 15,
                  color: LoratoneEntryColors.coral,
                ),
              ),
            ),
          StoryEntryButton(
            label: _isSaving ? 'Saving…' : 'Start reading',
            onPressed: _isSaving ? null : _finish,
          ),
        ],
      ),
      child: _OptionList(
        children: [
          for (final time in ReadingTime.values)
            _OptionTile(
              label: time.label,
              icon: time.icon,
              selected: _readingTime == time,
              onTap: () => setState(
                () => _readingTime = _readingTime == time ? null : time,
              ),
            ),
        ],
      ),
    ),
  };
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step ${step + 1} of $count',
    child: Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: AnimatedContainer(
              duration: StoriaMotion.medium,
              curve: StoriaMotion.emphasized,
              height: 6,
              margin: EdgeInsets.only(left: i == 0 ? 0 : StoriaSpacing.xs),
              decoration: BoxDecoration(
                color: i <= step
                    ? LoratoneEntryColors.blue
                    : LoratoneEntryColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Fills in as the parent answers, in place of a mascot.
class _ReaderCard extends StatelessWidget {
  const _ReaderCard({
    required this.name,
    required this.ageRange,
    required this.readingStyle,
    required this.interestCount,
    required this.readingTime,
  });

  final String name;
  final ChildAgeRange? ageRange;
  final ReadingStyle? readingStyle;
  final int interestCount;
  final ReadingTime? readingTime;

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (ageRange != null) 'Age ${ageRange!.label}',
      if (readingStyle != null) readingStyle!.label,
      if (interestCount > 0)
        '$interestCount ${interestCount == 1 ? 'favorite' : 'favorites'}',
      if (readingTime != null) readingTime!.label,
    ];
    // Fixed height: a card that grows would shift the tap targets below it.
    return Container(
      padding: const EdgeInsets.all(StoriaSpacing.md),
      decoration: BoxDecoration(
        color: LoratoneEntryColors.sky,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: LoratoneEntryColors.blue,
            foregroundColor: LoratoneEntryColors.surface,
            child: name.isEmpty
                ? const Icon(Icons.auto_stories_rounded, size: 22)
                : Text(
                    name.characters.first.toUpperCase(),
                    style: storyEntryText(
                      size: 20,
                      weight: FontWeight.w900,
                      color: LoratoneEntryColors.surface,
                    ),
                  ),
          ),
          const SizedBox(width: StoriaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Your reader' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: storyEntryText(size: 18, weight: FontWeight.w900),
                ),
                const SizedBox(height: StoriaSpacing.xs),
                SizedBox(
                  height: 24,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final chip in chips)
                        Container(
                          margin: const EdgeInsets.only(
                            right: StoriaSpacing.xs,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: StoriaSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: const ShapeDecoration(
                            color: LoratoneEntryColors.surface,
                            shape: StadiumBorder(),
                          ),
                          child: Text(
                            chip,
                            style: storyEntryText(
                              size: 13,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            StoriaSpacing.xl,
            StoriaSpacing.xl,
            StoriaSpacing.xl,
            StoriaSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: storyEntryText(
                  size: 28,
                  weight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: StoriaSpacing.sm),
              Text(
                subtitle,
                style: storyEntryText(
                  size: 16,
                  color: LoratoneEntryColors.inkMuted,
                ),
              ),
              const SizedBox(height: StoriaSpacing.xl),
              child,
            ],
          ),
        ),
      ),
      if (footer != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            StoriaSpacing.xl,
            0,
            StoriaSpacing.xl,
            StoriaSpacing.lg,
          ),
          child: footer,
        ),
    ],
  );
}

class _OptionList extends StatelessWidget {
  const _OptionList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final child in children)
        Padding(
          padding: const EdgeInsets.only(bottom: StoriaSpacing.md),
          child: child,
        ),
    ],
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.large = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool large;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? LoratoneEntryColors.sky : LoratoneEntryColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? LoratoneEntryColors.blue : LoratoneEntryColors.line,
          width: selected ? 2 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: StoriaSpacing.lg,
            vertical: large ? StoriaSpacing.xl : StoriaSpacing.lg,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: LoratoneEntryColors.blue),
                const SizedBox(width: StoriaSpacing.md),
              ],
              Expanded(
                child: Text(
                  label,
                  style: storyEntryText(
                    size: large ? 24 : 17,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: LoratoneEntryColors.blue,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.interest,
    required this.selected,
    required this.onTap,
  });

  final ReadingInterest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? LoratoneEntryColors.blue : LoratoneEntryColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? LoratoneEntryColors.blue : LoratoneEntryColors.line,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StoriaSpacing.lg,
            vertical: StoriaSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                interest.icon,
                size: 20,
                color: selected
                    ? LoratoneEntryColors.surface
                    : LoratoneEntryColors.blue,
              ),
              const SizedBox(width: StoriaSpacing.sm),
              Text(
                interest.label,
                style: storyEntryText(
                  size: 16,
                  weight: FontWeight.w800,
                  color: selected
                      ? LoratoneEntryColors.surface
                      : LoratoneEntryColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GoalPayoff extends StatelessWidget {
  const _GoalPayoff({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(StoriaSpacing.lg),
    decoration: BoxDecoration(
      color: LoratoneEntryColors.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lightbulb_rounded, color: LoratoneEntryColors.coral),
        const SizedBox(width: StoriaSpacing.md),
        Expanded(
          child: Text(text, style: storyEntryText(size: 16, height: 1.45)),
        ),
      ],
    ),
  );
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: LoratoneEntryColors.blue,
      minimumSize: const Size(44, 48),
      textStyle: storyEntryText(size: 16, weight: FontWeight.w800),
    ),
    child: const Text('Skip for now'),
  );
}
