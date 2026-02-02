import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/notification_service.dart';
import 'package:focus_quest/core/services/sync_service.dart';
import 'package:focus_quest/features/auth/providers/auth_provider.dart';
import 'package:focus_quest/models/user_activity_event.dart';
import 'package:focus_quest/models/user_progress.dart';
import 'package:focus_quest/services/sembast_service.dart';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

class UserProgressNotifier extends AsyncNotifier<UserProgress> {
  final SembastService _db = SembastService();
  static const String _userId = 'default_user';

  @override
  Future<UserProgress> build() async {
    // 1. Load basic state from events
    final progress = await _loadAndCalculateProgress();

    // 2. Silent backfill of achievements not yet recorded as events
    // (This handles the "migration" for existing users)
    final newAchievements = _scanForNewAchievements(progress);
    if (newAchievements.isNotEmpty) {
      await _persistAchievements(newAchievements, notify: false);
      // Reload to include the new events
      return _loadAndCalculateProgress();
    }

    return progress;
  }

  Future<UserProgress> _loadAndCalculateProgress() async {
    final db = await _db.database;

    // Load all events
    final records = await _db.userActivityEvents.find(db);
    final events = records
        .map((r) => UserActivityEvent.fromJson(r.value))
        .toList();

    // Calculate state from events
    final progress = UserProgress.initial(id: _userId);

    // If no events, return initial
    if (events.isEmpty) {
      return progress;
    }

    // Sort events by date (oldest first) to replay history
    events.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    return _calculateProgress(progress, events);
  }

  UserProgress _calculateProgress(
    UserProgress initial,
    List<UserActivityEvent> events,
  ) {
    var p = initial;

    // Reset counters
    var totalXp = 0;
    var quests = 0;
    var subQuests = 0;
    var focusSessions = 0;
    var totalFocusTime = Duration.zero; // in seconds

    // Streak calculation helpers
    final activeDates = <DateTime>{};

    for (final event in events) {
      // 1. Accumulate XP
      totalXp += event.xpEarned;

      // 2. Accumulate Counts
      switch (event.type) {
        case UserActivityType.questCompleted:
          quests++;
        case UserActivityType.subQuestCompleted:
          subQuests++;
        case UserActivityType.focusSessionCompleted:
          focusSessions++;
          if (event.metadata.containsKey('durationSeconds')) {
            totalFocusTime += Duration(
              seconds: event.metadata['durationSeconds'] as int,
            );
          }
        case UserActivityType.achievementUnlocked:
          // Handled in separate pass
          break;
        case UserActivityType.manualAdjustment:
        case UserActivityType.legacyImport:
          // Handle legacy stats if present
          if (event.metadata.containsKey('questsCompleted')) {
            quests += event.metadata['questsCompleted'] as int;
          }
          if (event.metadata.containsKey('subQuestsCompleted')) {
            subQuests += event.metadata['subQuestsCompleted'] as int;
          }
          if (event.metadata.containsKey('focusSessionsCompleted')) {
            focusSessions += event.metadata['focusSessionsCompleted'] as int;
          }
          if (event.metadata.containsKey('totalFocusTimeSeconds')) {
            totalFocusTime += Duration(
              seconds: event.metadata['totalFocusTimeSeconds'] as int,
            );
          }
      }

      // 3. Track Active Dates for Streak
      // We only count meaningful activity for streaks (quests, focus)
      if (event.type != UserActivityType.manualAdjustment) {
        final date = DateTime(
          event.occurredAt.year,
          event.occurredAt.month,
          event.occurredAt.day,
        );
        activeDates.add(date);
      }
    }

    // 4. Calculate Streak
    final sortedDates = activeDates.toList()..sort();
    var currentStreak = 0;
    var longestStreak = 0;

    if (sortedDates.isNotEmpty) {
      currentStreak = 1;
      longestStreak = 1;

      for (var i = 0; i < sortedDates.length - 1; i++) {
        final current = sortedDates[i];
        final next = sortedDates[i + 1];
        final diff = next.difference(current).inDays;

        if (diff == 1) {
          currentStreak++;
        } else if (diff > 1) {
          // Streak broken
          currentStreak = 1;
        }

        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
      }

      // Check if current streak is still valid (activity today or yesterday)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastActivity = sortedDates.last;

      final diffFromToday = today.difference(lastActivity).inDays;
      if (diffFromToday > 1) {
        currentStreak = 0;
      }
    }

    // Update Progress Object
    // Update Progress Object
    p = p.copyWith(
      totalXp: totalXp,
      questsCompleted: quests,
      subQuestsCompleted: subQuests,
      focusSessionsCompleted: focusSessions,
      totalFocusTime: totalFocusTime,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastActiveDate: sortedDates.isNotEmpty ? sortedDates.last : null,
      updatedAt: events.isNotEmpty ? events.last.occurredAt : DateTime.now(),
    );

    // Apply achievements from events
    for (final event in events) {
      if (event.type == UserActivityType.achievementUnlocked) {
        if (event.metadata.containsKey('achievementId')) {
          final output = event.metadata['achievementId'] as String;
          AchievementType? foundType;
          for (final val in AchievementType.values) {
            if (val.name == output) {
              foundType = val;
              break;
            }
          }

          if (foundType != null) {
            p = p.addAchievement(foundType);
          }
        }
      }
    }

    return p;
  }

