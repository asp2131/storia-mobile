import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/storia_colors.dart';
import 'gate_controller.dart';
import 'gate_state.dart';
import 'sketch_button.dart';
import 'sketch_card.dart';

String _formatCountdown(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

Widget _defaultLockIcon() {
  return Container(
    width: 48,
    height: 48,
    decoration: const BoxDecoration(
      color: StoriaColors.paper,
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.lock_clock_rounded,
      color: StoriaColors.ink,
      size: 28,
    ),
  );
}

class GateChallengeCard extends StatefulWidget {
  const GateChallengeCard({
    super.key,
    required this.controller,
    required this.header,
    required this.title,
    this.showCancel = true,
    this.onCancel,
  });

  final GateController controller;
  final Widget header;
  final String title;
  final bool showCancel;
  final VoidCallback? onCancel;

  @override
  State<GateChallengeCard> createState() => _GateChallengeCardState();
}

class _GateChallengeCardState extends State<GateChallengeCard> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    widget.controller.submitAnswer(_inputController.text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.value;
        return SketchCard(
          color: StoriaColors.ink,
          borderColor: StoriaColors.inkDeep,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          child: switch (state) {
            GateChallenging() => _buildChallenge(context, state),
            GateLocked() => _buildLockout(context, state),
            GatePassed() || GateCancelled() => const SizedBox.shrink(),
          },
        );
      },
    );
  }

  Widget _buildChallenge(BuildContext context, GateChallenging state) {
    final textTheme = Theme.of(context).textTheme;
    final timerColor = state.solveSecondsLeft <= 10
        ? StoriaColors.gateTimerWarning
        : StoriaColors.paper.withValues(alpha: 0.7);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.header,
        const SizedBox(height: 18),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(color: StoriaColors.paper),
        ),
        const SizedBox(height: 6),
        Text(
          _formatCountdown(state.solveSecondsLeft),
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            color: timerColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            state.question,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: StoriaColors.paper.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _inputController,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(color: StoriaColors.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: '???',
              hintStyle: textTheme.headlineSmall?.copyWith(
                color: StoriaColors.ink.withValues(alpha: 0.3),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (_) {
              if (state.error != null) {
                widget.controller.clearError();
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (state.error != null) ...[
          const SizedBox(height: 14),
          Text(
            state.error!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: StoriaColors.gateError,
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (widget.showCancel)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: Text(
                  'Cancel',
                  style: textTheme.bodyLarge?.copyWith(
                    color: StoriaColors.paper.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SketchButton(
                label: 'Continue',
                expand: false,
                onPressed: _submit,
              ),
            ],
          )
        else
          SketchButton(
            label: 'Continue',
            expand: false,
            onPressed: _submit,
          ),
      ],
    );
  }

  Widget _buildLockout(BuildContext context, GateLocked state) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _defaultLockIcon(),
        const SizedBox(height: 18),
        Text(
          'Please wait',
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(color: StoriaColors.paper),
        ),
        const SizedBox(height: 10),
        Text(
          'Please try again in',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: StoriaColors.paper.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatCountdown(state.lockoutSecondsLeft),
          textAlign: TextAlign.center,
          style: textTheme.displaySmall?.copyWith(
            color: StoriaColors.paper,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (widget.showCancel) ...[
          const SizedBox(height: 22),
          TextButton(
            onPressed: widget.onCancel,
            child: Text(
              'Cancel',
              style: textTheme.bodyLarge?.copyWith(
                color: StoriaColors.paper.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
