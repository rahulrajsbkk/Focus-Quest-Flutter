import 'package:flutter_quest/models/user_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XP and Level calculations', () {
    test('xpRequiredForLevel returns correct values', () {
      expect(xpRequiredForLevel(1), 0);
      expect(xpRequiredForLevel(2), 200);
      expect(xpRequiredForLevel(3), 300);
      expect(xpRequiredForLevel(5), 500);
      expect(xpRequiredForLevel(10), 1000);
    });

    test('totalXpForLevel returns correct cumulative values', () {
      expect(totalXpForLevel(1), 0);
      expect(totalXpForLevel(2), 200); // 2*100 + offset
      expect(totalXpForLevel(3), 500); // 200 + 300
      expect(totalXpForLevel(4), 900); // 500 + 400
    });

    test('levelFromTotalXp returns correct level', () {
      expect(levelFromTotalXp(0), 1);
      expect(levelFromTotalXp(50), 1);
      expect(levelFromTotalXp(199), 1);
      expect(levelFromTotalXp(200), 2);
      expect(levelFromTotalXp(499), 2);
      expect(levelFromTotalXp(500), 3);
      expect(levelFromTotalXp(899), 3);
      expect(levelFromTotalXp(900), 4);
    });

    test('level and XP are consistent', () {
      // For any level, totalXpForLevel should be the threshold
      for (var level = 1; level <= 20; level++) {
        final threshold = totalXpForLevel(level);
        expect(levelFromTotalXp(threshold), level);

        if (level > 1) {
          // Just below threshold should be previous level
          expect(levelFromTotalXp(threshold - 1), level - 1);
        }
      }
    });
  });

  group('UserProgress', () {
    final testDate = DateTime(2025, 1, 15, 10);

    test('initial() creates progress with defaults', () {
      final progress = UserProgress.initial(id: 'user-1');

      expect(progress.id, 'user-1');
      expect(progress.totalXp, 0);
      expect(progress.level, 1);
      expect(progress.questsCompleted, 0);
      expect(progress.currentStreak, 0);
    });

    group('XP and level', () {
      test('level increases with XP', () {
        var progress = UserProgress(
          id: 'user-1',
          createdAt: testDate,
        );

        expect(progress.level, 1);

        progress = progress.addXp(200);
        expect(progress.level, 2);

        progress = progress.addXp(300); // Total: 500
        expect(progress.level, 3);
      });

      test('addXp increments total XP', () {
        final progress = UserProgress(
          id: 'user-1',
          totalXp: 100,
          createdAt: testDate,
        );

        final updated = progress.addXp(50);

        expect(updated.totalXp, 150);
      });

      test('levelProgress returns correct fraction', () {
        // At level 2 (200 XP), need 300 more for level 3
        // With 350 XP, progress should be 150/300 = 0.5
        final progress = UserProgress(
          id: 'user-1',
          totalXp: 350,
          createdAt: testDate,
        );

        expect(progress.level, 2);
        expect(progress.xpProgressInCurrentLevel, 150);
        expect(progress.xpForNextLevel, 300);
        expect(progress.levelProgress, closeTo(0.5, 0.01));
      });
    });

    group('quest completion', () {
      test('completeQuest increments count and adds XP', () {
        final progress = UserProgress(
          id: 'user-1',
          createdAt: testDate,
        );

        final updated = progress.completeQuest(now: testDate);

        expect(updated.questsCompleted, 1);
        expect(updated.totalXp, 50); // Default XP reward
      });

      test('completeQuest accepts custom XP reward', () {
        final progress = UserProgress(
          id: 'user-1',
          createdAt: testDate,
        );

        final updated = progress.completeQuest(xpReward: 100);

        expect(updated.totalXp, 100);
      });

      test('completeSubQuest increments count and adds XP', () {
        final progress = UserProgress(
          id: 'user-1',
          subQuestsCompleted: 5,
          createdAt: testDate,
        );

        final updated = progress.completeSubQuest();

        expect(updated.subQuestsCompleted, 6);
        expect(updated.totalXp, 10); // Default XP reward
      });
    });

    group('focus session completion', () {
      test('completeFocusSession updates all stats', () {
        final progress = UserProgress(
          id: 'user-1',
          createdAt: testDate,
        );

        final updated = progress.completeFocusSession(
          sessionDuration: const Duration(minutes: 25),
        );

        expect(updated.focusSessionsCompleted, 1);
        expect(updated.totalFocusTime, const Duration(minutes: 25));
        expect(updated.totalXp, 25); // Default XP reward
      });

      test('totalFocusTime accumulates', () {
        var progress = UserProgress(
          id: 'user-1',
          totalFocusTime: const Duration(minutes: 30),
          createdAt: testDate,
        );

        progress = progress.completeFocusSession(
          sessionDuration: const Duration(minutes: 25),
        );

        expect(progress.totalFocusTime, const Duration(minutes: 55));
      });
    });

    group('streak tracking', () {
      test('updateStreak starts streak on first activity', () {
        final progress = UserProgress(
          id: 'user-1',
          createdAt: testDate,
        );

        final updated = progress.updateStreak(now: testDate);

        expect(updated.currentStreak, 1);
        expect(updated.longestStreak, 1);
        expect(
          updated.lastActiveDate,
          DateTime(testDate.year, testDate.month, testDate.day),
        );
      });

      test('updateStreak increments for consecutive days', () {
        final day1 = DateTime(2025, 1, 15);
        final day2 = DateTime(2025, 1, 16);

        var progress = UserProgress(
          id: 'user-1',
          currentStreak: 1,
          longestStreak: 1,
          lastActiveDate: day1,
          createdAt: testDate,
        );

        progress = progress.updateStreak(now: day2);

        expect(progress.currentStreak, 2);
        expect(progress.longestStreak, 2);
      });

      test('updateStreak does not change for same day', () {
        final day1 = DateTime(2025, 1, 15, 10);
        final day1Later = DateTime(2025, 1, 15, 18);

        var progress = UserProgress(
          id: 'user-1',
          currentStreak: 5,
          longestStreak: 10,
          lastActiveDate: day1,
          createdAt: testDate,
        );

        progress = progress.updateStreak(now: day1Later);

        expect(progress.currentStreak, 5);
        expect(progress.longestStreak, 10);
      });

      test('updateStreak resets for missed day', () {
        final day1 = DateTime(2025, 1, 15);
        final day3 = DateTime(2025, 1, 17); // Skipped day 16

        var progress = UserProgress(
          id: 'user-1',
          currentStreak: 5,
          longestStreak: 10,
          lastActiveDate: day1,
          createdAt: testDate,
        );

        progress = progress.updateStreak(now: day3);

        expect(progress.currentStreak, 1);
        expect(progress.longestStreak, 10); // Longest unchanged
      });

      test('longestStreak updates when current exceeds it', () {
        final day1 = DateTime(2025, 1, 15);
        final day2 = DateTime(2025, 1, 16);

        var progress = UserProgress(
          id: 'user-1',
          currentStreak: 10,
          longestStreak: 10,
          lastActiveDate: day1,
          createdAt: testDate,
        );

        progress = progress.updateStreak(now: day2);

        expect(progress.currentStreak, 11);
        expect(progress.longestStreak, 11);
      });
    });

    group('achievements', () {
      test('addAchievement adds new achievement', () {
        final progress = UserProgress(
          id: 'user-1',
          createdAt: testDate,
        );

        final updated = progress.addAchievement(
          AchievementType.firstQuest,
          now: testDate,
        );

        expect(updated.achievements.length, 1);
        expect(updated.achievements.first.type, AchievementType.firstQuest);
        expect(updated.achievements.first.unlockedAt, testDate);
      });

      test('addAchievement does not duplicate', () {
        var progress = UserProgress(
          id: 'user-1',
          createdAt: testDate,
        );

        progress = progress.addAchievement(AchievementType.firstQuest);
        progress = progress.addAchievement(AchievementType.firstQuest);

        expect(progress.achievements.length, 1);
      });

      test('hasAchievement returns correct value', () {
        var progress = UserProgress(
          id: 'user-1',
          createdAt: testDate,
        );

        expect(progress.hasAchievement(AchievementType.firstQuest), isFalse);

        progress = progress.addAchievement(AchievementType.firstQuest);

        expect(progress.hasAchievement(AchievementType.firstQuest), isTrue);
        expect(progress.hasAchievement(AchievementType.questMaster), isFalse);
      });
    });

    group('JSON serialization', () {
      test('toJson() correctly serializes all fields', () {
        final progress = UserProgress(
          id: 'user-1',
          totalXp: 500,
          questsCompleted: 10,
          subQuestsCompleted: 25,
          focusSessionsCompleted: 15,
          totalFocusTime: const Duration(hours: 2, minutes: 30),
          currentStreak: 5,
          longestStreak: 10,
          lastActiveDate: testDate,
          achievements: [
            Achievement(
              type: AchievementType.firstQuest,
              unlockedAt: testDate,
            ),
          ],
          createdAt: testDate,
        );

        final json = progress.toJson();

        expect(json['id'], 'user-1');
        expect(json['totalXp'], 500);
        expect(json['questsCompleted'], 10);
        expect(json['totalFocusTimeSeconds'], 9000); // 2.5 hours
        expect(json['currentStreak'], 5);
        expect(json['achievements'], hasLength(1));
      });

      test('fromJson() correctly deserializes all fields', () {
        final json = {
          'id': 'user-2',
          'totalXp': 1000,
          'questsCompleted': 20,
          'subQuestsCompleted': 50,
          'focusSessionsCompleted': 30,
          'totalFocusTimeSeconds': 18000,
          'currentStreak': 7,
          'longestStreak': 14,
          'lastActiveDate': testDate.toIso8601String(),
          'achievements': [
            {
              'type': 'firstFocus',
              'unlockedAt': testDate.toIso8601String(),
            },
          ],
          'createdAt': testDate.toIso8601String(),
        };

        final progress = UserProgress.fromJson(json);

        expect(progress.id, 'user-2');
        expect(progress.totalXp, 1000);
        expect(progress.level, 4); // Calculated from XP
        expect(progress.totalFocusTime, const Duration(hours: 5));
        expect(progress.achievements.first.type, AchievementType.firstFocus);
      });

      test('round-trip serialization preserves data', () {
        final progress = UserProgress(
          id: 'user-1',
          totalXp: 750,
          questsCompleted: 15,
          currentStreak: 3,
          longestStreak: 7,
          lastActiveDate: testDate,
          achievements: [
            Achievement(type: AchievementType.weekStreak, unlockedAt: testDate),
          ],
          createdAt: testDate,
        );

        final json = progress.toJson();
        final restored = UserProgress.fromJson(json);

        expect(restored, progress);
      });
    });

    group('formattedTotalFocusTime', () {
      test('formats hours and minutes', () {
        final progress = UserProgress(
          id: 'user-1',
          totalFocusTime: const Duration(hours: 2, minutes: 30),
          createdAt: testDate,
        );

        expect(progress.formattedTotalFocusTime, '2h 30m');
      });

      test('formats minutes only', () {
        final progress = UserProgress(
          id: 'user-1',
          totalFocusTime: const Duration(minutes: 45),
          createdAt: testDate,
        );

        expect(progress.formattedTotalFocusTime, '45m');
      });
    });
  });

  group('Achievement', () {
    test('fromJson() and toJson() work correctly', () {
      final testDate = DateTime(2025, 1, 15);
      final achievement = Achievement(
        type: AchievementType.levelTen,
        unlockedAt: testDate,
      );

      final json = achievement.toJson();
      final restored = Achievement.fromJson(json);

      expect(restored.type, achievement.type);
      expect(restored.unlockedAt, achievement.unlockedAt);
    });
  });

  group('AchievementType', () {
    test('all types are defined', () {
      expect(AchievementType.values, hasLength(11));
      expect(AchievementType.firstQuest.name, 'firstQuest');
      expect(AchievementType.levelTwentyFive.name, 'levelTwentyFive');
    });
  });
}
