import 'package:flutter/foundation.dart';

@immutable
class CreateChildProfileInput {
  const CreateChildProfileInput({
    required this.displayName,
    required this.ageBand,
    this.readingLevel,
    required this.isDefault,
  });

  final String displayName;
  final String ageBand;
  final String? readingLevel;
  final bool isDefault;

  Map<String, dynamic> toJson() {
    final normalizedReadingLevel = readingLevel?.trim();
    return {
      'displayName': displayName.trim(),
      'ageBand': ageBand.trim(),
      'readingLevel':
          normalizedReadingLevel == null || normalizedReadingLevel.isEmpty
          ? null
          : normalizedReadingLevel,
      'isDefault': isDefault,
    };
  }
}

@immutable
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.displayName,
    required this.ageBand,
    required this.isDefault,
    this.userId,
    this.readingLevel,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? userId;
  final String displayName;
  final String ageBand;
  final String? readingLevel;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    final id = _readRequiredString(json, 'id');
    final displayName = _readRequiredString(json, 'displayName');
    final ageBand = _readRequiredString(json, 'ageBand');

    return ChildProfile(
      id: id,
      userId: _readString(json, 'userId'),
      displayName: displayName,
      ageBand: ageBand,
      readingLevel: _readString(json, 'readingLevel'),
      isDefault: json['isDefault'] == true,
      createdAt: _readDateTime(json, 'createdAt'),
      updatedAt: _readDateTime(json, 'updatedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userId != null) 'userId': userId,
    'displayName': displayName,
    'ageBand': ageBand,
    if (readingLevel != null) 'readingLevel': readingLevel,
    'isDefault': isDefault,
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    return parts
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
  }

  static String? _readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final value = _readString(json, key);
    if (value == null) {
      throw FormatException('Missing child profile field: $key');
    }
    return value;
  }

  static DateTime? _readDateTime(Map<String, dynamic> json, String key) {
    final raw = _readString(json, key);
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}
