import 'package:flutter/foundation.dart';

/// Status of a quest in the task management system.
enum QuestStatus {
  /// Quest is waiting to be started.
  pending,

  /// Quest is currently being worked on.
  inProgress,

  /// Quest has been completed successfully.
  completed,

  /// Quest was abandoned/cancelled.
  cancelled,
}

/// Energy level required/associated with a quest (1-5 scale).
///
/// ADHD-friendly energy categorization for task planning.
enum EnergyLevel {
  /// Minimal effort - autopilot tasks (1/5).
  minimal,

  /// Low effort - easy tasks requiring little focus (2/5).
  low,

  /// Medium effort - moderate focus required (3/5).
  medium,

  /// High effort - significant focus and energy (4/5).
  high,

  /// Maximum effort - deep work, high cognitive load (5/5).
  intense,
}

/// Category for organizing quests.
enum QuestCategory {
  /// Work-related tasks.
  work,

  /// Personal tasks and errands.
  personal,

  /// Learning and skill development.
  learning,

  /// Other/miscellaneous tasks.
  other,
}

/// Repeat frequency for recurring quests.
enum RepeatFrequency {
  /// Quest does not repeat.
  none,

  /// Quest repeats on selected days (or every day if no days selected).
  daily,

  /// Quest repeats every week.
  weekly,

  /// Quest repeats every month.
  monthly,
}

/// Days of the week for repeat scheduling.
/// Values match DateTime.weekday (1=Monday, 7=Sunday).
enum Weekday {
  monday(1, 'Mon', 'Monday'),
  tuesday(2, 'Tue', 'Tuesday'),
  wednesday(3, 'Wed', 'Wednesday'),
  thursday(4, 'Thu', 'Thursday'),
  friday(5, 'Fri', 'Friday'),
  saturday(6, 'Sat', 'Saturday'),
  sunday(7, 'Sun', 'Sunday')
  ;

  const Weekday(this.value, this.shortName, this.fullName);

  /// The weekday value (1-7, matches DateTime.weekday).
  final int value;

  /// Short name (Mon, Tue, etc.).
  final String shortName;

  /// Full name (Monday, Tuesday, etc.).
  final String fullName;

  /// Get Weekday from DateTime.weekday value.
  static Weekday fromValue(int value) {
    return Weekday.values.firstWhere((w) => w.value == value);
  }

  /// Get today's weekday.
  static Weekday get today => fromValue(DateTime.now().weekday);
}

