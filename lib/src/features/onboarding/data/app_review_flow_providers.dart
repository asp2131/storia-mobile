import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/review_onboarding_profile.dart';

const appReviewBypassEmail = 'app-review@storia.kids';

@immutable
class AppReviewFlowState {
  const AppReviewFlowState({
    required this.isReady,
    required this.hasReviewBypass,
    required this.parentBirthYear,
    required this.onboardingProfile,
  });

  final bool isReady;
  final bool hasReviewBypass;
  final int? parentBirthYear;
  final ReviewOnboardingProfile? onboardingProfile;

  bool get hasParentBirthYear => parentBirthYear != null;
  bool get hasCompletedOnboarding => onboardingProfile != null;
}

final appReviewFlowNotifierProvider =
    ChangeNotifierProvider<AppReviewFlowNotifier>((ref) {
      final notifier = AppReviewFlowNotifier();
      ref.onDispose(notifier.dispose);
      return notifier;
    });

final appReviewFlowProvider = Provider<AppReviewFlowState>((ref) {
  final notifier = ref.watch(appReviewFlowNotifierProvider);
  return notifier.state;
});

class AppReviewFlowNotifier extends ChangeNotifier {
  AppReviewFlowNotifier() {
    _load();
  }

  static const _reviewBypassEmailKey = 'app_review_bypass_email';
  static const _reviewParentBirthYearKey = 'app_review_parent_birth_year';
  static const _reviewOnboardingProfileKey = 'app_review_onboarding_profile';

  SharedPreferences? _preferences;
  AppReviewFlowState _state = const AppReviewFlowState(
    isReady: false,
    hasReviewBypass: false,
    parentBirthYear: null,
    onboardingProfile: null,
  );

  AppReviewFlowState get state => _state;

  Future<void> _load() async {
    final preferences = await _prefs;
    _state = AppReviewFlowState(
      isReady: true,
      hasReviewBypass:
          (preferences.getString(_reviewBypassEmailKey) ?? '').isNotEmpty,
      parentBirthYear: preferences.getInt(_reviewParentBirthYearKey),
      onboardingProfile: ReviewOnboardingProfile.tryParse(
        preferences.getString(_reviewOnboardingProfileKey),
      ),
    );
    notifyListeners();
  }

  Future<void> enableReviewBypass({required String email}) async {
    final preferences = await _prefs;
    await preferences.setString(_reviewBypassEmailKey, email.toLowerCase());
    await preferences.remove(_reviewParentBirthYearKey);
    await preferences.remove(_reviewOnboardingProfileKey);

    _state = const AppReviewFlowState(
      isReady: true,
      hasReviewBypass: true,
      parentBirthYear: null,
      onboardingProfile: null,
    );
    notifyListeners();
  }

  Future<void> saveParentBirthYear(int birthYear) async {
    final preferences = await _prefs;
    await preferences.setInt(_reviewParentBirthYearKey, birthYear);

    _state = AppReviewFlowState(
      isReady: true,
      hasReviewBypass: _state.hasReviewBypass,
      parentBirthYear: birthYear,
      onboardingProfile: _state.onboardingProfile,
    );
    notifyListeners();
  }

  Future<void> completeOnboarding(ReviewOnboardingProfile profile) async {
    final preferences = await _prefs;
    await preferences.setString(_reviewOnboardingProfileKey, profile.toJson());

    _state = AppReviewFlowState(
      isReady: true,
      hasReviewBypass: _state.hasReviewBypass,
      parentBirthYear: _state.parentBirthYear,
      onboardingProfile: profile,
    );
    notifyListeners();
  }

  Future<void> clearReviewFlow() async {
    final preferences = await _prefs;
    await preferences.remove(_reviewBypassEmailKey);
    await preferences.remove(_reviewParentBirthYearKey);
    await preferences.remove(_reviewOnboardingProfileKey);

    _state = const AppReviewFlowState(
      isReady: true,
      hasReviewBypass: false,
      parentBirthYear: null,
      onboardingProfile: null,
    );
    notifyListeners();
  }

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }
}
