import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/sync_service.dart';
import 'package:focus_quest/features/profile/providers/user_progress_provider.dart';
import 'package:focus_quest/models/quest.dart';
import 'package:focus_quest/services/sembast_service.dart';
import 'package:sembast/sembast.dart';

/// State for the quest list
class QuestListState {
  const QuestListState({
    this.quests = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory,
  });

  final List<Quest> quests;
  final bool isLoading;
  final String? error;
  final QuestCategory? selectedCategory;

  QuestListState copyWith({
    List<Quest>? quests,
    bool? isLoading,
    String? error,
    QuestCategory? selectedCategory,
    bool clearCategory = false,
  }) {
    return QuestListState(
      quests: quests ?? this.quests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
    );
  }

  /// Get quests filtered by category
  List<Quest> _filterByCategory(List<Quest> questList) {
    if (selectedCategory == null) return questList;
    return questList
        .where((Quest q) => q.category == selectedCategory)
        .toList();
  }

  /// Get active quests (pending or in progress)
  List<Quest> get activeQuests {
    final active = quests.where((Quest q) => q.isActive).toList()
      ..sort((Quest a, Quest b) => b.createdAt.compareTo(a.createdAt));
    return _filterByCategory(active);
  }

  /// Get completed quests (non-repeating only, or repeating that are not due)
  List<Quest> get completedQuests {
    final completed =
        quests.where((Quest q) {
          if (q.isRepeating) {
            // For repeating quests, show in completed if not due
            return q.isCompleted && !q.isDueForRepeat;
          }
          return q.isCompleted;
        }).toList()..sort(
          (Quest a, Quest b) => (b.completedAt ?? b.createdAt).compareTo(
            a.completedAt ?? a.createdAt,
          ),
        );
    return _filterByCategory(completed);
  }

  /// Get all active quests including repeating ones that are due
  List<Quest> get allActiveQuests {
    final active = quests.where((Quest q) {
      if (q.isRepeating && q.isDueForRepeat) {
        return true; // Show repeating quests that are due
      }
      return q.isActive;
    }).toList()..sort((Quest a, Quest b) => b.createdAt.compareTo(a.createdAt));
    return _filterByCategory(active);
  }

  /// Check if there are any overdue non-repeating tasks relative to a date
  bool hasOverdueTasks(DateTime targetDate) {
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return quests.any((q) {
      if (q.isRepeating || q.isCompleted || q.dueDate == null) return false;
      final due = DateTime(q.dueDate!.year, q.dueDate!.month, q.dueDate!.day);
      return due.isBefore(target);
    });
  }
}

/// Notifier for managing quest list state
class QuestListNotifier extends AsyncNotifier<QuestListState> {
  late final SembastService _db;

  @override
  Future<QuestListState> build() async {
    _db = SembastService();
    return _loadQuests();
  }

  Future<QuestListState> _loadQuests({QuestCategory? category}) async {
    try {
      final db = await _db.database;
      final records = await _db.quests.find(db);

      final quests =
          records
              .map(
                (RecordSnapshot<String, Map<String, Object?>> record) =>
                    Quest.fromJson(Map<String, dynamic>.from(record.value)),
              )
              .toList()
            ..sort((Quest a, Quest b) => b.createdAt.compareTo(a.createdAt));

      return QuestListState(quests: quests, selectedCategory: category);
    } on Exception catch (e) {
      return QuestListState(error: 'Failed to load quests: $e');
    }
  }

