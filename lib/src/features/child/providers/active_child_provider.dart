import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../data/child_profile_repository.dart';
import '../domain/child_profile.dart';

final childProfileRepositoryProvider = Provider<ChildProfileRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ChildProfileRepository(supabase);
});

final activeChildProvider = FutureProvider<ChildProfile?>((ref) async {
  final repo = ref.watch(childProfileRepositoryProvider);
  return repo.fetchDefaultChildProfile();
});
