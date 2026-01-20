import 'package:flutter/foundation.dart';

/// XP required for each level.
///
/// Uses a simple formula: level N requires N * 100 XP from level N-1.
/// Total XP for level N = sum(1..N) * 100 = N*(N+1)/2 * 100
int xpRequiredForLevel(int level) {
  if (level <= 1) return 0;
  return level * 100;
}

/// Calculates the total XP required to reach a given level.
int totalXpForLevel(int level) {
  if (level <= 1) return 0;
  // Sum from 2 to level of (i * 100)
  // = 100 * sum(2..level) = 100 * (level*(level+1)/2 - 1)
  return 100 * (level * (level + 1) ~/ 2 - 1);
}

/// Calculates the level from total XP.
int levelFromTotalXp(int totalXp) {
  if (totalXp <= 0) return 1;

  // Solve: 100 * (level*(level+1)/2 - 1) <= totalXp
  // level*(level+1)/2 <= totalXp/100 + 1
  // Using quadratic formula approximation
  var level = 1;
  while (totalXpForLevel(level + 1) <= totalXp) {
    level++;
  }
  return level;
}

/// Achievement types that can be earned.
enum AchievementType {
  /// Completed first quest.
  firstQuest,

  /// Completed 10 quests.
  questMaster,

  /// Completed 100 quests.
  questLegend,

  /// First focus session completed.
  firstFocus,

  /// 1 hour total focus time.
  focusHour,

  /// 10 hours total focus time.
  focusMarathon,

  /// 7 day streak.
  weekStreak,

  /// 30 day streak.
  monthStreak,

  /// Reached level 5.
  levelFive,

  /// Reached level 10.
  levelTen,

  /// Reached level 25.
  levelTwentyFive,
}

/// An achievement earned by the user.
@immutable
class Achievement {
  /// Creates a new Achievement.
  const Achievement({
    required this.type,
    required this.unlockedAt,
  });

  /// Creates an Achievement from JSON.
  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      type: AchievementType.values.firstWhere(
        (t) => t.name == json['type'],
      ),
      unlockedAt: DateTime.parse(json['unlockedAt'] as String),
    );
  }

  /// The type of achievement.
  final AchievementType type;

  /// When the achievement was unlocked.
  final DateTime unlockedAt;

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'unlockedAt': unlockedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Achievement &&
        other.type == type &&
        other.unlockedAt == unlockedAt;
  }

  @override
  int get hashCode => Object.hash(type, unlockedAt);
}

/// User progress tracking model.
///
/// Tracks XP, level, streaks, and achievements for gamification.
@immutable
class UserProgress {
  /// Creates a new UserProgress instance.
  const UserProgress({
    required this.id,
    required this.createdAt,
    this.totalXp = 0,
    this.questsCompleted = 0,
    this.subQuestsCompleted = 0,
    this.focusSessionsCompleted = 0,
    this.totalFocusTime = Duration.zero,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.achievements = const [],
    this.updatedAt,
  });

  /// Creates a new UserProgress with default values.
  factory UserProgress.initial({required String id}) {
    return UserProgress(
      id: id,
      createdAt: DateTime.now(),
    );
  }

