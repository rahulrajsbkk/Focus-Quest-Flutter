import 'package:flutter_quest/models/quest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Quest', () {
    final testDate = DateTime(2025, 1, 15, 10, 30);
    final testQuest = Quest(
      id: 'quest-1',
      title: 'Complete Flutter Project',
      createdAt: testDate,
      description: 'Build the Focus Quest app',
      energyLevel: EnergyLevel.high,
      category: QuestCategory.work,
      tags: const ['flutter', 'adhd'],
    );

    group('JSON serialization', () {
      test('toJson() correctly serializes all fields', () {
        final json = testQuest.toJson();

        expect(json['id'], 'quest-1');
        expect(json['title'], 'Complete Flutter Project');
        expect(json['description'], 'Build the Focus Quest app');
        expect(json['status'], 'pending');
        expect(json['energyLevel'], 'high');
        expect(json['category'], 'work');
        expect(json['repeatFrequency'], 'none');
        expect(json['repeatDays'], isEmpty);
        expect(json['createdAt'], testDate.toIso8601String());
        expect(json['tags'], ['flutter', 'adhd']);
        expect(json['updatedAt'], isNull);
        expect(json['completedAt'], isNull);
        expect(json['dueDate'], isNull);
        expect(json['completionCount'], 0);
      });

      test('toJson() serializes repeatDays correctly', () {
        final questWithDays = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: {Weekday.monday, Weekday.wednesday, Weekday.friday},
        );

        final json = questWithDays.toJson();

        expect(json['repeatDays'], containsAll([1, 3, 5]));
      });

      test('fromJson() correctly deserializes all fields', () {
        final json = {
          'id': 'quest-2',
          'title': 'Test Quest',
          'description': 'A test quest',
          'status': 'inProgress',
          'energyLevel': 'medium',
          'category': 'learning',
          'repeatFrequency': 'daily',
          'repeatDays': [1, 3, 5], // Mon, Wed, Fri
          'completionCount': 5,
          'lastCompletedAt': testDate.toIso8601String(),
          'createdAt': testDate.toIso8601String(),
          'updatedAt': testDate.add(const Duration(hours: 1)).toIso8601String(),
          'tags': ['test'],
        };

        final quest = Quest.fromJson(json);

        expect(quest.id, 'quest-2');
        expect(quest.title, 'Test Quest');
        expect(quest.description, 'A test quest');
        expect(quest.status, QuestStatus.inProgress);
        expect(quest.energyLevel, EnergyLevel.medium);
        expect(quest.category, QuestCategory.learning);
        expect(quest.repeatFrequency, RepeatFrequency.daily);
        expect(
          quest.repeatDays,
          {Weekday.monday, Weekday.wednesday, Weekday.friday},
        );
        expect(quest.completionCount, 5);
        expect(quest.lastCompletedAt, testDate);
        expect(quest.createdAt, testDate);
        expect(quest.updatedAt, testDate.add(const Duration(hours: 1)));
        expect(quest.tags, ['test']);
      });

      test('fromJson() handles missing optional fields', () {
        final json = {
          'id': 'quest-3',
          'title': 'Minimal Quest',
          'createdAt': testDate.toIso8601String(),
        };

        final quest = Quest.fromJson(json);

        expect(quest.id, 'quest-3');
        expect(quest.title, 'Minimal Quest');
        expect(quest.description, isNull);
        expect(quest.status, QuestStatus.pending);
        expect(quest.energyLevel, EnergyLevel.medium);
        expect(quest.category, QuestCategory.other);
        expect(quest.repeatFrequency, RepeatFrequency.none);
        expect(quest.repeatDays, isEmpty);
        expect(quest.completionCount, 0);
        expect(quest.tags, isEmpty);
      });

      test('round-trip serialization preserves data', () {
        final completedQuest = testQuest.copyWith(
          status: QuestStatus.completed,
          completedAt: testDate.add(const Duration(days: 1)),
          updatedAt: testDate.add(const Duration(days: 1)),
        );

        final json = completedQuest.toJson();
        final restored = Quest.fromJson(json);

        expect(restored, completedQuest);
      });

      test('round-trip with repeatDays preserves data', () {
        final dailyQuest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: {Weekday.tuesday, Weekday.thursday},
        );

        final json = dailyQuest.toJson();
        final restored = Quest.fromJson(json);

        expect(restored.repeatDays, dailyQuest.repeatDays);
      });
    });

    group('copyWith', () {
      test('creates copy with updated title', () {
        final updated = testQuest.copyWith(title: 'Updated Title');

        expect(updated.title, 'Updated Title');
        expect(updated.id, testQuest.id);
        expect(updated.description, testQuest.description);
      });

      test('creates copy with updated status', () {
        final updated = testQuest.copyWith(status: QuestStatus.completed);

        expect(updated.status, QuestStatus.completed);
        expect(updated.title, testQuest.title);
      });

      test('creates copy with updated category', () {
        final updated = testQuest.copyWith(category: QuestCategory.personal);

        expect(updated.category, QuestCategory.personal);
        expect(updated.title, testQuest.title);
      });

      test('creates copy with updated repeat frequency', () {
        final updated = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.weekly,
        );

        expect(updated.repeatFrequency, RepeatFrequency.weekly);
        expect(updated.isRepeating, isTrue);
      });

      test('creates copy with updated repeatDays', () {
        final updated = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: {Weekday.monday, Weekday.friday},
        );

        expect(updated.repeatDays, {Weekday.monday, Weekday.friday});
      });
    });

    group('computed properties', () {
      test('isActive returns true for pending quests', () {
        final pending = testQuest.copyWith(status: QuestStatus.pending);
        expect(pending.isActive, isTrue);
      });

      test('isActive returns true for in-progress quests', () {
        final inProgress = testQuest.copyWith(status: QuestStatus.inProgress);
        expect(inProgress.isActive, isTrue);
      });

      test('isActive returns false for completed quests', () {
        final completed = testQuest.copyWith(status: QuestStatus.completed);
        expect(completed.isActive, isFalse);
      });

      test('isCompleted returns true only for completed status', () {
        expect(
          testQuest.copyWith(status: QuestStatus.completed).isCompleted,
          isTrue,
        );
        expect(
          testQuest.copyWith(status: QuestStatus.pending).isCompleted,
          isFalse,
        );
        expect(
          testQuest.copyWith(status: QuestStatus.inProgress).isCompleted,
          isFalse,
        );
      });

      test('isRepeating returns correct value', () {
        expect(testQuest.isRepeating, isFalse);
        final daily = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
        );
        expect(daily.isRepeating, isTrue);
        final weekly = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.weekly,
        );
        expect(weekly.isRepeating, isTrue);
        final monthly = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.monthly,
        );
        expect(monthly.isRepeating, isTrue);
      });

      test('energyValue returns correct numeric value', () {
        expect(
          testQuest.copyWith(energyLevel: EnergyLevel.minimal).energyValue,
          1,
        );
        expect(
          testQuest.copyWith(energyLevel: EnergyLevel.low).energyValue,
          2,
        );
        expect(
          testQuest.copyWith(energyLevel: EnergyLevel.medium).energyValue,
          3,
        );
        expect(
          testQuest.copyWith(energyLevel: EnergyLevel.high).energyValue,
          4,
        );
        expect(
          testQuest.copyWith(energyLevel: EnergyLevel.intense).energyValue,
          5,
        );
      });
    });

    group('repeatDaysFormatted', () {
      test('returns "Every day" for empty set', () {
        final quest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: {},
        );
        expect(quest.repeatDaysFormatted, 'Every day');
      });

      test('returns "Every day" for all days', () {
        final quest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: Set.from(Weekday.values),
        );
        expect(quest.repeatDaysFormatted, 'Every day');
      });

      test('returns "Weekdays" for Mon-Fri', () {
        final quest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: {
            Weekday.monday,
            Weekday.tuesday,
            Weekday.wednesday,
            Weekday.thursday,
            Weekday.friday,
          },
        );
        expect(quest.repeatDaysFormatted, 'Weekdays');
      });

      test('returns "Weekends" for Sat-Sun', () {
        final quest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: {Weekday.saturday, Weekday.sunday},
        );
        expect(quest.repeatDaysFormatted, 'Weekends');
      });

      test('returns comma-separated short names for custom days', () {
        final quest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: {Weekday.monday, Weekday.wednesday, Weekday.friday},
        );
        expect(quest.repeatDaysFormatted, 'Mon, Wed, Fri');
      });
    });

    group('repeating quest logic', () {
      test('isDueForRepeat returns true when never completed', () {
        final dailyQuest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
        );

        expect(dailyQuest.isDueForRepeat, isTrue);
      });

      test('isDueForRepeat returns false for non-repeating quests', () {
        expect(testQuest.isDueForRepeat, isFalse);
      });

      test('daily quest is due after a day', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final dailyQuest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          lastCompletedAt: yesterday,
        );

        expect(dailyQuest.isDueForRepeat, isTrue);
      });

      test('daily quest is not due on same day', () {
        final today = DateTime.now();
        final dailyQuest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          lastCompletedAt: today,
        );

        expect(dailyQuest.isDueForRepeat, isFalse);
      });

      test('weekly quest is due after 7 days', () {
        final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
        final weeklyQuest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.weekly,
          lastCompletedAt: eightDaysAgo,
        );

        expect(weeklyQuest.isDueForRepeat, isTrue);
      });

      test('weekly quest is not due within 7 days', () {
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        final weeklyQuest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.weekly,
          lastCompletedAt: threeDaysAgo,
        );

        expect(weeklyQuest.isDueForRepeat, isFalse);
      });

      test('daily quest with specific days is not due on other days', () {
        // Create a quest that only repeats on a day that is NOT today
        final today = Weekday.today;
        final otherDays = Weekday.values.where((d) => d != today).toSet();

        final dailyQuest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: otherDays,
        );

        expect(dailyQuest.isScheduledForToday, isFalse);
        expect(dailyQuest.isDueForRepeat, isFalse);
      });

      test('daily quest with today selected is due', () {
        final today = Weekday.today;

        final dailyQuest = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: {today},
        );

        expect(dailyQuest.isScheduledForToday, isTrue);
        expect(dailyQuest.isDueForRepeat, isTrue);
      });
    });

    group('equality', () {
      test('equal quests are equal', () {
        final quest1 = Quest(
          id: 'same-id',
          title: 'Same Title',
          category: QuestCategory.work,
          createdAt: testDate,
        );
        final quest2 = Quest(
          id: 'same-id',
          title: 'Same Title',
          category: QuestCategory.work,
          createdAt: testDate,
        );

        expect(quest1, quest2);
        expect(quest1.hashCode, quest2.hashCode);
      });

      test('different quests are not equal', () {
        final quest1 = Quest(
          id: 'id-1',
          title: 'Title',
          createdAt: testDate,
        );
        final quest2 = Quest(
          id: 'id-2',
          title: 'Title',
          createdAt: testDate,
        );

        expect(quest1, isNot(quest2));
      });

      test('quests with different repeatDays are not equal', () {
        final quest1 = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: {Weekday.monday},
        );
        final quest2 = testQuest.copyWith(
          repeatFrequency: RepeatFrequency.daily,
          repeatDays: {Weekday.tuesday},
        );

        expect(quest1, isNot(quest2));
      });
    });
  });

  group('Weekday', () {
    test('all weekdays have correct values', () {
      expect(Weekday.monday.value, 1);
      expect(Weekday.tuesday.value, 2);
      expect(Weekday.wednesday.value, 3);
      expect(Weekday.thursday.value, 4);
      expect(Weekday.friday.value, 5);
      expect(Weekday.saturday.value, 6);
      expect(Weekday.sunday.value, 7);
    });

    test('fromValue returns correct weekday', () {
      expect(Weekday.fromValue(1), Weekday.monday);
      expect(Weekday.fromValue(7), Weekday.sunday);
    });

    test('shortName returns correct abbreviation', () {
      expect(Weekday.monday.shortName, 'Mon');
      expect(Weekday.wednesday.shortName, 'Wed');
      expect(Weekday.sunday.shortName, 'Sun');
    });

    test('fullName returns correct name', () {
      expect(Weekday.monday.fullName, 'Monday');
      expect(Weekday.friday.fullName, 'Friday');
    });

    test('today returns current weekday', () {
      final today = DateTime.now().weekday;
      expect(Weekday.today.value, today);
    });
  });

  group('QuestStatus', () {
    test('all statuses are correctly named', () {
      expect(QuestStatus.pending.name, 'pending');
      expect(QuestStatus.inProgress.name, 'inProgress');
      expect(QuestStatus.completed.name, 'completed');
      expect(QuestStatus.cancelled.name, 'cancelled');
    });
  });

  group('EnergyLevel', () {
    test('all energy levels are correctly named', () {
      expect(EnergyLevel.minimal.name, 'minimal');
      expect(EnergyLevel.low.name, 'low');
      expect(EnergyLevel.medium.name, 'medium');
      expect(EnergyLevel.high.name, 'high');
      expect(EnergyLevel.intense.name, 'intense');
    });

    test('energy level values are 1-5', () {
      expect(EnergyLevel.minimal.value, 1);
      expect(EnergyLevel.low.value, 2);
      expect(EnergyLevel.medium.value, 3);
      expect(EnergyLevel.high.value, 4);
      expect(EnergyLevel.intense.value, 5);
    });

    test('energy level labels are correct', () {
      expect(EnergyLevel.minimal.label, 'Minimal');
      expect(EnergyLevel.low.label, 'Low');
      expect(EnergyLevel.medium.label, 'Medium');
      expect(EnergyLevel.high.label, 'High');
      expect(EnergyLevel.intense.label, 'Intense');
    });
  });

  group('QuestCategory', () {
    test('all categories are correctly named', () {
      expect(QuestCategory.work.name, 'work');
      expect(QuestCategory.personal.name, 'personal');
      expect(QuestCategory.learning.name, 'learning');
      expect(QuestCategory.other.name, 'other');
    });

    test('category labels are correct', () {
      expect(QuestCategory.work.label, 'Work');
      expect(QuestCategory.personal.label, 'Personal');
      expect(QuestCategory.learning.label, 'Learning');
      expect(QuestCategory.other.label, 'Other');
    });
  });

  group('RepeatFrequency', () {
    test('all frequencies are correctly named', () {
      expect(RepeatFrequency.none.name, 'none');
      expect(RepeatFrequency.daily.name, 'daily');
      expect(RepeatFrequency.weekly.name, 'weekly');
      expect(RepeatFrequency.monthly.name, 'monthly');
    });

    test('frequency labels are correct', () {
      expect(RepeatFrequency.none.label, 'No repeat');
      expect(RepeatFrequency.daily.label, 'Daily');
      expect(RepeatFrequency.weekly.label, 'Weekly');
      expect(RepeatFrequency.monthly.label, 'Monthly');
    });
  });
}
