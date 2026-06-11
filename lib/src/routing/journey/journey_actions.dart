/// Screen-facing journey verbs — the ergonomic layer over [JourneyPolicy].
///
/// One verb per empirically-observed caller pattern (see the call-site
/// census in docs/design-drafts/journey-policy-caller.md). Screens must use
/// these instead of `context.go('/...')` literals so the journey graph has
/// exactly one authority: the pure policy, enforced by the router redirect
/// backstop.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/data/app_review_flow_providers.dart';
import 'journey_policy.dart';
import 'journey_providers.dart';

/// SUCCESS-FORWARD: call after this screen's journey step has completed.
///
/// Reads the *current* snapshot and goes wherever the policy says is next —
/// the screen never knows (or guesses) the destination. Callers must let
/// their state mutation land in its notifier (await it) BEFORE calling
/// this, so the snapshot reflects the completed step. Owns the `mounted`
/// guard every call site used to hand-roll.
void continueJourney(WidgetRef ref, BuildContext context) {
  if (!context.mounted) {
    return;
  }
  context.go(JourneyPolicy.nextLocation(ref.read(journeySnapshotProvider)));
}

/// BACK-EXIT: leave the current journey step toward its static parent
/// (sign-in/sign-up -> intro, add-profile -> picker; unknown -> AuthGate).
void backOutOfJourneyStep(BuildContext context) {
  context.go(
    JourneyPolicy.backTarget(GoRouterState.of(context).matchedLocation),
  );
}

/// START-OVER: abandon the App Review flow entirely. Owns the
/// clearReviewFlow side effect, its sequencing before navigation, and the
/// `mounted` guard (previously copy-pasted as `_startOver` in two screens).
Future<void> restartJourney(WidgetRef ref, BuildContext context) async {
  await ref.read(appReviewFlowNotifierProvider).clearReviewFlow();
  if (!context.mounted) {
    return;
  }
  context.go(JourneyPolicy.restartTarget);
}

/// The two auth entry modes a signed-out user can switch between.
enum AuthEntry { signIn, signUp }

/// LATERAL SWITCH: peer navigation between auth entry screens.
void enterAuth(BuildContext context, AuthEntry mode) {
  context.go(
    mode == AuthEntry.signIn ? JourneyRoutes.signIn : JourneyRoutes.signUp,
  );
}

/// DETOUR: push the add-profile sub-flow onto the navigation stack.
void pushAddProfile(BuildContext context) {
  context.push(JourneyRoutes.addProfile);
}
