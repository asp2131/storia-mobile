import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entry_flow_state.dart';

/// Owns both the entry snapshot and the router's entry refresh source.
///
/// ChangeNotifierProvider owns disposal; do not also register ref.onDispose.
final entryFlowNotifierProvider = ChangeNotifierProvider<EntryFlowNotifier>(
  (ref) => EntryFlowNotifier(),
);

final entryFlowProvider = Provider<EntryFlowState>((ref) {
  return ref.watch(entryFlowNotifierProvider).state;
});

/// Temporary parent authorization, independent of auth and App Review storage.
///
/// No preferences or backend session can restore a passed gate or birth year.
/// [hydration] may hold readiness while local entry prerequisites hydrate; it
/// cannot supply authorization. Await [ready] to surface a failed prerequisite.
class EntryFlowNotifier extends ChangeNotifier with WidgetsBindingObserver {
  EntryFlowNotifier({
    DateTime Function()? clock,
    Future<void>? hydration,
    WidgetsBinding? binding,
  }) : _clock = clock ?? DateTime.now,
       _binding = binding ?? WidgetsBinding.instance {
    _isBackgrounded = switch (_binding.lifecycleState) {
      AppLifecycleState.inactive ||
      AppLifecycleState.hidden ||
      AppLifecycleState.paused => true,
      _ => false,
    };
    _binding.addObserver(this);
    ready = _hydrate(hydration);
  }

  static const parentAccessDuration = Duration(minutes: 10);
  static const _earliestBirthYear = 1930;

  final DateTime Function() _clock;
  final WidgetsBinding _binding;
  late final Future<void> ready;

  bool _disposed = false;
  bool _isReady = false;
  bool _isBackgrounded = false;
  bool _authRoundTripPending = false;
  bool _notificationScheduled = false;
  EntryAuthIntent? _pendingAuthIntent;
  SampleSaveDestination? _pendingSampleSave;
  DateTime? _parentAccessExpiresAt;
  int? _parentBirthYear;
  Timer? _accessTimer;
  EntryFlowState _state = const EntryFlowState(isReady: false);

  EntryFlowState get state {
    // Clock changes can precede the timer. Never expose expired authorization
    // even if a router snapshot is read before the timer callback runs.
    if (!_disposed && _expireParentAccess(notify: false)) {
      _scheduleNotification();
    }
    return _state;
  }

  Future<void> _hydrate(Future<void>? hydration) async {
    await (hydration ?? Future<void>.value());
    if (_disposed) return;
    _isReady = true;
    _publish();
  }

  /// Records a parent action before opening the existing parental gate.
  ///
  /// Calling this, including from a deep link, never grants authorization. An
  /// unclaimed sample return survives cancellation and another parent attempt.
  void beginParentEntry(EntryAuthIntent intent, {bool saveSample = false}) {
    if (!_canMutate) return;
    _expireParentAccess();
    _pendingAuthIntent = intent;
    if (saveSample) {
      _pendingSampleSave = SampleSaveDestination.sampleReader;
    }
    _publish();
  }

  /// Call only after the existing parental challenge explicitly passes.
  ///
  /// Repeated success callbacks during a live window do not extend its deadline.
  /// A newly passed gate after relocking starts a new window and needs a new
  /// adult-year check. Gate cancellation or lockout must never call this method.
  bool authorizeParentAfterPassedGate() {
    if (!_canMutate || _isBackgrounded || _pendingAuthIntent == null) {
      return false;
    }
    _expireParentAccess();
    if (_parentAccessExpiresAt != null) return true;
    _parentAccessExpiresAt = _clock().add(parentAccessDuration);
    _parentBirthYear = null;
    _authRoundTripPending = false;
    _scheduleAccessTimer();
    _publish();
    return true;
  }

  /// Applies the existing four-digit, 18+ year-only check using the clock.
  ///
  /// This is not exact age verification or verified parental consent. The raw
  /// birth year stays private and is never part of a snapshot or analytics.
  bool verifyAdultYear(int birthYear) {
    if (!_canMutate || _isBackgrounded) return false;
    _expireParentAccess();
    if (_parentAccessExpiresAt == null) return false;
    final isAdult =
        birthYear >= _earliestBirthYear && birthYear <= _clock().year - 18;
    _parentBirthYear = isAdult ? birthYear : null;
    if (!isAdult) _authRoundTripPending = false;
    _publish();
    return isAdult;
  }