  Future<void> _recordEvent(UserActivityEvent event) async {
    final db = await _db.database;
    final user = ref.read(authProvider).value;

    // Save locally
    await _db.userActivityEvents.record(event.id).put(db, event.toJson());

    // Sync immediately
    try {
      await ref.read(syncServiceProvider).syncUserActivityEvent(event);
    } on Exception catch (e) {
      debugPrint('Failed to sync event immediately: $e');
    }

    // Recalculate state
    // We strictly rebuild from DB to ensure consistency
    var newState = await _loadAndCalculateProgress();

    // Scan for NEW achievements triggered by this event
    final newAchievements = _scanForNewAchievements(newState);
    if (newAchievements.isNotEmpty) {
      await _persistAchievements(newAchievements, notify: true);
      // Reload again to get the achievements into the state
      newState = await _loadAndCalculateProgress();
    }

    // Also check for Level Up
    // We can compare against previous state if available, or just check logic.
    // _scanForNewAchievements doesn't handle Level Up notification logic which
    // was in _checkAchievements.
    // We should probably include level up check here.
    final oldLevel = state.value?.level;
    if (oldLevel != null && newState.level > oldLevel) {
      unawaited(
        NotificationService().showNotification(
          title: 'Level Up!',
          body: 'Congratulations! You reached level ${newState.level}!',
        ),
      );
    }

    state = AsyncValue.data(newState);

    // We also save the calculated UserProgress as a "snapshot" for backup/easy view
    await _db.userProgress.record(_userId).put(db, newState.toJson());
    // And sync that snapshot too (optional, but good for admin view)
    if (user?.isGamificationEnabled ?? false) {
      await ref.read(syncServiceProvider).syncUserProgress(newState);
    }
  }

  Future<void> _persistAchievements(
    List<AchievementType> achievements, {
    required bool notify,
  }) async {
    final user = ref.read(authProvider).value;
    for (final type in achievements) {
      final event = UserActivityEvent(
        id: const Uuid().v4(),
        userId: user?.id ?? _userId,
        type: UserActivityType.achievementUnlocked,
        xpEarned: 0,
        occurredAt: DateTime.now(),
        metadata: {'achievementId': type.name},
      );

      // Save locally
      final db = await _db.database;
      await _db.userActivityEvents.record(event.id).put(db, event.toJson());

      // Sync
      try {
        await ref.read(syncServiceProvider).syncUserActivityEvent(event);
      } on Exception catch (e) {
        debugPrint('Failed to sync achievement event: $e');
      }

      if (notify) {
        unawaited(
          NotificationService().showNotification(
            title: 'Achievement Unlocked!',
            body: 'You earned: ${_getAchievementName(type)}',
          ),
        );
      }
    }
  }

