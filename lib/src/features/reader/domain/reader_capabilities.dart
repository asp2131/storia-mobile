/// Reserved identity of the bundled, account-free entry sample.
///
/// Regular catalog book IDs are numeric strings; this constant is the only
/// value that resolves to bundled content, and capabilities are selected at
/// trusted route boundaries by exact comparison — never inferred from
/// user-controlled arbitrary IDs.
const String sampleBookId = 'loratone-entry-sample';

/// Which kind of content a reader session is bound to.
enum ReaderAccess { sample, guest, catalog }

/// Explicit runtime permissions for a reader session, chosen at the trusted
/// route/source boundary, rather than inferred from a book ID.
///
/// Disallowed capabilities must not even initialize their services; hiding
/// UI controls alone is insufficient.
class ReaderCapabilities {
  const ReaderCapabilities({required this.access});

  final ReaderAccess access;

  bool get allowsNetworkContent => access != ReaderAccess.sample;
  bool get allowsSpeech => access == ReaderAccess.catalog;
  bool get allowsWordHelp => access == ReaderAccess.catalog;
  bool get allowsParentNarration => access == ReaderAccess.catalog;
  bool get allowsActivities => access == ReaderAccess.catalog;
  bool get allowsAnalytics => access == ReaderAccess.catalog;

  /// Account-free pages load silently until the reader explicitly starts audio.
  bool get autoplayPages => access == ReaderAccess.catalog;
}
