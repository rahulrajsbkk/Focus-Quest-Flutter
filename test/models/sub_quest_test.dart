import 'package:flutter_quest/models/sub_quest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubQuest', () {
    final testDate = DateTime(2025, 1, 15, 10, 30);

    group('duration validation', () {
      test('accepts duration of exactly 5 minutes', () {
        expect(
          () => SubQuest(
            id: 'sub-1',
            questId: 'quest-1',
            title: 'Max duration task',
            estimatedDuration: const Duration(minutes: 5),
            createdAt: testDate,
          ),
          returnsNormally,
        );
      });

      test('accepts duration less than 5 minutes', () {
        expect(
          () => SubQuest(
            id: 'sub-1',
            questId: 'quest-1',
            title: 'Short task',
            estimatedDuration: const Duration(minutes: 2, seconds: 30),
            createdAt: testDate,
          ),
          returnsNormally,
        );
      });

      test('rejects duration greater than 5 minutes', () {
        expect(
          () => SubQuest(
            id: 'sub-1',
            questId: 'quest-1',
            title: 'Too long task',
            estimatedDuration: const Duration(minutes: 6),
            createdAt: testDate,
          ),
          throwsA(isA<InvalidSubQuestDurationException>()),
        );
      });

      test('rejects duration of 10 minutes', () {
        expect(
          () => SubQuest(
            id: 'sub-1',
            questId: 'quest-1',
            title: 'Way too long',
            estimatedDuration: const Duration(minutes: 10),
            createdAt: testDate,
          ),
          throwsA(
            isA<InvalidSubQuestDurationException>().having(
              (e) => e.duration,
              'duration',
              const Duration(minutes: 10),
            ),
          ),
        );
      });

      test('copyWith rejects invalid duration', () {
        final subQuest = SubQuest(
          id: 'sub-1',
          questId: 'quest-1',
          title: 'Valid task',
          estimatedDuration: const Duration(minutes: 3),
          createdAt: testDate,
        );

        expect(
          () => subQuest.copyWith(
            estimatedDuration: const Duration(minutes: 7),
          ),
          throwsA(isA<InvalidSubQuestDurationException>()),
        );
      });
    });

    group('JSON serialization', () {
      test('toJson() correctly serializes all fields', () {
        final subQuest = SubQuest(
          id: 'sub-1',
          questId: 'quest-1',
          title: 'Test Sub Quest',
          description: 'A test sub-quest',
          status: SubQuestStatus.inProgress,
          estimatedDuration: const Duration(minutes: 3, seconds: 30),
          createdAt: testDate,
          order: 2,
        );

        final json = subQuest.toJson();

        expect(json['id'], 'sub-1');
        expect(json['questId'], 'quest-1');
        expect(json['title'], 'Test Sub Quest');
        expect(json['description'], 'A test sub-quest');
        expect(json['status'], 'inProgress');
        expect(json['estimatedDurationSeconds'], 210); // 3*60 + 30
        expect(json['createdAt'], testDate.toIso8601String());
        expect(json['order'], 2);
      });

      test('fromJson() correctly deserializes all fields', () {
        final json = {
          'id': 'sub-2',
          'questId': 'quest-1',
          'title': 'From JSON',
          'description': 'Deserialized',
          'status': 'completed',
          'estimatedDurationSeconds': 180, // 3 minutes
          'createdAt': testDate.toIso8601String(),
          'completedAt': testDate
              .add(const Duration(minutes: 3))
              .toIso8601String(),
          'order': 1,
        };

        final subQuest = SubQuest.fromJson(json);

        expect(subQuest.id, 'sub-2');
        expect(subQuest.questId, 'quest-1');
        expect(subQuest.title, 'From JSON');
        expect(subQuest.status, SubQuestStatus.completed);
        expect(subQuest.estimatedDuration, const Duration(minutes: 3));
        expect(subQuest.completedAt, testDate.add(const Duration(minutes: 3)));
        expect(subQuest.order, 1);
      });

      test('fromJson() rejects invalid duration', () {
        final json = {
          'id': 'sub-3',
          'questId': 'quest-1',
          'title': 'Invalid',
          'estimatedDurationSeconds': 600, // 10 minutes - too long!
          'createdAt': testDate.toIso8601String(),
        };

        expect(
          () => SubQuest.fromJson(json),
          throwsA(isA<InvalidSubQuestDurationException>()),
        );
      });

      test('round-trip serialization preserves data', () {
        final subQuest = SubQuest(
          id: 'sub-1',
          questId: 'quest-1',
          title: 'Round Trip',
          estimatedDuration: const Duration(minutes: 4),
          createdAt: testDate,
          order: 5,
        );

        final json = subQuest.toJson();
        final restored = SubQuest.fromJson(json);

        expect(restored, subQuest);
      });
    });

    group('formattedDuration', () {
      test('formats minutes only', () {
        final subQuest = SubQuest(
          id: 'sub-1',
          questId: 'quest-1',
          title: 'Test',
          estimatedDuration: const Duration(minutes: 3),
          createdAt: testDate,
        );

        expect(subQuest.formattedDuration, '3m');
      });

      test('formats seconds only', () {
        final subQuest = SubQuest(
          id: 'sub-1',
          questId: 'quest-1',
          title: 'Test',
          estimatedDuration: const Duration(seconds: 45),
          createdAt: testDate,
        );

        expect(subQuest.formattedDuration, '45s');
      });

      test('formats minutes and seconds', () {
        final subQuest = SubQuest(
          id: 'sub-1',
          questId: 'quest-1',
          title: 'Test',
          estimatedDuration: const Duration(minutes: 2, seconds: 30),
          createdAt: testDate,
        );

        expect(subQuest.formattedDuration, '2m 30s');
      });
    });

    group('computed properties', () {
      test('isActive returns correct values', () {
        final pending = SubQuest(
          id: 'sub-1',
          questId: 'quest-1',
          title: 'Test',
          estimatedDuration: const Duration(minutes: 1),
          createdAt: testDate,
        );

        final inProgress = pending.copyWith(status: SubQuestStatus.inProgress);
        final completed = pending.copyWith(status: SubQuestStatus.completed);

        expect(pending.isActive, isTrue);
        expect(inProgress.isActive, isTrue);
        expect(completed.isActive, isFalse);
      });

      test('isCompleted returns correct values', () {
        final subQuest = SubQuest(
          id: 'sub-1',
          questId: 'quest-1',
          title: 'Test',
          estimatedDuration: const Duration(minutes: 1),
          createdAt: testDate,
        );

        expect(subQuest.isCompleted, isFalse);
        expect(
          subQuest.copyWith(status: SubQuestStatus.completed).isCompleted,
          isTrue,
        );
      });
    });
  });

  group('InvalidSubQuestDurationException', () {
    test('toString() includes duration info', () {
      const exception = InvalidSubQuestDurationException(Duration(minutes: 10));
      final message = exception.toString();

      expect(message, contains('10 minutes'));
      expect(message, contains('5 minutes'));
    });
  });

  group('maxSubQuestDurationMinutes', () {
    test('is 5 minutes', () {
      expect(maxSubQuestDurationMinutes, 5);
    });
  });
}
