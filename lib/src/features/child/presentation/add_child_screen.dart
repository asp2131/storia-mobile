import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../../core/widgets/sketch_icon_button.dart';
import '../../../core/widgets/sketch_text_field.dart';
import '../../../core/widgets/watercolor_scaffold.dart';
import '../../../routing/journey/journey_actions.dart';
import '../data/child_profile_providers.dart';
import '../data/child_profile_repository.dart';
import '../domain/child_profile.dart';

class AddChildScreen extends ConsumerStatefulWidget {
  const AddChildScreen({super.key});

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  static const List<String> _ageBands = ['0-2', '3-4', '5-6', '7-9', '10-12'];

  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _readingLevelController = TextEditingController();
  final _displayNameFocusNode = FocusNode();
  final _readingLevelFocusNode = FocusNode();

  String? _selectedAgeBand;
  bool _isDefault = true;
  bool _isSubmitting = false;
  bool _didAttemptSubmit = false;
  String? _submitError;

  @override
  void dispose() {
    _displayNameController.dispose();
    _readingLevelController.dispose();
    _displayNameFocusNode.dispose();
    _readingLevelFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      body: WatercolorScaffold(
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: FocusTraversalGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SketchIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: _isSubmitting
                              ? null
                              : () => backOutOfJourneyStep(context),
                          tooltip: 'Back to reader chooser',
                        ),
                        const SizedBox(height: StoriaSpacing.xl),
                        SketchCard(
                          color: Colors.white.withValues(alpha: 0.94),
                          padding: const EdgeInsets.all(StoriaSpacing.xl),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: StoriaColors.sage.withValues(
                                    alpha: 0.9,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: StoriaColors.ink,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.child_care_rounded,
                                  color: StoriaColors.ink,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: StoriaSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add a child profile',
                                      style: textTheme.headlineSmall?.copyWith(
                                        color: StoriaColors.ink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: StoriaSpacing.sm),
                                    Text(
                                      'Create a reading profile so Loratone can save progress and analytics for the right child.',
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: StoriaColors.inkMuted,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: StoriaSpacing.lg),
                        SketchCard(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Profile details',
                                  style: textTheme.titleLarge?.copyWith(
                                    color: StoriaColors.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: StoriaSpacing.sm),
                                Text(
                                  'Display name and age band are required. Reading level is optional.',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: StoriaColors.inkMuted,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Semantics(
                                  textField: true,
                                  label: 'Child display name',
                                  child: TextFormField(
                                    controller: _displayNameController,
                                    focusNode: _displayNameFocusNode,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    keyboardType: TextInputType.name,
                                    enabled: !_isSubmitting,
                                    cursorColor: StoriaColors.ink,
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: StoriaColors.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(40),
                                    ],
                                    decoration: _inputDecoration(
                                      context,
                                      label: 'Display name',
                                      hintText: 'Ava',
                                      leading: const Icon(Icons.badge_outlined),
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'Enter a display name.';
                                      }
                                      return null;
                                    },
                                    onFieldSubmitted: (_) =>
                                        _readingLevelFocusNode.requestFocus(),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Age band',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FontStyle.italic,
                                    color: StoriaColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _ageBands
                                      .map(
                                        (ageBand) => _AgeBandChip(
                                          label: ageBand,
                                          selected: _selectedAgeBand == ageBand,
                                          enabled: !_isSubmitting,
                                          onTap: () => setState(
                                            () => _selectedAgeBand = ageBand,
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                                if (_showAgeBandError) ...[
                                  const SizedBox(height: StoriaSpacing.sm),
                                  Text(
                                    'Choose an age band.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: StoriaColors.danger,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                SketchTextField(
                                  controller: _readingLevelController,
                                  label: 'Reading level (optional)',
                                  hintText: 'Early reader',
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.done,
                                  leading: const Icon(
                                    Icons.auto_stories_outlined,
                                  ),
                                  onSubmitted: (_) => _submit(),
                                ),
                                const SizedBox(height: 18),
                                Semantics(
                                  container: true,
                                  child: Material(
                                    color: StoriaColors.paperAlt,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: const BorderSide(
                                        color: StoriaColors.line,
                                        width: 1.2,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: SwitchListTile.adaptive(
                                      value: _isDefault,
                                      onChanged: _isSubmitting
                                          ? null
                                          : (value) => setState(
                                              () => _isDefault = value,
                                            ),
                                      activeThumbColor: StoriaColors.ink,
                                      activeTrackColor: StoriaColors.sage,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: StoriaSpacing.lg,
                                            vertical: StoriaSpacing.sm,
                                          ),
                                      title: Text(
                                        'Make this default child',
                                        style: textTheme.titleMedium?.copyWith(
                                          color: StoriaColors.ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Loratone opens the library with this reader selected first.',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: StoriaColors.inkMuted,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_submitError != null) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    _submitError!,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: StoriaColors.danger,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: StoriaSpacing.xl),
                                SketchButton(
                                  label: 'Save child profile',
                                  trailing: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                  isLoading: _isSubmitting,
                                  onPressed: _isSubmitting ? null : _submit,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _showAgeBandError => _didAttemptSubmit && _selectedAgeBand == null;

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required String hintText,
    Widget? leading,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      filled: true,
      fillColor: StoriaColors.paperAlt,
      prefixIcon: leading,
      prefixIconColor: StoriaColors.ink,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: _outlineBorder(StoriaColors.line),
      enabledBorder: _outlineBorder(StoriaColors.line),
      focusedBorder: _outlineBorder(StoriaColors.dustyPink),
      errorBorder: _outlineBorder(StoriaColors.danger),
      focusedErrorBorder: _outlineBorder(StoriaColors.danger),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: StoriaColors.ink.withValues(alpha: 0.56),
        fontWeight: FontWeight.w600,
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: StoriaColors.ink,
        fontWeight: FontWeight.w700,
      ),
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(
        color: StoriaColors.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  OutlineInputBorder _outlineBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: 1.2),
    );
  }

  String _errorMessage(Object error) {
    if (error is ChildProfileRepositoryException) {
      return 'Save failed (HTTP ${error.statusCode ?? '?'})';
    }
    if (error is ChildProfileAuthException) {
      return error.message;
    }
    return 'Could not save this child profile.';
  }

  Future<void> _submit() async {
    final validForm = _formKey.currentState?.validate() ?? false;
    if (!validForm || _selectedAgeBand == null) {
      setState(() {
        _didAttemptSubmit = true;
        _submitError = null;
      });
      return;
    }

    setState(() {
      _didAttemptSubmit = true;
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await ref
          .read(childProfileActionsProvider)
          .createAndSelect(
            CreateChildProfileInput(
              displayName: _displayNameController.text,
              ageBand: _selectedAgeBand!,
              readingLevel: _readingLevelController.text,
              isDefault: _isDefault,
            ),
          );

      if (!mounted) {
        return;
      }
      continueJourney(ref, context);
    } catch (error, stackTrace) {
      debugPrint('[AddChildScreen] create child failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() => _submitError = _errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _AgeBandChip extends StatelessWidget {
  const _AgeBandChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected ? StoriaColors.sage : Colors.white;
    final borderColor = selected ? StoriaColors.ink : StoriaColors.lineStrong;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Age band $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.4),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72, minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: StoriaSpacing.lg,
                  vertical: StoriaSpacing.md,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: StoriaColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
