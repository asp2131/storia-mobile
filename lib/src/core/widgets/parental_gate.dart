import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/storia_colors.dart';
import 'sketch_button.dart';
import 'sketch_card.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Converts an integer 0-99 to its English word form.
String numberToWords(int n) {
  const ones = [
    'zero', 'one', 'two', 'three', 'four', 'five',
    'six', 'seven', 'eight', 'nine', 'ten', 'eleven',
    'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
    'seventeen', 'eighteen', 'nineteen',
  ];
  const tens = [
    '', '', 'twenty', 'thirty', 'forty',
    'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
  ];

  assert(n >= 0 && n < 100, 'numberToWords only handles 0-99');

  if (n < 20) return ones[n];
  if (n % 10 == 0) return tens[n ~/ 10];
  return '${tens[n ~/ 10]}-${ones[n % 10]}';
}

/// Generates a random addition challenge with two-digit operands.
({int a, int b, int answer, String question}) generateGateChallenge(
  Random random,
) {
  final a = 11 + random.nextInt(25);
  final b = 10 + random.nextInt(20);
  final answer = a + b;
  final question =
      'What is ${numberToWords(a)} plus ${numberToWords(b)}?';
  return (a: a, b: b, answer: answer, question: question);
}

String formatCountdown(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Progressive lockout — shared across all gate surfaces
// ---------------------------------------------------------------------------

/// Tracks consecutive failures across every parental-gate invocation so a
/// child cannot simply dismiss one gate and retry on a different action.
class GateLockout {
  GateLockout._();

  static const _shortLockout = Duration(seconds: 30);
  static const _longLockout = Duration(minutes: 2);
  static const _longLockoutThreshold = 3;

  static int _consecutiveFailures = 0;
  static DateTime? _lockedUntil;

  static bool get isLocked {
    final until = _lockedUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _lockedUntil = null;
      return false;
    }
    return true;
  }

  static int get remainingSeconds {
    final until = _lockedUntil;
    if (until == null) return 0;
    final diff = until.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  static void recordFailure() {
    _consecutiveFailures++;
    final duration = _consecutiveFailures >= _longLockoutThreshold
        ? _longLockout
        : _shortLockout;
    _lockedUntil = DateTime.now().add(duration);
  }

  static void recordSuccess() {
    _consecutiveFailures = 0;
    _lockedUntil = null;
  }
}

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/// A non-disableable parental gate that presents a random word-form arithmetic
/// challenge with a 30-second countdown and progressive lockout on failure.
class ParentalGate {
  ParentalGate._();

  static const solveSeconds = 30;

  static Future<bool> verify(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ParentalGateSheet(),
    );
    return result ?? false;
  }
}

// ---------------------------------------------------------------------------
// Bottom-sheet implementation
// ---------------------------------------------------------------------------

class _ParentalGateSheet extends StatefulWidget {
  const _ParentalGateSheet();

  @override
  State<_ParentalGateSheet> createState() => _ParentalGateSheetState();
}

class _ParentalGateSheetState extends State<_ParentalGateSheet> {
  static final _random = Random();

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _ticker;
  late int _answer;
  late String _question;
  String? _errorMessage;

  int _solveSecondsLeft = ParentalGate.solveSeconds;
  bool _isLockedOut = false;
  int _lockoutSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    if (GateLockout.isLocked) {
      _isLockedOut = true;
      _lockoutSecondsLeft = GateLockout.remainingSeconds;
      _regenerate();
    } else {
      _regenerate();
      _solveSecondsLeft = ParentalGate.solveSeconds;
    }
    _startTicker();
  }

  void _regenerate() {
    final c = generateGateChallenge(_random);
    _answer = c.answer;
    _question = c.question;
    _controller.clear();
    _errorMessage = null;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_isLockedOut) {
          _lockoutSecondsLeft--;
          if (_lockoutSecondsLeft <= 0) {
            _isLockedOut = false;
            _regenerate();
            _solveSecondsLeft = ParentalGate.solveSeconds;
          }
        } else {
          _solveSecondsLeft--;
          if (_solveSecondsLeft <= 0) {
            _onFailure();
          }
        }
      });
    });
  }

  void _onFailure() {
    GateLockout.recordFailure();
    _isLockedOut = true;
    _lockoutSecondsLeft = GateLockout.remainingSeconds;
    _errorMessage = null;
    _controller.clear();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final input = int.tryParse(_controller.text.trim());
    if (input == null) {
      setState(() => _errorMessage = 'Please enter a number.');
      return;
    }

    if (input == _answer) {
      GateLockout.recordSuccess();
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _onFailure());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: SketchCard(
        color: const Color(0xFF4A5BE7),
        borderColor: const Color(0xFF3544C4),
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        child: _isLockedOut ? _buildLockout(textTheme) : _buildChallenge(textTheme),
      ),
    );
  }

  Widget _buildChallenge(TextTheme textTheme) {
    final timerColor = _solveSecondsLeft <= 10
        ? const Color(0xFFFFB4B4)
        : StoriaColors.paper.withValues(alpha: 0.7);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFFF8F5ED),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.family_restroom_rounded,
            color: StoriaColors.ink,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Grown-ups only',
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(
            color: StoriaColors.paper,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatCountdown(_solveSecondsLeft),
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
            _question,
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
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: StoriaColors.ink,
            ),
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
              if (_errorMessage != null) {
                setState(() => _errorMessage = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFFFD4D4),
            ),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
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
        ),
      ],
    );
  }

  Widget _buildLockout(TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFFF8F5ED),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_clock_rounded,
            color: StoriaColors.ink,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Please wait',
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(
            color: StoriaColors.paper,
          ),
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
          formatCountdown(_lockoutSecondsLeft),
          textAlign: TextAlign.center,
          style: textTheme.displaySmall?.copyWith(
            color: StoriaColors.paper,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 22),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: textTheme.bodyLarge?.copyWith(
              color: StoriaColors.paper.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}
