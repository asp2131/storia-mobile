import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/child_profile.dart';

class ChildProfileRepository {
  const ChildProfileRepository(this._supabase);

  final SupabaseClient _supabase;

  static const _activeChildKey = 'active_child_profile_id';

  Future<List<ChildProfile>> fetchChildProfiles() async {
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

  Future<void> saveActiveChildId(String childProfileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeChildKey, childProfileId);
  }

  Future<String?> _getSavedActiveChildId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeChildKey);
  }
}
