import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/notification_service.dart';
import 'package:focus_quest/core/services/sync_service.dart';
import 'package:focus_quest/features/auth/providers/auth_provider.dart';
import 'package:focus_quest/models/user_progress.dart';
import 'package:focus_quest/services/sembast_service.dart';
import 'package:sembast/sembast.dart';

class UserProgressNotifier extends AsyncNotifier<UserProgress> {
  late final SembastService _db;
  static const String _userId = 'default_user';

  @override
  Future<UserProgress> build() async {
    _db = SembastService();
    return _loadProgress();
  }

  Future<UserProgress> _loadProgress() async {
    final db = await _db.database;
    final record = await _db.userProgress.record(_userId).get(db);

    if (record == null) {
      final initialProgress = UserProgress.initial(id: _userId);
      await _db.userProgress.record(_userId).put(db, initialProgress.toJson());
      return initialProgress;
    }

    return UserProgress.fromJson(Map<String, dynamic>.from(record));
  }

  Future<void> _saveProgress(UserProgress progress) async {
    final db = await _db.database;
    await _db.userProgress.record(_userId).put(db, progress.toJson());
    state = AsyncValue.data(progress);

    // Sync to Firestore
    await ref.read(syncServiceProvider).syncUserProgress(progress);
  }

  Future<void> addXp(int xp) async {
    final user = ref.read(authProvider).value;
    if (user?.isGamificationEnabled == false) return;

    final current = state.value;
    if (current == null) return;

    var updated = current.addXp(xp);

    // Check for level up achievements or other progress-based ones
    updated = _checkAchievements(updated);

    await _saveProgress(updated);
  }

  Future<void> completeFocusSession(Duration duration) async {
    final current = state.value;
    if (current == null) return;

    final user = ref.read(authProvider).value;
    if (user?.isGamificationEnabled == false) return;

    // Award 1 XP per minute of focus, minimum 5 XP
    final calculatedXp = duration.inMinutes.clamp(5, 500);

    var updated = current.completeFocusSession(sessionDuration: duration);
    // Add XP after completing the session
    updated = updated.addXp(calculatedXp);
    updated = updated.updateStreak();
    updated = _checkAchievements(updated);

    await _saveProgress(updated);
  }

  Future<void> completeQuest() async {
    final current = state.value;
    if (current == null) return;

    final user = ref.read(authProvider).value;
    if (user?.isGamificationEnabled == false) return;

    var updated = current.completeQuest();
    updated = updated.updateStreak();
    updated = _checkAchievements(updated);

    await _saveProgress(updated);
  }

  UserProgress _checkAchievements(UserProgress progress) {
    var p = progress;
    final oldLevel = state.value?.level ?? 1;
    final newLevel = p.level;

    // Level up notification
    if (newLevel > oldLevel) {
      unawaited(
        NotificationService().showNotification(
          title: 'Level Up!',
          body: 'Congratulations! You reached level $newLevel!',
        ),
      );
    }

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

    for (final type in newAchievements) {
      p = p.addAchievement(type);
      unawaited(
        NotificationService().showNotification(
          title: 'Achievement Unlocked!',
          body: 'You earned: ${_getAchievementName(type)}',
        ),
      );
    }

    return p;
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