  /// Creates a UserProgress from JSON.
  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      id: json['id'] as String,
      totalXp: json['totalXp'] as int? ?? 0,
      questsCompleted: json['questsCompleted'] as int? ?? 0,
      subQuestsCompleted: json['subQuestsCompleted'] as int? ?? 0,
      focusSessionsCompleted: json['focusSessionsCompleted'] as int? ?? 0,
      totalFocusTime: Duration(
        seconds: json['totalFocusTimeSeconds'] as int? ?? 0,
      ),
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastActiveDate: json['lastActiveDate'] != null
          ? DateTime.parse(json['lastActiveDate'] as String)
          : null,
      achievements:
          (json['achievements'] as List<dynamic>?)
              ?.map((a) => Achievement.fromJson(a as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Unique identifier (typically matches user ID).
  final String id;

  /// Total experience points earned.
  final int totalXp;

  /// Total number of quests completed.
  final int questsCompleted;

  /// Total number of sub-quests completed.
  final int subQuestsCompleted;

  /// Total number of focus sessions completed.
  final int focusSessionsCompleted;

  /// Total time spent in focus sessions.
  final Duration totalFocusTime;

  /// Current daily streak.
  final int currentStreak;

  /// Longest streak ever achieved.
  final int longestStreak;

  /// Last date the user was active.
  final DateTime? lastActiveDate;

  /// List of achievements earned.
  final List<Achievement> achievements;

  /// When the progress record was created.
  final DateTime createdAt;

  /// When the progress was last updated.
  final DateTime? updatedAt;

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'totalXp': totalXp,
      'questsCompleted': questsCompleted,
      'subQuestsCompleted': subQuestsCompleted,
      'focusSessionsCompleted': focusSessionsCompleted,
      'totalFocusTimeSeconds': totalFocusTime.inSeconds,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastActiveDate': lastActiveDate?.toIso8601String(),
      'achievements': achievements.map((a) => a.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Creates a copy with the given fields replaced.
  UserProgress copyWith({
    String? id,
    int? totalXp,
    int? questsCompleted,
    int? subQuestsCompleted,
    int? focusSessionsCompleted,
    Duration? totalFocusTime,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActiveDate,
    List<Achievement>? achievements,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProgress(
      id: id ?? this.id,
      totalXp: totalXp ?? this.totalXp,
      questsCompleted: questsCompleted ?? this.questsCompleted,
      subQuestsCompleted: subQuestsCompleted ?? this.subQuestsCompleted,
      focusSessionsCompleted:
          focusSessionsCompleted ?? this.focusSessionsCompleted,
      totalFocusTime: totalFocusTime ?? this.totalFocusTime,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      achievements: achievements ?? this.achievements,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Current level based on total XP.
  int get level => levelFromTotalXp(totalXp);

  /// XP required to reach the next level.
  int get xpForNextLevel => xpRequiredForLevel(level + 1);

  /// XP progress towards the next level.
  int get xpProgressInCurrentLevel {
    final currentLevelTotalXp = totalXpForLevel(level);
    return totalXp - currentLevelTotalXp;
  }

  /// Progress towards next level as a value between 0.0 and 1.0.
  double get levelProgress {
    if (xpForNextLevel == 0) return 0;
    return xpProgressInCurrentLevel / xpForNextLevel;
  }

  /// Adds XP and returns updated progress.
  UserProgress addXp(int xp, {DateTime? now}) {
    final newTotalXp = totalXp + xp;
    return copyWith(
      totalXp: newTotalXp,
      updatedAt: now ?? DateTime.now(),
    );
  }

  /// Records a completed quest and awards XP.
  UserProgress completeQuest({int xpReward = 50, DateTime? now}) {
    return copyWith(
      totalXp: totalXp + xpReward,
      questsCompleted: questsCompleted + 1,
      updatedAt: now ?? DateTime.now(),
    );
  }

  /// Records a completed sub-quest and awards XP.
  UserProgress completeSubQuest({int xpReward = 10, DateTime? now}) {
    return copyWith(
      totalXp: totalXp + xpReward,
      subQuestsCompleted: subQuestsCompleted + 1,
      updatedAt: now ?? DateTime.now(),
    );
  }

  /// Records a completed focus session and awards XP.
  UserProgress completeFocusSession({
    required Duration sessionDuration,
    int? xpReward,
    DateTime? now,
  }) {
    // Award 1 XP per minute of focus, minimum 5 XP
    final calculatedXp = xpReward ?? sessionDuration.inMinutes.clamp(5, 500);

    return copyWith(
      totalXp: totalXp + calculatedXp,
      focusSessionsCompleted: focusSessionsCompleted + 1,
      totalFocusTime: totalFocusTime + sessionDuration,
      updatedAt: now ?? DateTime.now(),
    );
  }

  /// Updates the daily streak based on activity.
  UserProgress updateStreak({DateTime? now}) {
    final today = now ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (lastActiveDate == null) {
      // First activity
      return copyWith(
        currentStreak: 1,
        longestStreak: 1,
        lastActiveDate: todayDate,
        updatedAt: today,
      );
    }

    final lastDate = DateTime(
      lastActiveDate!.year,
      lastActiveDate!.month,
      lastActiveDate!.day,
    );

    final daysDifference = todayDate.difference(lastDate).inDays;

    if (daysDifference == 0) {
      // Same day, no streak change
      return copyWith(updatedAt: today);
    } else if (daysDifference == 1) {
      // Consecutive day, increment streak
      final newStreak = currentStreak + 1;
      return copyWith(
        currentStreak: newStreak,
        longestStreak: newStreak > longestStreak ? newStreak : longestStreak,
        lastActiveDate: todayDate,
        updatedAt: today,
      );
    } else {
      // Streak broken, start over
      return copyWith(
        currentStreak: 1,
        lastActiveDate: todayDate,
        updatedAt: today,
      );
    }
  }

  /// Adds an achievement if not already earned.
  UserProgress addAchievement(AchievementType type, {DateTime? now}) {
    if (achievements.any((a) => a.type == type)) {
      return this; // Already has this achievement
    }

    final achievement = Achievement(
      type: type,
      unlockedAt: now ?? DateTime.now(),
    );

    return copyWith(
      achievements: [...achievements, achievement],
      updatedAt: now ?? DateTime.now(),
    );
  }

  /// Checks if a specific achievement has been earned.
  bool hasAchievement(AchievementType type) {
    return achievements.any((a) => a.type == type);
  }

  /// Returns formatted total focus time.
  String get formattedTotalFocusTime {
    final hours = totalFocusTime.inHours;
    final minutes = totalFocusTime.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProgress &&
        other.id == id &&
        other.totalXp == totalXp &&
        other.questsCompleted == questsCompleted &&
        other.subQuestsCompleted == subQuestsCompleted &&
        other.focusSessionsCompleted == focusSessionsCompleted &&
        other.totalFocusTime == totalFocusTime &&
        other.currentStreak == currentStreak &&
        other.longestStreak == longestStreak &&
        other.lastActiveDate == lastActiveDate &&
        listEquals(other.achievements, achievements) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      totalXp,
      questsCompleted,
      subQuestsCompleted,
      focusSessionsCompleted,
      totalFocusTime,
      currentStreak,
      longestStreak,
      lastActiveDate,
      Object.hashAll(achievements),
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserProgress(id: $id, level: $level, totalXp: $totalXp, '
        'streak: $currentStreak)';
  }
}
