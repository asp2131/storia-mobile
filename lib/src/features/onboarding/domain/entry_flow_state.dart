/// The account operation explicitly requested by a parent.
enum EntryAuthIntent { signIn, signUp }

/// The only supported return after explicitly claiming the bundled sample.
///
/// Route strings and arbitrary book IDs cannot become entry return targets.
enum SampleSaveDestination { sampleReader }

/// A read-only snapshot of the in-memory parent entry flow.
///
/// Gate authorization and the adult-year check are temporary product safeguards,
/// not verified parental consent. Neither the raw year nor persisted review
/// state is an authority for this flow.
final class EntryFlowState {
  const EntryFlowState({
    required this.isReady,
    this.pendingAuthIntent,
    this.isParentAuthorized = false,
    this.isAdultVerified = false,
    this.pendingSampleSave,
  });

  final bool isReady;
  final EntryAuthIntent? pendingAuthIntent;
  final bool isParentAuthorized;
  final bool isAdultVerified;
  final SampleSaveDestination? pendingSampleSave;

  bool get hasPendingSampleSave => pendingSampleSave != null;
}
