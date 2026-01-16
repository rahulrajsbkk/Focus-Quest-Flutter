import 'package:flutter/foundation.dart';

/// Status of a focus session.
enum FocusSessionStatus {
  /// Session is currently active and running.
  active,

  /// Session was paused by the user.
  paused,

  /// Session was completed successfully.
  completed,

  /// Session was interrupted or abandoned.
  interrupted,
}

/// Type of focus session.
enum FocusSessionType {
  /// Standard pomodoro-style focus session.
  focus,

  /// Short break between focus sessions.
  shortBreak,

  /// Longer break after multiple focus sessions.
  longBreak,
}

/// A FocusSession represents a timed focus period.
///
/// Sessions can be associated with a specific quest/sub-quest and track
/// the actual time spent focusing. They support pause/resume for ADHD-friendly
/// flexibility.
@immutable
class FocusSession {
  /// Creates a new FocusSession instance.
  const FocusSession({
    required this.id,
    required this.type,
    required this.status,
    required this.plannedDuration,
    required this.startedAt,
    this.questId,
    this.subQuestId,
    this.pausedAt,
    this.resumedAt,
    this.completedAt,
    this.totalPausedDuration = Duration.zero,
    this.notes,
  });

  /// Creates a FocusSession from a JSON map.
  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: json['id'] as String,
      questId: json['questId'] as String?,
      subQuestId: json['subQuestId'] as String?,
      type: FocusSessionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => FocusSessionType.focus,
      ),
      status: FocusSessionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => FocusSessionStatus.active,
      ),
      plannedDuration: Duration(seconds: json['plannedDurationSeconds'] as int),
      startedAt: DateTime.parse(json['startedAt'] as String),
      pausedAt: json['pausedAt'] != null
          ? DateTime.parse(json['pausedAt'] as String)
          : null,
      resumedAt: json['resumedAt'] != null
          ? DateTime.parse(json['resumedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      totalPausedDuration: Duration(
        seconds: json['totalPausedDurationSeconds'] as int? ?? 0,
      ),
      notes: json['notes'] as String?,
    );
  }

  /// Creates a new active focus session.
  factory FocusSession.start({
    required String id,
    required Duration plannedDuration,
    String? questId,
    String? subQuestId,
    FocusSessionType type = FocusSessionType.focus,
    DateTime? startedAt,
  }) {
    return FocusSession(
      id: id,
      questId: questId,
      subQuestId: subQuestId,
      type: type,
      status: FocusSessionStatus.active,
      plannedDuration: plannedDuration,
      startedAt: startedAt ?? DateTime.now(),
    );
  }

  /// Unique identifier for the session.
  final String id;

  /// ID of the associated quest (optional).
  final String? questId;

  /// ID of the associated sub-quest (optional).
  final String? subQuestId;

  /// Type of focus session.
  final FocusSessionType type;

  /// Current status of the session.
  final FocusSessionStatus status;

  /// The planned duration of the session.
  final Duration plannedDuration;

  /// When the session was started.
  final DateTime startedAt;

  /// When the session was paused (if paused).
  final DateTime? pausedAt;

  /// When the session was last resumed (if paused and resumed).
  final DateTime? resumedAt;

  /// When the session was completed or interrupted.
  final DateTime? completedAt;

  /// Total time spent paused during this session.
  final Duration totalPausedDuration;

  /// Optional notes about the session.
  final String? notes;

  /// Converts the FocusSession to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questId': questId,
      'subQuestId': subQuestId,
      'type': type.name,
      'status': status.name,
      'plannedDurationSeconds': plannedDuration.inSeconds,
      'startedAt': startedAt.toIso8601String(),
      'pausedAt': pausedAt?.toIso8601String(),
      'resumedAt': resumedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'totalPausedDurationSeconds': totalPausedDuration.inSeconds,
      'notes': notes,
    };
  }

  /// Creates a copy of this session with the given fields replaced.
  ///
  /// Use [clearPausedAt] to explicitly set pausedAt to null.
  FocusSession copyWith({
    String? id,
    String? questId,
    String? subQuestId,
    FocusSessionType? type,
    FocusSessionStatus? status,
    Duration? plannedDuration,
    DateTime? startedAt,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    DateTime? resumedAt,
    DateTime? completedAt,
    Duration? totalPausedDuration,
    String? notes,
  }) {
    return FocusSession(
      id: id ?? this.id,
      questId: questId ?? this.questId,
      subQuestId: subQuestId ?? this.subQuestId,
      type: type ?? this.type,
      status: status ?? this.status,
      plannedDuration: plannedDuration ?? this.plannedDuration,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      resumedAt: resumedAt ?? this.resumedAt,
      completedAt: completedAt ?? this.completedAt,
      totalPausedDuration: totalPausedDuration ?? this.totalPausedDuration,
      notes: notes ?? this.notes,
    );
  }

  /// Pauses the session.
  FocusSession pause({DateTime? at}) {
    if (status != FocusSessionStatus.active) {
      return this;
    }

    return copyWith(
      status: FocusSessionStatus.paused,
      pausedAt: at ?? DateTime.now(),
    );
  }

  /// Resumes a paused session.
  FocusSession resume({DateTime? at}) {
    if (status != FocusSessionStatus.paused || pausedAt == null) {
      return this;
    }

    final now = at ?? DateTime.now();
    final pauseDuration = now.difference(pausedAt!);

    return copyWith(
      status: FocusSessionStatus.active,
      resumedAt: now,
      clearPausedAt: true,
      totalPausedDuration: totalPausedDuration + pauseDuration,
    );
  }

  /// Completes the session.
  FocusSession complete({DateTime? at, String? notes}) {
    return copyWith(
      status: FocusSessionStatus.completed,
      completedAt: at ?? DateTime.now(),
      notes: notes ?? this.notes,
    );
  }

  /// Marks the session as interrupted.
  FocusSession interrupt({DateTime? at, String? notes}) {
    return copyWith(
      status: FocusSessionStatus.interrupted,
      completedAt: at ?? DateTime.now(),
      notes: notes ?? this.notes,
    );
  }

  /// Returns true if the session is currently active.
  bool get isActive => status == FocusSessionStatus.active;

  /// Returns true if the session is paused.
  bool get isPaused => status == FocusSessionStatus.paused;

  /// Returns true if the session has ended (completed or interrupted).
  bool get hasEnded =>
      status == FocusSessionStatus.completed ||
      status == FocusSessionStatus.interrupted;

  /// Calculates the actual elapsed time (excluding pauses).
  Duration get elapsedDuration {
    final endTime = completedAt ?? DateTime.now();
    final totalDuration = endTime.difference(startedAt);

    // Account for current pause if session is paused
    var currentPauseDuration = Duration.zero;
    if (status == FocusSessionStatus.paused && pausedAt != null) {
      currentPauseDuration = DateTime.now().difference(pausedAt!);
    }

    return totalDuration - totalPausedDuration - currentPauseDuration;
  }

  /// Returns the remaining time in the session.
  Duration get remainingDuration {
    final remaining = plannedDuration - elapsedDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Returns progress as a value between 0.0 and 1.0.
  double get progress {
    if (plannedDuration.inSeconds == 0) return 0;
    final elapsed = elapsedDuration.inSeconds;
    final planned = plannedDuration.inSeconds;
    return (elapsed / planned).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusSession &&
        other.id == id &&
        other.questId == questId &&
        other.subQuestId == subQuestId &&
        other.type == type &&
        other.status == status &&
        other.plannedDuration == plannedDuration &&
        other.startedAt == startedAt &&
        other.pausedAt == pausedAt &&
        other.resumedAt == resumedAt &&
        other.completedAt == completedAt &&
        other.totalPausedDuration == totalPausedDuration &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      questId,
      subQuestId,
      type,
      status,
      plannedDuration,
      startedAt,
      pausedAt,
      resumedAt,
      completedAt,
      totalPausedDuration,
      notes,
    );
  }

  @override
  String toString() {
    return 'FocusSession(id: $id, type: $type, status: $status, '
        'progress: ${(progress * 100).toStringAsFixed(1)}%)';
  }
}