  /// Filter quests by category
  void filterByCategory(QuestCategory? category) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(
      currentState.copyWith(
        selectedCategory: category,
        clearCategory: category == null,
      ),
    );
  }

  /// Add a new quest
  Future<void> addQuest(Quest quest) async {
    state = const AsyncValue.loading();

    final currentCategory = state.value?.selectedCategory;
    state = await AsyncValue.guard(() async {
      final db = await _db.database;
      await _db.quests.record(quest.id).put(db, quest.toJson());

      // Sync to Firestore
      await ref.read(syncServiceProvider).syncQuest(quest);

      return _loadQuests(category: currentCategory);
    });
  }

  /// Update an existing quest
  Future<void> updateQuest(Quest quest) async {
    final currentState = state.value;
    if (currentState == null) return;

    // Optimistic update
    final updatedQuests = currentState.quests.map((Quest q) {
      return q.id == quest.id ? quest : q;
    }).toList();

    state = AsyncValue.data(currentState.copyWith(quests: updatedQuests));

    // Persist
    try {
      final db = await _db.database;
      await _db.quests.record(quest.id).put(db, quest.toJson());

      // Sync to Firestore
      await ref.read(syncServiceProvider).syncQuest(quest);
    } on Exception {
      // Revert on error
      final category = currentState.selectedCategory;
      state = await AsyncValue.guard(() => _loadQuests(category: category));
    }
  }

  /// Toggle quest completion status
  Future<void> toggleQuestCompletion(
    String questId, {
    DateTime? completionDate,
    String? note,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    final quest = currentState.quests.firstWhere((Quest q) => q.id == questId);
    final now = completionDate ?? DateTime.now();
    final dateKey = _formatDateKey(now);

    Quest updatedQuest;

    if (quest.isRepeating) {
      final isSameDayCompletion =
          quest.lastCompletedAt != null &&
          _isSameDay(quest.lastCompletedAt!, now);

      if (quest.isCompleted && isSameDayCompletion) {
        // Uncompleting the current day's completion
        final updatedNotes = Map<String, String>.from(quest.completionNotes)
          ..remove(dateKey);

        final uncompletedQuest = quest.copyWith(
          status: QuestStatus.pending,
          updatedAt: now,
          completionCount: quest.completionCount > 0
              ? quest.completionCount - 1
              : 0,
          completionNotes: updatedNotes,
        );

        // Recalculate streak after uncompleting
        final newStreak = uncompletedQuest.calculateStreak();
        updatedQuest = uncompletedQuest.copyWith(currentStreak: newStreak);
      } else {
        // Completing for this day (or moving completion to this day)
        final updatedNotes = Map<String, String>.from(quest.completionNotes);
        // Always add an entry for the date, even with empty note, to track
        // streaks
        updatedNotes[dateKey] = note ?? updatedNotes[dateKey] ?? '';

        final completedQuest = quest.copyWith(
          status: QuestStatus.completed,
          lastCompletedAt: now,
          completionCount: quest.completionCount + 1,
          updatedAt: now,
          completionNotes: updatedNotes,
        );

        // Recalculate streak
        final newStreak = completedQuest.calculateStreak();
        updatedQuest = completedQuest.copyWith(
          currentStreak: newStreak,
          longestStreak: newStreak > quest.longestStreak
              ? newStreak
              : quest.longestStreak,
        );

        // Update global user progress stats
        unawaited(
          ref.read(userProgressProvider.notifier).completeQuest(),
        );
      }
    } else {
      // Non-repeating quest - simple toggle
      final updatedNotes = Map<String, String>.from(quest.completionNotes);
      if (quest.isCompleted) {
        updatedNotes.remove(dateKey);
        updatedQuest = quest.copyWith(
          status: QuestStatus.pending,
          updatedAt: now,
          completionNotes: updatedNotes,
        );
      } else {
        if (note != null && note.isNotEmpty) {
          updatedNotes[dateKey] = note;
        }
        updatedQuest = quest.copyWith(
          status: QuestStatus.completed,
          completedAt: now,
          updatedAt: now,
          completionNotes: updatedNotes,
        );

        // Update global user progress stats
        unawaited(
          ref.read(userProgressProvider.notifier).completeQuest(),
        );
      }
    }

    await updateQuest(updatedQuest);
  }

  String _formatDateKey(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Skips a repeating quest for a specific date
  Future<void> skipQuestForToday(String questId, {DateTime? targetDate}) async {
    final currentState = state.value;
    if (currentState == null) return;

    final quest = currentState.quests.firstWhere((q) => q.id == questId);
    if (!quest.isRepeating) return;

    final date = targetDate ?? DateTime.now();
    final updatedSkipped = List<DateTime>.from(quest.skippedDates)..add(date);

    await updateQuest(quest.copyWith(skippedDates: updatedSkipped));
  }

  /// Stops recurrence of a quest from a specific date onwards
  Future<void> stopQuestRecurrence(
    String questId, {
    DateTime? targetDate,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    final quest = currentState.quests.firstWhere((q) => q.id == questId);
    if (!quest.isRepeating) return;

    final date = targetDate ?? DateTime.now();
    // Set recurrence end date to day before to effectively stop it from target
    // date
    final dayBefore = date.subtract(const Duration(days: 1));

    await updateQuest(quest.copyWith(recurrenceEndDate: dayBefore));
  }

  /// Delete a quest
  Future<void> deleteQuest(String questId) async {
    final currentState = state.value;
    if (currentState == null) return;

    // Optimistic update
    final updatedQuests = currentState.quests
        .where((Quest q) => q.id != questId)
        .toList();
    state = AsyncValue.data(currentState.copyWith(quests: updatedQuests));

    // Persist
    try {
      final db = await _db.database;
      await _db.quests.record(questId).delete(db);

      // Sync delete to Firestore
      await ref.read(syncServiceProvider).syncDeleteQuest(questId);
    } on Exception {
      // Revert on error
      final category = currentState.selectedCategory;
      state = await AsyncValue.guard(() => _loadQuests(category: category));
    }
  }

  /// Start a quest (set to in progress)
  Future<void> startQuest(String questId) async {
    final currentState = state.value;
    if (currentState == null) return;

    final quest = currentState.quests.firstWhere((Quest q) => q.id == questId);
    final updatedQuest = quest.copyWith(
      status: QuestStatus.inProgress,
      updatedAt: DateTime.now(),
    );

    await updateQuest(updatedQuest);
  }

  /// Reset a repeating quest to pending
  Future<void> resetRepeatingQuest(String questId) async {
    final currentState = state.value;
    if (currentState == null) return;

    final quest = currentState.quests.firstWhere((Quest q) => q.id == questId);
    if (!quest.isRepeating) return;

    final updatedQuest = quest.copyWith(
      status: QuestStatus.pending,
      updatedAt: DateTime.now(),
    );

    await updateQuest(updatedQuest);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Moves a quest to a new date (updates dueDate and resets status if needed).
  Future<void> rescheduleQuest(String questId, DateTime newDate) async {
    final currentState = state.value;
    if (currentState == null) return;

    final quest = currentState.quests.firstWhere((q) => q.id == questId);

    // If it was completed, maybe we shouldn't reschedule?
    // Assuming we reschedule pending tasks.

    final updated = quest.copyWith(
      dueDate: newDate,
      status: QuestStatus.pending, // Reset to pending if it was stuck
      updatedAt: DateTime.now(),
    );

    await updateQuest(updated);
  }

  /// Reschedules all overdue non-repeating tasks to the given date (default:
  /// today).
  Future<int> rescheduleOverdueTasks({DateTime? targetDate}) async {
    final currentState = state.value;
    if (currentState == null) return 0;

    final now = DateTime.now();
    final today = targetDate ?? DateTime(now.year, now.month, now.day);

    final overdue = currentState.quests.where((q) {
      if (q.isRepeating) return false; // Don't move repeating schedules
      if (q.isCompleted) return false;
      if (q.dueDate == null) return false;

      final due = DateTime(q.dueDate!.year, q.dueDate!.month, q.dueDate!.day);
      return due.isBefore(today); // Strictly before today
    }).toList();

    for (final quest in overdue) {
      await updateQuest(quest.copyWith(dueDate: today));
    }

    return overdue.length;
  }
}

/// Provider for quest list
final questListProvider =
    AsyncNotifierProvider<QuestListNotifier, QuestListState>(
      QuestListNotifier.new,
    );

/// Provider for active quests only (including due repeating quests)
final activeQuestsProvider = Provider<List<Quest>>((ref) {
  final state = ref.watch(questListProvider);
  return state.value?.allActiveQuests ?? [];
});

/// Provider for completed quests only
final completedQuestsProvider = Provider<List<Quest>>((ref) {
  final state = ref.watch(questListProvider);
  return state.value?.completedQuests ?? [];
});

/// Provider for selected category filter
final selectedCategoryProvider = Provider<QuestCategory?>((ref) {
  final state = ref.watch(questListProvider);
  return state.value?.selectedCategory;
});
