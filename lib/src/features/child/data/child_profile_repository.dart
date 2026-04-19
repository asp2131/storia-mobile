import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/api_client.dart';
import '../domain/child_profile.dart';

class ChildProfileRepository {
  const ChildProfileRepository(this._supabase, this._apiClient);

  final SupabaseClient _supabase;
  final ApiClient _apiClient;

  static const _activeChildKey = 'active_child_profile_id';

  Future<List<ChildProfile>> fetchChildProfiles() async {
    try {
      final apiData = await _apiClient.get('/api/child-profiles');
      final rows =
          (apiData as Map<String, dynamic>?)?['childProfiles']
              as List<dynamic>?;
      if (rows != null) {
        return rows
            .whereType<Map<String, dynamic>>()
            .map(ChildProfile.fromJson)
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint('[ChildProfileRepository] API fetchChildProfiles failed: $e');
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final data = await _supabase
          .from('child_profiles')
          .select()
          .eq('owner_user_id', userId)
          .order('created_at');

      final rows = (data as List<dynamic>).whereType<Map<String, dynamic>>();
      return rows.map(ChildProfile.fromJson).toList(growable: false);
    } catch (e) {
      debugPrint('[ChildProfileRepository] fetchChildProfiles failed: $e');
      return const [];
    }
  }

  Future<ChildProfile?> fetchDefaultChildProfile() async {
    final profiles = await fetchChildProfiles();
    return resolveActiveChild(profiles);
  }

  Future<ChildProfile> createChildProfile(CreateChildProfileInput input) async {
    final apiData = await _apiClient.post(
      '/api/child-profiles',
      body: input.toJson(),
    );
    final row =
        (apiData as Map<String, dynamic>?)?['childProfile']
            as Map<String, dynamic>?;
    if (row == null) {
      throw const FormatException('Missing childProfile in response');
    }

    return ChildProfile.fromJson(row);
  }

  Future<void> saveActiveChildId(String childProfileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeChildKey, childProfileId);
  }

  Future<String?> _getSavedActiveChildId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeChildKey);
  }

  Future<ChildProfile?> resolveActiveChild(List<ChildProfile> profiles) async {
    if (profiles.isEmpty) return null;

    // Prefer previously selected child.
    final savedId = await _getSavedActiveChildId();
    if (savedId != null) {
      final saved = profiles.where((p) => p.id == savedId).firstOrNull;
      if (saved != null) return saved;
    }

    // Fall back to the default-flagged profile, or the first one.
    return profiles.where((p) => p.isDefault).firstOrNull ?? profiles.first;
  }
}
