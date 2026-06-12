import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/core/services/sync_service.dart';
import 'package:focus_quest/models/app_user.dart';
import 'package:focus_quest/models/focus_session.dart';
import 'package:focus_quest/models/user_activity_event.dart';
import 'package:focus_quest/services/sembast_service.dart';
import 'package:sembast/sembast_memory.dart';

import 'fake_firestore_service.dart';

const _signedInUser = AppUser(
  id: 'user-1',
  displayName: 'Tester',
  photoUrl: '',
  isGuest: false,
  isSyncEnabled: true,
);

const _syncDisabledUser = AppUser(
  id: 'user-2',
  displayName: 'Opt Out',
  photoUrl: '',
  isGuest: false,
);

FocusSession _session(
  String id, {
  DateTime? updatedAt,
  String? notes,
}) {
  return FocusSession(
    id: id,
    type: FocusSessionType.focus,
    status: FocusSessionStatus.completed,
    plannedDuration: const Duration(minutes: 25),
    startedAt: DateTime(2026, 6, 1, 10),
    completedAt: DateTime(2026, 6, 1, 10, 25),
    notes: notes,
    updatedAt: updatedAt ?? DateTime(2026, 6, 1, 10, 25),
  );
}

UserActivityEvent _event(String id) {
  return UserActivityEvent(
    id: id,
    userId: _signedInUser.id,
    type: UserActivityType.focusSessionCompleted,
    xpEarned: 25,
    occurredAt: DateTime(2026, 6, 1, 10, 25),
    metadata: const {'durationSeconds': 1500},
  );
}