/// A Quest represents a main task or goal in the Focus Quest system.
///
/// Quests can contain multiple sub-quests for breaking down larger tasks
/// into manageable, ADHD-friendly chunks.
@immutable
class Quest {
  /// Creates a new Quest instance.
  const Quest({
    required this.id,
    required this.title,
    required this.createdAt,
    this.description,
    this.status = QuestStatus.pending,
    this.energyLevel = EnergyLevel.medium,
    this.category = QuestCategory.other,
    this.repeatFrequency = RepeatFrequency.none,
    this.repeatDays = const {},
    this.lastCompletedAt,
    this.completionCount = 0,
    this.updatedAt,
    this.completedAt,
    this.dueDate,
    this.tags = const [],
    this.skippedDates = const [],
    this.recurrenceEndDate,
    this.completionNotes = const {},
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  /// Creates a Quest from a JSON map.
  factory Quest.fromJson(Map<String, dynamic> json) {
    // Parse repeatDays from list of integers
    final repeatDaysList = json['repeatDays'] as List<dynamic>?;
    final repeatDays = repeatDaysList != null
        ? repeatDaysList.cast<int>().map(Weekday.fromValue).toSet()
        : <Weekday>{};

    return Quest(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: QuestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => QuestStatus.pending,
      ),
      energyLevel: EnergyLevel.values.firstWhere(
        (e) => e.name == json['energyLevel'],
        orElse: () => EnergyLevel.medium,
      ),
      category: QuestCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => QuestCategory.other,
      ),
      repeatFrequency: RepeatFrequency.values.firstWhere(
        (r) => r.name == json['repeatFrequency'],
        orElse: () => RepeatFrequency.none,
      ),
      repeatDays: repeatDays,
      lastCompletedAt: json['lastCompletedAt'] != null
          ? DateTime.parse(json['lastCompletedAt'] as String)
          : null,
      completionCount: json['completionCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      skippedDates:
          (json['skippedDates'] as List<dynamic>?)
              ?.map((d) => DateTime.parse(d as String))
              .toList() ??
          const [],
      recurrenceEndDate: json['recurrenceEndDate'] != null
          ? DateTime.parse(json['recurrenceEndDate'] as String)
          : null,
      completionNotes:
          (json['completionNotes'] as Map<dynamic, dynamic>?)
              ?.cast<String, String>() ??
          const {},
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
    );
  }

  /// Unique identifier for the quest.
  final String id;

  /// Title of the quest.
  final String title;

  /// Optional detailed description.
  final String? description;

  /// Current status of the quest.
  final QuestStatus status;

  /// Energy level required for this quest (1-5).
  final EnergyLevel energyLevel;

  /// Category of the quest.
  final QuestCategory category;

  /// How often this quest repeats.
  final RepeatFrequency repeatFrequency;

  /// Days of the week this quest repeats on (for daily frequency).
  /// Empty set means every day.
  final Set<Weekday> repeatDays;

  /// When the quest was last completed (for repeating quests).
  final DateTime? lastCompletedAt;

  /// Number of times this quest has been completed.
  final int completionCount;

  /// When the quest was created.
  final DateTime createdAt;

  /// When the quest was last updated.
  final DateTime? updatedAt;

  /// When the quest was completed (if completed and non-repeating).
  final DateTime? completedAt;

  /// Optional due date for the quest.
  final DateTime? dueDate;

  /// Tags for categorization and filtering.
  final List<String> tags;

  /// Dates to skip for repeating quests.
  final List<DateTime> skippedDates;

  /// Optional end date for recurrence.
  final DateTime? recurrenceEndDate;

  /// Notes for specific completion dates.
  final Map<String, String> completionNotes;

  /// Current streak for repeating quests.
  final int currentStreak;

  /// Longest streak reached for this quest.
  final int longestStreak;

  /// Converts the Quest to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.name,
      'energyLevel': energyLevel.name,
      'category': category.name,
      'repeatFrequency': repeatFrequency.name,
      'repeatDays': repeatDays.map((Weekday w) => w.value).toList(),
      'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      'completionCount': completionCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'tags': tags,
      'skippedDates': skippedDates.map((d) => d.toIso8601String()).toList(),
      'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
      'completionNotes': completionNotes,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
    };
  }

  /// Creates a copy of this quest with the given fields replaced.
  Quest copyWith({
    String? id,
    String? title,
    String? description,
    QuestStatus? status,
    EnergyLevel? energyLevel,
    QuestCategory? category,
    RepeatFrequency? repeatFrequency,
    Set<Weekday>? repeatDays,
    DateTime? lastCompletedAt,
    int? completionCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? dueDate,
    List<String>? tags,
    List<DateTime>? skippedDates,
    DateTime? recurrenceEndDate,
    Map<String, String>? completionNotes,
    int? currentStreak,
    int? longestStreak,
  }) {
    return Quest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      energyLevel: energyLevel ?? this.energyLevel,
      category: category ?? this.category,
      repeatFrequency: repeatFrequency ?? this.repeatFrequency,
      repeatDays: repeatDays ?? this.repeatDays,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      completionCount: completionCount ?? this.completionCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      dueDate: dueDate ?? this.dueDate,
      tags: tags ?? this.tags,
      skippedDates: skippedDates ?? this.skippedDates,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      completionNotes: completionNotes ?? this.completionNotes,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
    );
  }

  /// Returns true if this is a repeating quest.
  bool get isRepeating => repeatFrequency != RepeatFrequency.none;

  /// Returns true if the quest is considered active (pending or in progress).
  bool get isActive =>
      status == QuestStatus.pending || status == QuestStatus.inProgress;

  /// Returns true if the quest has been completed.
  bool get isCompleted => status == QuestStatus.completed;

  /// Returns the energy level as a numeric value (1-5).
  int get energyValue => energyLevel.index + 1;

  /// Returns true if today is a scheduled repeat day.
  bool get isScheduledForToday {
    if (repeatFrequency != RepeatFrequency.daily) return true;
    if (repeatDays.isEmpty) return true; // Empty means every day
    return repeatDays.contains(Weekday.today);
  }

  /// Gets a formatted string of repeat days.
  String get repeatDaysFormatted {
    if (repeatDays.isEmpty) return 'Every day';
    if (repeatDays.length == 7) return 'Every day';

    // Check for weekdays (Mon-Fri)
    final weekdays = {
      Weekday.monday,
      Weekday.tuesday,
      Weekday.wednesday,
      Weekday.thursday,
      Weekday.friday,
    };
    if (setEquals(repeatDays, weekdays)) return 'Weekdays';

    // Check for weekends (Sat-Sun)
    final weekends = {Weekday.saturday, Weekday.sunday};
    if (setEquals(repeatDays, weekends)) return 'Weekends';

    // Sort by weekday value and join short names
    final sorted = repeatDays.toList()
      ..sort((Weekday a, Weekday b) => a.value.compareTo(b.value));
    return sorted.map((Weekday w) => w.shortName).join(', ');
  }

  /// Checks if a repeating quest is due for completion.
  bool get isDueForRepeat {
    if (!isRepeating) return false;

    // For daily quests, check if today is a scheduled day
    if (repeatFrequency == RepeatFrequency.daily && !isScheduledForToday) {
      return false;
    }

    final now = DateTime.now();

    // Check if recurrence has ended
    if (recurrenceEndDate != null && _isBeforeDay(recurrenceEndDate!, now)) {
      return false;
    }

    // Check if today is skipped
    if (skippedDates.any((d) => _isSameDay(d, now))) {
      return false;
    }

    if (lastCompletedAt == null) return true;

    final lastCompleted = lastCompletedAt!;

    switch (repeatFrequency) {
      case RepeatFrequency.none:
        return false;
      case RepeatFrequency.daily:
        return !_isSameDay(now, lastCompleted);
      case RepeatFrequency.weekly:
        return now.difference(lastCompleted).inDays >= 7;
      case RepeatFrequency.monthly:
        return now.month != lastCompleted.month ||
            now.year != lastCompleted.year;
    }
  }

  /// Checks if the quest is scheduled for a specific date.
  bool isScheduledForDate(DateTime date) {
    // Ensure the date is not before the quest was created (start date)
    if (_isBeforeDay(date, createdAt)) return false;

    // Check if recurrence has ended
    if (recurrenceEndDate != null && _isBeforeDay(recurrenceEndDate!, date)) {
      return false;
    }

    // Check if date is skipped
    if (skippedDates.any((d) => _isSameDay(d, date))) return false;

    // If not repeating, check due date
    if (!isRepeating) {
      if (dueDate != null) {
        return _isSameDay(dueDate!, date);
      }
      // If no due date, maybe repeat "pending" quests on "today"?
      // For now, only precise match or if it's created today?
      return false;
    }

    // For repeating quests
    switch (repeatFrequency) {
      case RepeatFrequency.none:
        return false;
      case RepeatFrequency.daily:
        if (repeatDays.isEmpty) return true; // Every day
        return repeatDays.contains(Weekday.fromValue(date.weekday));
      case RepeatFrequency.weekly:
        // Assume weekly repeats on the same weekday as created/started
        // Or if simple "every 7 days" logic matches date
        // For calendar visualization, let's assume same weekday as createdAt
        return date.weekday == createdAt.weekday;
      case RepeatFrequency.monthly:
        // Assume same day of month
        return date.day == createdAt.day;
    }
  }

  bool _isBeforeDay(DateTime a, DateTime b) {
    if (a.year < b.year) return true;
    if (a.year == b.year && a.month < b.month) return true;
    if (a.year == b.year && a.month == b.month && a.day < b.day) return true;
    return false;
  }

  /// Returns the effective status for a specific date key.
  QuestStatus statusForDate(DateTime date) {
    if (repeatFrequency == RepeatFrequency.daily) {
      // Check if this date has a completion entry in the history
      final dateKey = _formatDateKey(date);
      if (completionNotes.containsKey(dateKey)) {
        return QuestStatus.completed;
      }
      return QuestStatus.pending;
    }
    return status;
  }

  /// Formats a date as a key string (YYYY-MM-DD) for completionNotes lookup.
  String _formatDateKey(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Calculates the current streak based on completionNotes.
  /// This can be used to recover or verify the stored streak.
  int calculateStreak() {
    if (!isRepeating || completionNotes.isEmpty) return 0;

    final sortedDates = completionNotes.keys.toList()..sort();
    if (sortedDates.isEmpty) return 0;

    var streak = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var checkDate = today;

    // A streak is valid if completed today OR yesterday (if not yet completed)
    final mToday = today.month.toString().padLeft(2, '0');
    final dToday = today.day.toString().padLeft(2, '0');
    final todayKey = '${today.year}-$mToday-$dToday';

    final yesterday = today.subtract(const Duration(days: 1));
    final mYesterday = yesterday.month.toString().padLeft(2, '0');
    final dYesterday = yesterday.day.toString().padLeft(2, '0');
    final yesterdayKey = '${yesterday.year}-$mYesterday-$dYesterday';

    if (!completionNotes.containsKey(todayKey) &&
        !completionNotes.containsKey(yesterdayKey)) {
      return 0;
    }

    if (!completionNotes.containsKey(todayKey)) {
      checkDate = yesterday;
    }

    while (true) {
      final mKey = checkDate.month.toString().padLeft(2, '0');
      final dKey = checkDate.day.toString().padLeft(2, '0');
      final key = '${checkDate.year}-$mKey-$dKey';

      if (completionNotes.containsKey(key)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        // For daily quests, a gap breaks the streak.
        // For other repeat frequencies, we might need different logic,
        // but let's stick to daily continuity for now.
        break;
      }
    }

    return streak;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Quest &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.status == status &&
        other.energyLevel == energyLevel &&
        other.category == category &&
        other.repeatFrequency == repeatFrequency &&
        setEquals(other.repeatDays, repeatDays) &&
        other.lastCompletedAt == lastCompletedAt &&
        other.completionCount == completionCount &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.completedAt == completedAt &&
        other.dueDate == dueDate &&
        listEquals(other.tags, tags) &&
        listEquals(other.skippedDates, skippedDates) &&
        other.recurrenceEndDate == recurrenceEndDate &&
        mapEquals(other.completionNotes, completionNotes);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      description,
      status,
      energyLevel,
      category,
      repeatFrequency,
      Object.hashAll(repeatDays),
      lastCompletedAt,
      completionCount,
      createdAt,
      updatedAt,
      completedAt,
      dueDate,
      Object.hashAll(tags),
      Object.hashAll(skippedDates),
      recurrenceEndDate,
      Object.hashAll(completionNotes.keys),
      Object.hashAll(completionNotes.values),
    );
  }

  @override
  String toString() {
    return 'Quest(id: $id, title: $title, status: $status, '
        'energyLevel: $energyLevel, category: $category, '
        'repeat: $repeatFrequency, days: $repeatDaysFormatted)';
  }
}

