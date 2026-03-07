import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_client.dart';
import '../auth/auth_providers.dart';

final displayNameProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.name;
});

final userEmailProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.email;
});

final userImageProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.image;
});

class ProfileRepository {
  final BetterAuthClient _client;

  ProfileRepository(this._client);

  Future<void> updateDisplayName(String name) async {
    await _client.updateUser(name: name);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(betterAuthClientProvider);
  return ProfileRepository(client);
});
