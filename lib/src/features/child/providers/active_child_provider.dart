import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../data/child_profile_repository.dart';
import '../domain/child_profile.dart';

final childProfileRepositoryProvider = Provider<ChildProfileRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final apiClient = ref.watch(apiClientProvider);
  return ChildProfileRepository(supabase, apiClient);
});

final childProfilesProvider = FutureProvider<List<ChildProfile>>((ref) async {
  final repo = ref.watch(childProfileRepositoryProvider);
  return repo.fetchChildProfiles();
});

final activeChildProvider =
    AsyncNotifierProvider<ActiveChildNotifier, ChildProfile?>(
      ActiveChildNotifier.new,
    );

final activeChildIdProvider = Provider<String?>((ref) {
  return ref.watch(activeChildProvider).valueOrNull?.id;
});

class ActiveChildNotifier extends AsyncNotifier<ChildProfile?> {
  ChildProfileRepository get _repo => ref.read(childProfileRepositoryProvider);

  @override
  Future<ChildProfile?> build() async {
    return _repo.fetchDefaultChildProfile();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.fetchDefaultChildProfile);
  }

  Future<void> selectChild(String childProfileId) async {
    final profiles = await _repo.fetchChildProfiles();
    final selected = profiles.where((p) => p.id == childProfileId).firstOrNull;
    if (selected == null) {
      throw StateError('Unknown child profile: $childProfileId');
    }

    await _repo.saveActiveChildId(childProfileId);
    state = AsyncData(selected);
  }
}
