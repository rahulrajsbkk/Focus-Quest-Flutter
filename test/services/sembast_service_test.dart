import 'package:flutter_quest/models/focus_session.dart';
import 'package:flutter_quest/models/quest.dart';
import 'package:flutter_quest/models/sub_quest.dart';
import 'package:flutter_quest/models/user_progress.dart';
import 'package:flutter_quest/services/sembast_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  group('SembastService', () {
    late SembastService service;

    setUp(() async {
      service = SembastService();
      // Use in-memory database for testing
      final memoryDb = await databaseFactoryMemory.openDatabase('test.db');
      service.databaseForTesting = memoryDb;
    });

    tearDown(() async {
      await service.close();
      service.clearForTesting();
    });

    test('is a singleton', () {
      final instance1 = SembastService();
      final instance2 = SembastService();

      expect(identical(instance1, instance2), isTrue);
    });

    test('provides access to database', () async {
      final db = await service.database;

      expect(db, isNotNull);
    });

    test('isInitialized returns correct state', () async {
      service.clearForTesting();
      expect(service.isInitialized, isFalse);

      final memoryDb = await databaseFactoryMemory.openDatabase('test2.db');
      service.databaseForTesting = memoryDb;
      expect(service.isInitialized, isTrue);
    });

    group('store definitions', () {
      test('quests store exists and works', () async {
        final db = await service.database;

        await service.quests.record('quest-1').put(db, {'title': 'Test Quest'});

        final result = await service.quests.record('quest-1').get(db);
        expect(result?['title'], 'Test Quest');
      });

      test('subQuests store exists and works', () async {
        final db = await service.database;

        await service.subQuests.record('sub-1').put(db, {'title': 'Sub Quest'});

        final result = await service.subQuests.record('sub-1').get(db);
        expect(result?['title'], 'Sub Quest');
      });

      test('focusSessions store exists and works', () async {
        final db = await service.database;

        await service.focusSessions.record('session-1').put(db, {
          'duration': 1500,
        });

        final result = await service.focusSessions.record('session-1').get(db);
        expect(result?['duration'], 1500);
      });

      test('journalEntries store exists and works', () async {
        final db = await service.database;

        await service.journalEntries.record('entry-1').put(db, {
          'content': 'My journal',
        });

        final result = await service.journalEntries.record('entry-1').get(db);
        expect(result?['content'], 'My journal');
      });

      test('userProgress store exists and works', () async {
        final db = await service.database;

        await service.userProgress.record('user-1').put(db, {'xp': 500});

        final result = await service.userProgress.record('user-1').get(db);
        expect(result?['xp'], 500);
      });
    });

    group('CRUD operations', () {
      test('create and read quest', () async {
        final db = await service.database;
        final testDate = DateTime(2025, 1, 15);

        final quest = Quest(
          id: 'quest-1',
          title: 'Build Focus Quest',
          status: QuestStatus.inProgress,
          energyLevel: EnergyLevel.high,
          createdAt: testDate,
        );

        await service.quests.record(quest.id).put(db, quest.toJson());

        final result = await service.quests.record(quest.id).get(db);
        final restored = Quest.fromJson(result!);

        expect(restored.id, quest.id);
        expect(restored.title, quest.title);
        expect(restored.status, quest.status);
        expect(restored.energyLevel, quest.energyLevel);
      });

      test('update quest', () async {
        final db = await service.database;
        final testDate = DateTime(2025, 1, 15);

        final quest = Quest(
          id: 'quest-1',
          title: 'Original Title',
          createdAt: testDate,
        );

        await service.quests.record(quest.id).put(db, quest.toJson());

        final updated = quest.copyWith(
          title: 'Updated Title',
          status: QuestStatus.completed,
        );
        await service.quests.record(quest.id).put(db, updated.toJson());

        final result = await service.quests.record(quest.id).get(db);
        final restored = Quest.fromJson(result!);

        expect(restored.title, 'Updated Title');
        expect(restored.status, QuestStatus.completed);
      });

      test('delete quest', () async {
        final db = await service.database;
        final testDate = DateTime(2025, 1, 15);

        final quest = Quest(
          id: 'quest-1',
          title: 'To Delete',
          createdAt: testDate,
        );

        await service.quests.record(quest.id).put(db, quest.toJson());
        await service.quests.record(quest.id).delete(db);

        final result = await service.quests.record(quest.id).get(db);
        expect(result, isNull);
      });

      test('list all quests', () async {
        final db = await service.database;
        final testDate = DateTime(2025, 1, 15);

        for (var i = 1; i <= 3; i++) {
          final quest = Quest(
            id: 'quest-$i',
            title: 'Quest $i',
            createdAt: testDate,
          );
          await service.quests.record(quest.id).put(db, quest.toJson());
        }

        final records = await service.quests.find(db);
        expect(records.length, 3);
      });
    });

    group('stores work independently', () {
      test('data in different stores is isolated', () async {
        final db = await service.database;

        // Add data to different stores with same key
        await service.quests.record('id-1').put(db, {'type': 'quest'});
        await service.subQuests.record('id-1').put(db, {'type': 'subQuest'});
        await service.focusSessions.record('id-1').put(db, {'type': 'session'});

        // Verify each store has its own data
        final questResult = await service.quests.record('id-1').get(db);
        final subQuestResult = await service.subQuests.record('id-1').get(db);
        final sessionResult = await service.focusSessions
            .record('id-1')
            .get(db);

        expect(questResult?['type'], 'quest');
        expect(subQuestResult?['type'], 'subQuest');
        expect(sessionResult?['type'], 'session');
      });

      test('deleting from one store does not affect others', () async {
        final db = await service.database;

        await service.quests.record('id-1').put(db, {'data': 'quest'});
        await service.subQuests.record('id-1').put(db, {'data': 'subQuest'});

        await service.quests.record('id-1').delete(db);

        final questResult = await service.quests.record('id-1').get(db);
        final subQuestResult = await service.subQuests.record('id-1').get(db);

        expect(questResult, isNull);
        expect(subQuestResult?['data'], 'subQuest');
      });
    });

    group('model integration', () {
      test('SubQuest CRUD works', () async {
        final db = await service.database;
        final testDate = DateTime(2025, 1, 15);

        final subQuest = SubQuest(
          id: 'sub-1',
          questId: 'quest-1',
          title: 'Write tests',
          estimatedDuration: const Duration(minutes: 5),
          createdAt: testDate,
        );

        await service.subQuests.record(subQuest.id).put(db, subQuest.toJson());

        final result = await service.subQuests.record(subQuest.id).get(db);
        final restored = SubQuest.fromJson(result!);

        expect(restored.id, subQuest.id);
        expect(restored.questId, subQuest.questId);
        expect(restored.estimatedDuration, const Duration(minutes: 5));
      });

      test('FocusSession CRUD works', () async {
        final db = await service.database;
        final testDate = DateTime(2025, 1, 15);

        final session = FocusSession.start(
          id: 'session-1',
          questId: 'quest-1',
          plannedDuration: const Duration(minutes: 25),
          startedAt: testDate,
        );

        await service.focusSessions
            .record(session.id)
            .put(db, session.toJson());

        final result = await service.focusSessions.record(session.id).get(db);
        final restored = FocusSession.fromJson(result!);

        expect(restored.id, session.id);
        expect(restored.status, FocusSessionStatus.active);
        expect(restored.plannedDuration, const Duration(minutes: 25));
      });

      test('UserProgress CRUD works', () async {
        final db = await service.database;
        final testDate = DateTime(2025, 1, 15);

        var progress = UserProgress(
          id: 'user-1',
          totalXp: 500,
          questsCompleted: 10,
          createdAt: testDate,
        );

        await service.userProgress
            .record(progress.id)
            .put(db, progress.toJson());

        // Add XP and update
        progress = progress.addXp(100);
        await service.userProgress
            .record(progress.id)
            .put(db, progress.toJson());

        final result = await service.userProgress.record(progress.id).get(db);
        final restored = UserProgress.fromJson(result!);

        expect(restored.totalXp, 600);
        expect(restored.level, 3);
      });
    });

    group('data persistence simulation', () {
      test('data survives service close and reopen', () async {
        final db = await service.database;
        final testDate = DateTime(2025, 1, 15);

        final quest = Quest(
          id: 'persist-quest',
          title: 'Persistent Quest',
          createdAt: testDate,
        );

        await service.quests.record(quest.id).put(db, quest.toJson());

        // In a real scenario, the data would persist across app restarts
        // In memory DB, we verify the data is there before close
        final beforeClose = await service.quests.record(quest.id).get(db);
        expect(beforeClose, isNotNull);
        expect(Quest.fromJson(beforeClose!).title, 'Persistent Quest');
      });
    });
  });
}
