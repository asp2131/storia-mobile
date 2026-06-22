import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';
import 'gate_challenge_card.dart';
import 'gate_controller.dart';
import 'gate_state.dart';

export 'gate_challenge_card.dart' show GateChallengeCard;
export 'gate_controller.dart' show GateController;
export 'gate_lockout.dart' show GateLockout;
export 'gate_state.dart'
    show GateState, GateChallenging, GateLocked, GatePassed, GateCancelled;

class ParentalGate {
  ParentalGate._();

  static const solveSeconds = 30;

  static Future<bool> verify(BuildContext context) async {
    final controller = GateController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GateSheet(controller: controller),
    );
    controller.dispose();
    return result ?? false;
  }
}

class _GateSheet extends StatefulWidget {
  const _GateSheet({required this.controller});

  final GateController controller;

  @override
  State<_GateSheet> createState() => _GateSheetState();
}

class _GateSheetState extends State<_GateSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    final state = widget.controller.value;
    if (state is GatePassed && mounted) {
      Navigator.of(context).pop(true);
    } else if (state is GateCancelled && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: GateChallengeCard(
        controller: widget.controller,
        header: _GateHeaderIcon(),
        title: 'Grown-ups only',
        showCancel: true,
        onCancel: () => widget.controller.cancel(),
      ),
    );
  }
}

class _GateHeaderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: StoriaColors.paper,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.family_restroom_rounded,
        color: StoriaColors.ink,
        size: 28,
      ),
    );
  }
}
