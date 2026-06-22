import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'gate_lockout.dart';
import 'gate_state.dart';

String _numberToWords(int n) {
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

  if (n < 20) return ones[n];
  if (n % 10 == 0) return tens[n ~/ 10];
  return '${tens[n ~/ 10]}-${ones[n % 10]}';
}

({int a, int b, int answer, String question}) _generateChallenge(Random random) {
  final a = 11 + random.nextInt(25);
  final b = 10 + random.nextInt(20);
  final answer = a + b;
  final question = 'What is ${_numberToWords(a)} plus ${_numberToWords(b)}?';
  return (a: a, b: b, answer: answer, question: question);
}

class GateController extends ValueNotifier<GateState> {
  GateController({
    Random? random,
    GateLockout? lockout,
    int solveSeconds = 30,
    bool autoTick = true,
  })  : _random = random ?? Random(),
        _lockout = lockout ?? GateLockout.instance,
        _solveSeconds = solveSeconds,
        super(const GateCancelled()) {
    _bootstrap();
    if (autoTick) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_disposed) tick();
      });
    }
  }

  final Random _random;
  final GateLockout _lockout;
  final int _solveSeconds;

  Timer? _ticker;
  bool _disposed = false;

  void _bootstrap() {
    if (_lockout.isLocked) {
      value = GateLocked(_lockout.remainingSeconds);
    } else {
      _regenerate();
    }
  }

  void _regenerate() {
    final c = _generateChallenge(_random);
    value = GateChallenging(
      question: c.question,
      answer: c.answer,
      solveSecondsLeft: _solveSeconds,
    );
  }

  void tick() {
    final s = value;
    switch (s) {
      case GateChallenging():
        final left = s.solveSecondsLeft - 1;
        if (left <= 0) {
          _lockout.recordFailure();
          value = GateLocked(_lockout.remainingSeconds);
        } else {
          value = GateChallenging(
            question: s.question,
            answer: s.answer,
            solveSecondsLeft: left,
            error: s.error,
          );
        }
      case GateLocked():
        final left = s.lockoutSecondsLeft - 1;
        if (left <= 0) {
          _regenerate();
        } else {
          value = GateLocked(left);
        }
      case GatePassed():
      case GateCancelled():
    }
  }

  void submitAnswer(String input) {
    final s = value;
    if (s is! GateChallenging) return;

    final parsed = int.tryParse(input.trim());
    if (parsed == null) {
      value = GateChallenging(
        question: s.question,
        answer: s.answer,
        solveSecondsLeft: s.solveSecondsLeft,
        error: 'Please enter a number.',
      );
      return;
    }

    if (parsed == s.answer) {
      _lockout.recordSuccess();
      value = const GatePassed();
      return;
    }

    _lockout.recordFailure();
    value = GateLocked(_lockout.remainingSeconds);
  }

  void clearError() {
    final s = value;
    if (s is GateChallenging && s.error != null) {
      value = GateChallenging(
        question: s.question,
        answer: s.answer,
        solveSecondsLeft: s.solveSecondsLeft,
      );
    }
  }

  void cancel() {
    value = const GateCancelled();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