  Future<void> addXp(int xp) async {
    final user = ref.read(authProvider).value;
    if (user?.isGamificationEnabled == false) return;

    final event = UserActivityEvent(
      id: const Uuid().v4(),
      userId: user?.id ?? _userId,
      type: UserActivityType.manualAdjustment,
      xpEarned: xp,
      occurredAt: DateTime.now(),
    );

    await _recordEvent(event);
  }

  Future<void> completeFocusSession(
    Duration duration, {
    String? questId,
    String? subQuestId,
  }) async {
    final user = ref.read(authProvider).value;
    if (user?.isGamificationEnabled == false) return;

    // Award 1 XP per minute of focus, minimum 5 XP
    final calculatedXp = duration.inMinutes.clamp(5, 500);

    final event = UserActivityEvent(
      id: const Uuid().v4(),
      userId: user?.id ?? _userId,
      type: UserActivityType.focusSessionCompleted,
      xpEarned: calculatedXp,
      occurredAt: DateTime.now(),
      metadata: {
        'durationSeconds': duration.inSeconds,
        // The analyzer suggests null-aware elements, but explicit 'if' is
        // clearer for map entries here
        // ignore: use_null_aware_elements
        if (questId != null) 'questId': questId,
        // Same reason for subQuestId
        // ignore: use_null_aware_elements
        if (subQuestId != null) 'subQuestId': subQuestId,
      },
    );

    await _recordEvent(event);
  }

  Future<void> completeQuest() async {
    final user = ref.read(authProvider).value;
    if (user?.isGamificationEnabled == false) return;

    final event = UserActivityEvent(
      id: const Uuid().v4(),
      userId: user?.id ?? _userId,
      type: UserActivityType.questCompleted,
      xpEarned: 50, // Default quest XP
      occurredAt: DateTime.now(),
    );

    await _recordEvent(event);
  }

  List<AchievementType> _scanForNewAchievements(UserProgress p) {
    final newAchievements = <AchievementType>[];

    void check({required AchievementType type, required bool condition}) {
      if (condition && !p.hasAchievement(type)) {
        newAchievements.add(type);
      }
    }

    check(type: AchievementType.firstQuest, condition: p.questsCompleted >= 1);
    check(
      type: AchievementType.questMaster,
      condition: p.questsCompleted >= 10,
    );
    check(
      type: AchievementType.questLegend,
      condition: p.questsCompleted >= 100,
    );
    check(
      type: AchievementType.firstFocus,
      condition: p.focusSessionsCompleted >= 1,
    );
    check(
      type: AchievementType.focusHour,
      condition: p.totalFocusTime.inHours >= 1,
    );
    check(
      type: AchievementType.focusMarathon,
      condition: p.totalFocusTime.inHours >= 10,
    );
    check(type: AchievementType.levelFive, condition: p.level >= 5);
    check(type: AchievementType.levelTen, condition: p.level >= 10);
    check(type: AchievementType.levelTwentyFive, condition: p.level >= 25);
    check(type: AchievementType.weekStreak, condition: p.currentStreak >= 7);
    check(type: AchievementType.monthStreak, condition: p.currentStreak >= 30);

    return newAchievements;
  }

  String _getAchievementName(AchievementType type) {
    switch (type) {
      case AchievementType.firstQuest:
        return 'First Quest';
      case AchievementType.questMaster:
        return 'Quest Master';
      case AchievementType.questLegend:
        return 'Quest Legend';
      case AchievementType.firstFocus:
        return 'Focused Mind';
      case AchievementType.focusHour:
        return 'Focus Hour';
      case AchievementType.focusMarathon:
        return 'Focus Marathon';
      case AchievementType.levelFive:
        return 'Level 5 Reached';
      case AchievementType.levelTen:
        return 'Level 10 Reached';
      case AchievementType.levelTwentyFive:
        return 'Level 25 Reached';
      case AchievementType.weekStreak:
        return '7 Day Streak';
      case AchievementType.monthStreak:
        return '30 Day Streak';
    }
  }
}

final userProgressProvider =
    AsyncNotifierProvider<UserProgressNotifier, UserProgress>(
      UserProgressNotifier.new,
    );