/// Extension methods for EnergyLevel.
extension EnergyLevelExtension on EnergyLevel {
  /// Returns the numeric value (1-5).
  int get value => index + 1;

  /// Returns a display label.
  String get label {
    switch (this) {
      case EnergyLevel.minimal:
        return 'Minimal';
      case EnergyLevel.low:
        return 'Low';
      case EnergyLevel.medium:
        return 'Medium';
      case EnergyLevel.high:
        return 'High';
      case EnergyLevel.intense:
        return 'Intense';
    }
  }
}

/// Extension methods for QuestCategory.
extension QuestCategoryExtension on QuestCategory {
  /// Returns a display label.
  String get label {
    switch (this) {
      case QuestCategory.work:
        return 'Work';
      case QuestCategory.personal:
        return 'Personal';
      case QuestCategory.learning:
        return 'Learning';
      case QuestCategory.other:
        return 'Other';
    }
  }
}

/// Extension methods for RepeatFrequency.
extension RepeatFrequencyExtension on RepeatFrequency {
  /// Returns a display label.
  String get label {
    switch (this) {
      case RepeatFrequency.none:
        return 'No repeat';
      case RepeatFrequency.daily:
        return 'Daily';
      case RepeatFrequency.weekly:
        return 'Weekly';
      case RepeatFrequency.monthly:
        return 'Monthly';
    }
  }
}
