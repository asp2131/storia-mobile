import '../../routing/journey/journey_policy.dart';

/// Always share the stable custom domain, including from preview deployments.
abstract final class BookLinks {
  static bool isValidId(String bookId) => RegExp(r'^[0-9]+$').hasMatch(bookId);

  static Uri forBook(String bookId) {
    if (!isValidId(bookId)) {
      throw ArgumentError.value(bookId, 'bookId', 'Expected a catalog book ID');
    }
    return Uri.parse(
      'https://app.loratone.com',
    ).resolve(JourneyRoutes.sharedBook(bookId));
  }
}
