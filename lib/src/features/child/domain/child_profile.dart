import 'package:flutter/foundation.dart';

@immutable
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.displayName,
    required this.ageBand,
    this.readingLevel,
    required this.isDefault,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String displayName;
  final String ageBand;
  final String? readingLevel;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ??
          json['display_name'] as String? ??
          '',
      ageBand: json['ageBand'] as String? ??
          json['age_band'] as String? ??
          '',
      readingLevel: json['readingLevel'] as String? ??
          json['reading_level'] as String?,
      isDefault: json['isDefault'] as bool? ??
          json['is_default'] as bool? ??
          false,
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'ageBand': ageBand,
      'readingLevel': readingLevel,
      'isDefault': isDefault,
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}
