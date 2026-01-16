import 'package:flutter/foundation.dart';

/// Status of a sub-quest.
enum SubQuestStatus {
  /// Sub-quest is waiting to be started.
  pending,

  /// Sub-quest is currently being worked on.
  inProgress,

  /// Sub-quest has been completed successfully.
  completed,

  /// Sub-quest was skipped.
  skipped,
}

/// Maximum allowed duration for a sub-quest in minutes.
///
/// ADHD-friendly constraint to keep tasks manageable.
const int maxSubQuestDurationMinutes = 5;

/// Exception thrown when a sub-quest duration exceeds the maximum allowed.
class InvalidSubQuestDurationException implements Exception {
  /// Creates an InvalidSubQuestDurationException.
  const InvalidSubQuestDurationException(this.duration);

  /// The invalid duration that was attempted.
  final Duration duration;

  @override
  String toString() {
    return 'InvalidSubQuestDurationException: Duration of '
        '${duration.inMinutes} minutes exceeds maximum of '
        '$maxSubQuestDurationMinutes minutes.';
  }
}

/// A SubQuest is a small, time-boxed task within a parent Quest.
///
/// SubQuests are designed to be completed in 5 minutes or less,
/// making them ideal for ADHD-friendly task management.
@immutable
class SubQuest {
  /// Creates a new SubQuest instance.
  ///
  /// Throws [InvalidSubQuestDurationException] if [estimatedDuration]
  /// exceeds [maxSubQuestDurationMinutes].
  factory SubQuest({
    required String id,
    required String questId,
    required String title,
    required Duration estimatedDuration,
    required DateTime createdAt,
    String? description,
    SubQuestStatus status = SubQuestStatus.pending,
    DateTime? completedAt,
    int order = 0,
  }) {
    // Validate duration constraint
    if (estimatedDuration.inMinutes > maxSubQuestDurationMinutes) {
      throw InvalidSubQuestDurationException(estimatedDuration);
    }

    return SubQuest._internal(
      id: id,
      questId: questId,
      title: title,
      description: description,
      status: status,
      estimatedDuration: estimatedDuration,
      createdAt: createdAt,
      completedAt: completedAt,
      order: order,
    );
  }

  /// Internal constructor that bypasses validation.
  /// Used by copyWith and fromJson after validation.
  const SubQuest._internal({
    required this.id,
    required this.questId,
    required this.title,
    required this.status,
    required this.estimatedDuration,
    required this.createdAt,
    required this.order,
    this.description,
    this.completedAt,
  });

  /// Creates a SubQuest from a JSON map.
  ///
  /// Throws [InvalidSubQuestDurationException] if the stored duration
  /// exceeds [maxSubQuestDurationMinutes].
  factory SubQuest.fromJson(Map<String, dynamic> json) {
    final duration = Duration(seconds: json['estimatedDurationSeconds'] as int);

    // Validate duration on deserialization
    if (duration.inMinutes > maxSubQuestDurationMinutes) {
      throw InvalidSubQuestDurationException(duration);
    }

    return SubQuest._internal(
      id: json['id'] as String,
      questId: json['questId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: SubQuestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SubQuestStatus.pending,
      ),
      estimatedDuration: duration,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      order: json['order'] as int? ?? 0,
    );
  }

  /// Unique identifier for the sub-quest.
  final String id;

  /// ID of the parent quest this sub-quest belongs to.
  final String questId;

  /// Title of the sub-quest.
  final String title;

  /// Optional detailed description.
  final String? description;

  /// Current status of the sub-quest.
  final SubQuestStatus status;

  /// Estimated duration to complete (max 5 minutes).
  final Duration estimatedDuration;

  /// When the sub-quest was created.
  final DateTime createdAt;

  /// When the sub-quest was completed (if completed).
  final DateTime? completedAt;

  /// Order within the parent quest (for sorting).
  final int order;

  /// Converts the SubQuest to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questId': questId,
      'title': title,
      'description': description,
      'status': status.name,
      'estimatedDurationSeconds': estimatedDuration.inSeconds,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'order': order,
    };
  }

  /// Creates a copy of this sub-quest with the given fields replaced.
  ///
  /// Throws [InvalidSubQuestDurationException] if [estimatedDuration]
  /// exceeds [maxSubQuestDurationMinutes].
  SubQuest copyWith({
    String? id,
    String? questId,
    String? title,
    String? description,
    SubQuestStatus? status,
    Duration? estimatedDuration,
    DateTime? createdAt,
    DateTime? completedAt,
    int? order,
  }) {
    final newDuration = estimatedDuration ?? this.estimatedDuration;

    // Validate duration constraint
    if (newDuration.inMinutes > maxSubQuestDurationMinutes) {
      throw InvalidSubQuestDurationException(newDuration);
    }

    return SubQuest._internal(
      id: id ?? this.id,
      questId: questId ?? this.questId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      estimatedDuration: newDuration,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      order: order ?? this.order,
    );
  }

  /// Returns true if the sub-quest has been completed.
  bool get isCompleted => status == SubQuestStatus.completed;

  /// Returns true if the sub-quest is currently active.
  bool get isActive =>
      status == SubQuestStatus.pending || status == SubQuestStatus.inProgress;

  /// Returns the estimated duration in a human-readable format.
  String get formattedDuration {
    final minutes = estimatedDuration.inMinutes;
    final seconds = estimatedDuration.inSeconds % 60;

    if (minutes > 0 && seconds > 0) {
      return '${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubQuest &&
        other.id == id &&
        other.questId == questId &&
        other.title == title &&
        other.description == description &&
        other.status == status &&
        other.estimatedDuration == estimatedDuration &&
        other.createdAt == createdAt &&
        other.completedAt == completedAt &&
        other.order == order;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      questId,
      title,
      description,
      status,
      estimatedDuration,
      createdAt,
      completedAt,
      order,
    );
  }

  @override
  String toString() {
    return 'SubQuest(id: $id, questId: $questId, title: $title, '
        'status: $status, duration: $formattedDuration)';
  }
}
