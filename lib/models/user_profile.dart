/// lib/models/user_profile.dart
import 'package:flutter/material.dart';

class UserProfile {
  final String id;
  final String name;
  final String avatarId; // ID or path to avatar asset
  final int colorValue; // Colors.blue.value
  final List<String>? allowedFolderIds; // Null = all access
  final String? pin; // 4-digit PIN, null if not set

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarId,
    required this.colorValue,
    this.allowedFolderIds,
    this.pin,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarId': avatarId,
        'colorValue': colorValue,
        'allowedFolderIds': allowedFolderIds,
        'pin': pin,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarId: json['avatarId'] as String? ?? 'default',
        colorValue: json['colorValue'] as int? ?? 0xFF2196F3,
        allowedFolderIds: (json['allowedFolderIds'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        pin: json['pin'] as String?,
      );

  UserProfile copyWith({
    String? name,
    String? avatarId,
    int? colorValue,
    List<String>? allowedFolderIds,
    String? pin,
    bool clearPin = false,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      colorValue: colorValue ?? this.colorValue,
      allowedFolderIds: allowedFolderIds ?? this.allowedFolderIds,
      pin: clearPin ? null : (pin ?? this.pin),
    );
  }
}

class UserMediaData {
  final String mediaId;
  final int positionSeconds;
  final bool isWatched;
  final DateTime lastUpdated;

  const UserMediaData({
    required this.mediaId,
    this.positionSeconds = 0,
    this.isWatched = false,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'positionSeconds': positionSeconds,
        'isWatched': isWatched,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory UserMediaData.fromJson(Map<String, dynamic> json) => UserMediaData(
        mediaId: json['mediaId'] as String,
        positionSeconds: json['positionSeconds'] as int? ?? 0,
        isWatched: json['isWatched'] as bool? ?? false,
        lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? '') ??
            DateTime.now(),
      );

  UserMediaData copyWith({
    int? positionSeconds,
    bool? isWatched,
    DateTime? lastUpdated,
  }) {
    return UserMediaData(
      mediaId: mediaId,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      isWatched: isWatched ?? this.isWatched,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