void main() {
  group('SyncService', () {
    late SembastService sembast;
    late FakeFirestoreService fake;
    late ProviderContainer container;
    late SyncService sync;
    var dbCounter = 0;

    setUp(() async {
      sembast = SembastService();
      final memoryDb = await databaseFactoryMemory.openDatabase(
        'sync-test-${dbCounter++}.db',
      );
      sembast.databaseForTesting = memoryDb;

      fake = FakeFirestoreService();
      container = ProviderContainer(
        overrides: [
          syncServiceProvider.overrideWith(
            (ref) => SyncService(ref, firestore: fake),
          ),
        ],
      );
      sync = container.read(syncServiceProvider);
    });

    tearDown(() async {
      sync.stopRealTimeSync();
      container.dispose();
      await sembast.close();
      sembast.clearForTesting();
      await fake.dispose();
    });

    group('guards', () {
      test('per-write sync no-ops when no user is set', () async {
        final db = await sembast.database;
        final session = _session('s1');
        await sembast.focusSessions.record('s1').put(db, session.toJson());

        await sync.syncFocusSession(session);

        expect(fake.sessions, isEmpty);
        expect(await sembast.outbox.find(db), isEmpty);
      });

      test('per-write sync no-ops when sync is disabled', () async {
        sync.user = _syncDisabledUser;
        final db = await sembast.database;
        final event = _event('e1');
        await sembast.userActivityEvents.record('e1').put(db, event.toJson());

        await sync.syncUserActivityEvent(event);

        expect(fake.events, isEmpty);
        expect(await sembast.outbox.find(db), isEmpty);
      });

      test('performFullSync no-ops without an enabled user', () async {
        fake.sessions['r1'] = _session('r1');

        await sync.performFullSync();

        final db = await sembast.database;
        expect(await sembast.focusSessions.record('r1').get(db), isNull);
      });
    });

    group('push', () {
      test('session and event reach Firestore and outbox drains', () async {
        sync.user = _signedInUser;
        final db = await sembast.database;
        final session = _session('s1');
        final event = _event('e1');
        await sembast.focusSessions.record('s1').put(db, session.toJson());
        await sembast.userActivityEvents.record('e1').put(db, event.toJson());

        await sync.syncFocusSession(session);
        await sync.syncUserActivityEvent(event);

        expect(fake.sessions['s1']?.id, 's1');
        expect(fake.events['e1']?.id, 'e1');
        expect(await sembast.outbox.find(db), isEmpty);
      });

      test('failed write stays in outbox and flushes later', () async {
        sync.user = _signedInUser;
        final db = await sembast.database;
        final session = _session('s1');
        await sembast.focusSessions.record('s1').put(db, session.toJson());

        fake.failWrites = true;
        await sync.syncFocusSession(session);

        expect(fake.sessions, isEmpty);
        final pending = await sembast.outbox.find(db);
        expect(pending, hasLength(1));
        expect(pending.first.value['attempts'], 1);

        fake.failWrites = false;
        await sync.flushOutbox();

        expect(fake.sessions['s1'], isNotNull);
        expect(await sembast.outbox.find(db), isEmpty);
      });
    });

    group('full sync', () {
      test('pulls remote-only sessions and events into Sembast', () async {
        sync.user = _signedInUser;
        fake.sessions['r1'] = _session('r1');
        fake.events['re1'] = _event('re1');

        await sync.performFullSync();

        final db = await sembast.database;
        final session = await sembast.focusSessions.record('r1').get(db);
        final event = await sembast.userActivityEvents.record('re1').get(db);
        expect(session, isNotNull);
        expect(FocusSession.fromJson(session!).id, 'r1');
        expect(event, isNotNull);
        expect(UserActivityEvent.fromJson(event!).id, 're1');
      });

      test('pushes local-only sessions and events to Firestore', () async {
        sync.user = _signedInUser;
        final db = await sembast.database;
        await sembast.focusSessions
            .record('l1')
            .put(db, _session('l1').toJson());
        await sembast.userActivityEvents
            .record('le1')
            .put(db, _event('le1').toJson());

        await sync.performFullSync();

        expect(fake.sessions['l1'], isNotNull);
        expect(fake.events['le1'], isNotNull);
      });

      test('newer remote session wins over older local', () async {
        sync.user = _signedInUser;
        final db = await sembast.database;
        await sembast.focusSessions
            .record('c1')
            .put(
              db,
              _session(
                'c1',
                updatedAt: DateTime(2026, 6, 1, 10),
                notes: 'local',
              ).toJson(),
            );
        fake.sessions['c1'] = _session(
          'c1',
          updatedAt: DateTime(2026, 6, 2, 10),
          notes: 'remote',
        );

        await sync.performFullSync();

        final stored = await sembast.focusSessions.record('c1').get(db);
        expect(FocusSession.fromJson(stored!).notes, 'remote');
      });

      test('newer local session wins over older remote', () async {
        sync.user = _signedInUser;
        final db = await sembast.database;
        await sembast.focusSessions
            .record('c2')
            .put(
              db,
              _session(
                'c2',
                updatedAt: DateTime(2026, 6, 3, 10),
                notes: 'local',
              ).toJson(),
            );
        fake.sessions['c2'] = _session(
          'c2',
          updatedAt: DateTime(2026, 6, 2, 10),
          notes: 'remote',
        );

        await sync.performFullSync();

        expect(fake.sessions['c2']?.notes, 'local');
      });
    });

    group('real-time streams', () {
      test('cache snapshots never delete local records', () async {
        sync.user = _signedInUser;
        final db = await sembast.database;
        await sembast.focusSessions
            .record('keep')
            .put(db, _session('keep').toJson());

        sync.startRealTimeSync();

        // An empty CACHE snapshot (cold Firestore cache) must not delete.
        fake.sessionsController.add((items: [], isFromCache: true));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(await sembast.focusSessions.record('keep').get(db), isNotNull);

        // The same snapshot confirmed by the SERVER propagates the delete.
        fake.sessionsController.add((items: [], isFromCache: false));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(await sembast.focusSessions.record('keep').get(db), isNull);
      });

      test('incoming server snapshot upserts sessions and events', () async {
        sync
          ..user = _signedInUser
          ..startRealTimeSync();

        fake
          ..sessionsController.add(
            (items: [_session('s9')], isFromCache: false),
          )
          ..eventsController.add((items: [_event('e9')], isFromCache: true));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final db = await sembast.database;
        expect(await sembast.focusSessions.record('s9').get(db), isNotNull);
        expect(
          await sembast.userActivityEvents.record('e9').get(db),
          isNotNull,
        );
      });

      test('stream errors are swallowed and do not crash', () async {
        sync
          ..user = _signedInUser
          ..startRealTimeSync();

        fake
          ..sessionsController.addError(Exception('permission-denied'))
          ..eventsController.addError(Exception('permission-denied'));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Reaching this point without an unhandled async error is the test.
        expect(sync.user, _signedInUser);
      });
    });
  });
}
