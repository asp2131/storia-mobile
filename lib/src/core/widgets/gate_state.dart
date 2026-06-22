sealed class GateState {
  const GateState();
}

final class GateChallenging extends GateState {
  const GateChallenging({
    required this.question,
    required this.answer,
    required this.solveSecondsLeft,
    this.error,
  });

  final String question;
  final int answer;
  final int solveSecondsLeft;
  final String? error;
}

final class GateLocked extends GateState {
  const GateLocked(this.lockoutSecondsLeft);

  final int lockoutSecondsLeft;
}

final class GatePassed extends GateState {
  const GatePassed();
}

final class GateCancelled extends GateState {
  const GateCancelled();
}
