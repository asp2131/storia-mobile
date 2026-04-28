import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/providers.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/child_profile.dart';
import 'child_profile_repository.dart';

final childProfileHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final childProfileRepositoryProvider = Provider<ChildProfileRepository>((ref) {
  return ChildProfileRepository(
    client: ref.watch(childProfileHttpClientProvider),
    apiBaseUrl: ref.watch(apiBaseUrlProvider),
    supabase: ref.watch(supabaseClientProvider),
  );
});

final childProfileActionsProvider = Provider<ChildProfileActions>((ref) {
  return ChildProfileActions(ref);
});

final childProfilesProvider = FutureProvider<List<ChildProfile>>((ref) async {
  final authState = ref.watch(authViewStateProvider);
  if (!authState.isAuthenticated) {
    return const <ChildProfile>[];
  }

  final profiles = await ref
      .watch(childProfileRepositoryProvider)
      .getChildProfiles();
  final activeId = ref.read(activeChildProfileIdProvider);
  if (activeId != null && !profiles.any((profile) => profile.id == activeId)) {
    unawaited(
      ref
          .read(activeChildProfileIdStateProvider.notifier)
          .setActiveChildProfileId(null),
    );
  }
  return profiles;
});

final activeChildProfileIdStateProvider =
    StateNotifierProvider<ActiveChildProfileIdNotifier, AsyncValue<String?>>((
      ref,
    ) {
      final authState = ref.watch(authViewStateProvider);
      final userId = authState.session?.user.id;
      final notifier = ActiveChildProfileIdNotifier(userId: userId);
      unawaited(notifier.load());
      return notifier;
    });

final activeChildProfileIdProvider = Provider<String?>((ref) {
  return ref.watch(activeChildProfileIdStateProvider).valueOrNull;
});

final activeChildProfileProvider = Provider<AsyncValue<ChildProfile?>>((ref) {
  final activeId = ref.watch(activeChildProfileIdProvider);
  final profiles = ref.watch(childProfilesProvider);

  return profiles.whenData((profiles) {
    if (activeId == null || activeId.trim().isEmpty) {
      return null;
    }
    for (final profile in profiles) {
      if (profile.id == activeId) {
        return profile;
      }
    }
    return null;
  });
});

final childProfileRouterRefreshProvider =
    ChangeNotifierProvider<ChildProfileRouterRefreshNotifier>((ref) {
      final notifier = ChildProfileRouterRefreshNotifier();
      ref.listen<AsyncValue<String?>>(
        activeChildProfileIdStateProvider,
        (_, _) => notifier.refresh(),
      );
      ref.listen<AsyncValue<List<ChildProfile>>>(
        childProfilesProvider,
        (_, _) => notifier.refresh(),
      );
      ref.onDispose(notifier.dispose);
      return notifier;
    });

class ChildProfileActions {
  ChildProfileActions(this._ref);

  final Ref _ref;

  Future<ChildProfile> createAndSelect(CreateChildProfileInput input) async {
    final created = await _ref
        .read(childProfileRepositoryProvider)
        .createChildProfile(input);
    await _ref
        .read(activeChildProfileIdStateProvider.notifier)
        .setActiveChildProfileId(created.id);
    _ref.invalidate(childProfilesProvider);
    return created;
  }
}

class ActiveChildProfileIdNotifier extends StateNotifier<AsyncValue<String?>> {
  ActiveChildProfileIdNotifier({required String? userId})
    : _userId = userId,
      super(const AsyncValue.loading());

  final String? _userId;

  static const _legacyPreferenceKey = 'activeChildProfileId';
  static const _preferencePrefix = 'activeChildProfileId.';

  String? get userId => _userId;

  Future<void> load() async {
    if (_userId == null || _userId.trim().isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) {
        return;
      }
      final value = prefs.getString(_preferenceKey(_userId));
      state = AsyncValue.data(_blankToNull(value));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> setActiveChildProfileId(String? childProfileId) async {
    if (_userId == null || _userId.trim().isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }

    final normalized = _blankToNull(childProfileId);
    state = AsyncValue.data(normalized);

    final prefs = await SharedPreferences.getInstance();
    final key = _preferenceKey(_userId);
    if (normalized == null) {
      await prefs.remove(key);
      await prefs.remove(_legacyPreferenceKey);
    } else {
      await prefs.setString(key, normalized);
    }
  }

  static String _preferenceKey(String? userId) {
    final normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return _legacyPreferenceKey;
    }
    return '$_preferencePrefix$normalized';
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class ChildProfileRouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
