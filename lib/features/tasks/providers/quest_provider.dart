import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    final quest = currentState.quests.firstWhere((Quest q) => q.id == questId);
    final now = completionDate ?? DateTime.now();

    Quest updatedQuest;

    if (quest.isRepeating) {
      final isSameDayCompletion =
          quest.lastCompletedAt != null &&
          _isSameDay(quest.lastCompletedAt!, now);

      if (quest.isCompleted && isSameDayCompletion) {
        // Uncompleting the current day's completion
        updatedQuest = quest.copyWith(
          status: QuestStatus.pending,
          updatedAt: now,
          completionCount: quest.completionCount > 0
              ? quest.completionCount - 1
              : 0,
        );
      } else {
        // Completing for this day (or moving completion to this day)
        updatedQuest = quest.copyWith(
          status: QuestStatus.completed,
          lastCompletedAt: now,
          completionCount: quest.completionCount + 1,
          updatedAt: now,
        );
      }
    } else {
      // Non-repeating quest - simple toggle
      updatedQuest = quest.isCompleted
          ? quest.copyWith(
              status: QuestStatus.pending,
              updatedAt: now,
            )
          : quest.copyWith(
              status: QuestStatus.completed,
              completedAt: now,
              updatedAt: now,
            );
    }

    await updateQuest(updatedQuest);
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