  /// Narrow handoff for the separate reviewer flow when its activation resets
  /// review storage. Never persist this value as normal parent authorization.
  int? verifiedParentBirthYearForReview() {
    if (!_canMutate) return null;
    _expireParentAccess();
    return _parentBirthYear;
  }

  /// Call immediately before launching OAuth or requesting a mail link/code.
  ///
  /// A live gate and adult-year check are required. Merely receiving an auth
  /// callback, or foregrounding the app, cannot start or renew this exception.
  bool beginAuthRoundTrip() {
    if (!_canMutate || _isBackgrounded) return false;
    _expireParentAccess();
    if (_parentAccessExpiresAt == null ||
        _parentBirthYear == null ||
        _pendingAuthIntent == null) {
      return false;
    }
    _authRoundTripPending = true;
    return true;
  }

  /// Ends an explicitly started round trip without extending gate access.
  ///
  /// An auth cancellation relocks but keeps the unclaimed sample destination.
  /// Late callbacks after expiry, invalidation or cold launch never grant access.
  void endAuthRoundTrip({bool cancelled = false}) {
    if (!_canMutate) return;
    _expireParentAccess();
    _authRoundTripPending = false;
    if (cancelled) {
      _clearParentAccess();
      _pendingAuthIntent = null;
      _publish();
    }
  }

  /// Relocks without touching reading checkpoints or an unclaimed return.
  ///
  /// Sign-out must pass [clearPendingIntent] to remove both the requested auth
  /// operation and the sample claim intent before another account can sign in.
  void invalidateParentAccess({bool clearPendingIntent = false}) {
    if (_disposed) return;
    _clearParentAccess();
    if (clearPendingIntent) {
      _pendingAuthIntent = null;
      _pendingSampleSave = null;
    }
    _publish();
  }

  /// Call only after an explicitly confirmed claim has succeeded (including an
  /// already-saved result). A failed/conflicting save must keep this intent.
  void clearPendingSave() {
    if (!_canMutate) return;
    _pendingSampleSave = null;
    _publish();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    _isBackgrounded = state != AppLifecycleState.resumed;
    _expireParentAccess();
    switch (state) {
      case AppLifecycleState.resumed:
        // No callback or foreground transition grants authorization.
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (!_authRoundTripPending) invalidateParentAccess();
      case AppLifecycleState.detached:
        invalidateParentAccess();
    }
  }

  bool get _canMutate => !_disposed && _isReady;

  bool _expireParentAccess({bool notify = true}) {
    final expiresAt = _parentAccessExpiresAt;
    if (expiresAt == null || _clock().isBefore(expiresAt)) return false;
    _clearParentAccess();
    _publish(notify: notify);
    return true;
  }

  void _clearParentAccess() {
    _parentAccessExpiresAt = null;
    _parentBirthYear = null;
    _authRoundTripPending = false;
    _accessTimer?.cancel();
    _accessTimer = null;
  }

  void _scheduleAccessTimer() {
    _accessTimer?.cancel();
    final expiresAt = _parentAccessExpiresAt;
    if (expiresAt == null || _disposed) return;
    _accessTimer = Timer(expiresAt.difference(_clock()), () {
      _accessTimer = null;
      if (_disposed) return;
      if (!_expireParentAccess()) _scheduleAccessTimer();
    });
  }

  void _publish({bool notify = true}) {
    if (_disposed) return;
    final isParentAuthorized = _parentAccessExpiresAt != null;
    final isAdultVerified = isParentAuthorized && _parentBirthYear != null;
    if (_state.isReady == _isReady &&
        _state.pendingAuthIntent == _pendingAuthIntent &&
        _state.isParentAuthorized == isParentAuthorized &&
        _state.isAdultVerified == isAdultVerified &&
        _state.pendingSampleSave == _pendingSampleSave) {
      return;
    }
    _state = EntryFlowState(
      isReady: _isReady,
      pendingAuthIntent: _pendingAuthIntent,
      isParentAuthorized: isParentAuthorized,
      isAdultVerified: isAdultVerified,
      pendingSampleSave: _pendingSampleSave,
    );
    if (notify) notifyListeners();
  }

  void _scheduleNotification() {
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    scheduleMicrotask(() {
      _notificationScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _clearParentAccess();
    _pendingAuthIntent = null;
    _pendingSampleSave = null;
    _publish(notify: false);
    _disposed = true;
    _binding.removeObserver(this);
    super.dispose();
  }
}
