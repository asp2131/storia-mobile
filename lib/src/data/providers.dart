import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics_repository.dart';
import 'book_repository.dart';
import 'models.dart';
import 'pronunciation_models.dart';
import 'pronunciation_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final apiBaseUrlProvider = Provider<String>((ref) {
  return dotenv.env['API_BASE_URL'] ?? 'https://storia.kids';
});

/// Current child profile used by backend analytics routes.
///
/// Defaults to null for tests and non-app containers. `main.dart` overrides this
/// with the shared-preferences backed active child profile selection.
final currentChildProfileIdProvider = Provider<String?>((ref) => null);

final analyticsHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final analyticsTransportProvider = Provider<AnalyticsTransport>((ref) {
  return HttpAnalyticsTransport(
    client: ref.watch(analyticsHttpClientProvider),
    apiBaseUrl: ref.watch(apiBaseUrlProvider),
  );
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AnalyticsRepository(
    transport: ref.watch(analyticsTransportProvider),
    currentUserId: () => supabase.auth.currentSession?.user.id,
    currentAccessToken: () => supabase.auth.currentSession?.accessToken,
    currentChildProfileId: () => ref.read(currentChildProfileIdProvider),
  );
});

/// Fires funnel events the backend cannot infer from reader activity:
/// `app_opened` once per launch with a restored session, and
/// `signup_completed` / `signin_completed` on each sign-in. Watched from the
/// app root so it lives for the whole process.
final authAnalyticsListenerProvider = Provider<void>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final analytics = ref.watch(analyticsRepositoryProvider);

  if (supabase.auth.currentSession != null) {
    unawaited(analytics.track(AnalyticsEventType.appOpened));
  }

  final subscription = supabase.auth.onAuthStateChange.listen((data) {
    if (data.event != AuthChangeEvent.signedIn) return;
    final user = data.session?.user;
    if (user == null) return;
    // ponytail: "new user" = account created within the last two minutes.
    // Good enough to split sign-ups from returning sign-ins without a flag.
    final createdAt = DateTime.tryParse(user.createdAt);
    final isNew =
        createdAt != null &&
        DateTime.now().toUtc().difference(createdAt.toUtc()) <
            const Duration(minutes: 2);
    unawaited(
      analytics.track(
        isNew
            ? AnalyticsEventType.signupCompleted
            : AnalyticsEventType.signinCompleted,
        metadata: {'provider': user.appMetadata['provider']?.toString()},
      ),
    );
  });
  ref.onDispose(subscription.cancel);
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return BookRepository(supabase);
});

final bookLibraryProvider = FutureProvider<List<Book>>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getPublishedBooks();
});
final currentBookProvider = FutureProvider.family<Book?, String>((
  ref,
  bookId,
) async {
  if (bookId.isEmpty) {
    return null;
  }
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getBookById(bookId);
});

final pronunciationRepositoryProvider = Provider<PronunciationRepository>((
  ref,
) {
  final supabase = ref.watch(supabaseClientProvider);
  return PronunciationRepository(supabase);
});

final bookManifestProvider =
    FutureProvider.family<BookPronunciationManifest?, String>((
      ref,
      bookId,
    ) async {
      if (bookId.isEmpty) {
        return null;
      }
      final repo = ref.watch(pronunciationRepositoryProvider);
      return repo.getManifestForBook(bookId);
    });
