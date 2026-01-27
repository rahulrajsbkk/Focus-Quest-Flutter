import 'package:flutter/foundation.dart';

enum UserActivityType {
  questCompleted,
  subQuestCompleted,
  focusSessionCompleted,
  manualAdjustment,
  legacyImport,
}

@immutable
class UserActivityEvent {
  const UserActivityEvent({
    required this.id,
    required this.userId,
    required this.type,
    required this.xpEarned,
    required this.occurredAt,
    this.metadata = const {},
  });

  factory UserActivityEvent.fromJson(Map<String, dynamic> json) {
    return UserActivityEvent(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: UserActivityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => UserActivityType.manualAdjustment,
      ),
      xpEarned: json['xpEarned'] as int,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  final String id;
  final String userId;
  final UserActivityType type;
  final int xpEarned;
  final DateTime occurredAt;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'xpEarned': xpEarned,
      'occurredAt': occurredAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserActivityEvent &&
        other.id == id &&
        other.userId == userId &&
        other.type == type &&
        other.xpEarned == xpEarned &&
        other.occurredAt == occurredAt &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      type,
      xpEarned,
      occurredAt,
      mapEquals(metadata, metadata),
    );
  }
}
