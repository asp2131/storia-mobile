import 'package:shared_preferences/shared_preferences.dart';

typedef GateClock = DateTime Function();

class GateLockout {
  GateLockout({GateClock? now, SharedPreferences? prefs})
      : _now = now ?? DateTime.now,
        _prefs = prefs {
    _loadFromPrefs();
  }

  static const _shortLockout = Duration(seconds: 30);
  static const _longLockout = Duration(minutes: 2);
  static const _longLockoutThreshold = 3;

  static const _kLockoutUntilKey = 'gate_lockout_until';
  static const _kFailuresKey = 'gate_lockout_failures';

  static final GateLockout instance = GateLockout();

  final GateClock _now;
  SharedPreferences? _prefs;

  int _consecutiveFailures = 0;
  DateTime? _lockedUntil;

  bool get isLocked {
    final until = _lockedUntil;
    if (until == null) return false;
    if (_now().isAfter(until)) {
      _lockedUntil = null;
      _consecutiveFailures = 0;
      _persist();
      return false;
    }
    return true;
  }

  int get remainingSeconds {
    final until = _lockedUntil;
    if (until == null) return 0;
    final diff = until.difference(_now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void recordFailure() {
    _consecutiveFailures++;
    final duration = _consecutiveFailures >= _longLockoutThreshold
        ? _longLockout
        : _shortLockout;
    _lockedUntil = _now().add(duration);
    _persist();
  }

  void recordSuccess() {
    _consecutiveFailures = 0;
    _lockedUntil = null;
    _persist();
  }

  void reset() {
    _consecutiveFailures = 0;
    _lockedUntil = null;
    _persist();
  }

  Future<void> loadFromPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final prefs = _prefs;
    if (prefs == null) return;
    final untilMillis = prefs.getInt(_kLockoutUntilKey);
    if (untilMillis != null) {
      _lockedUntil = DateTime.fromMillisecondsSinceEpoch(untilMillis);
    }
    _consecutiveFailures = prefs.getInt(_kFailuresKey) ?? 0;
    isLocked;
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;
    final until = _lockedUntil;
    if (until != null) {
      prefs.setInt(_kLockoutUntilKey, until.millisecondsSinceEpoch);
    } else {
      prefs.remove(_kLockoutUntilKey);
    }
    prefs.setInt(_kFailuresKey, _consecutiveFailures);
  }
}
