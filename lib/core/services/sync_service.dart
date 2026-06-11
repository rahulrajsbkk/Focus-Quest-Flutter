import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/firestore_service.dart';
import 'package:focus_quest/features/auth/providers/auth_provider.dart';
import 'package:focus_quest/features/journal/providers/journal_provider.dart';
import 'package:focus_quest/features/profile/providers/activity_stats_provider.dart';
import 'package:focus_quest/features/profile/providers/user_progress_provider.dart';
import 'package:focus_quest/features/tasks/providers/quest_provider.dart';
import 'package:focus_quest/features/timer/providers/focus_session_provider.dart';
import 'package:focus_quest/models/app_user.dart';
import 'package:focus_quest/models/focus_session.dart';
import 'package:focus_quest/models/journal_entry.dart';
import 'package:focus_quest/models/quest.dart';
import 'package:focus_quest/models/user_activity_event.dart';
import 'package:focus_quest/models/user_progress.dart';
import 'package:focus_quest/services/sembast_service.dart';
import 'package:sembast/sembast.dart';

/// Entity types tracked in the outbox / sync layer.
enum _SyncEntity { quest, focusSession, journalEntry, activityEvent }

extension on _SyncEntity {
  String get key {
    switch (this) {
      case _SyncEntity.quest:
        return 'quest';
      case _SyncEntity.focusSession:
        return 'session';
      case _SyncEntity.journalEntry:
        return 'journal';
      case _SyncEntity.activityEvent:
        return 'event';
    }
  }
}

class SyncService {
  SyncService(this._ref);

  final Ref _ref;
  final FirestoreService _firestore = FirestoreService();
  final SembastService _sembast = SembastService();

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  // Debouncer for userProgressProvider invalidation during incoming event
  // bursts (M6). 300ms collapses the typical backfill into one rebuild.
  Timer? _progressInvalidateDebounce;

  AppUser? get _currentUser => _ref.read(authProvider).value;
  bool get _isSyncEnabled => _currentUser?.isSyncEnabled ?? false;
  String? get _userId => _currentUser?.id;

  /// Starts listening to Firestore streams for real-time updates.
  /// Idempotent: calling twice stops the previous subscriptions first.
  void startRealTimeSync() {
    stopRealTimeSync();

    if (!_isSyncEnabled || _userId == null) return;
    debugPrint('Starting real-time sync for user: $_userId');

    _subscriptions
      ..add(
        _firestore.getQuestsStream(_userId!).listen(_handleIncomingQuests),
      )
      ..add(
        _firestore
            .getFocusSessionsStream(_userId!)
            .listen(_handleIncomingFocusSessions),
      )
      ..add(
        _firestore
            .getJournalEntriesStream(_userId!)
            .listen(_handleIncomingJournalEntries),
      )
      ..add(
        _firestore
            .getUserActivityEventsStream(_userId!)
            .listen(_handleIncomingUserActivityEvents),
      );
  }

  /// Stops all real-time sync subscriptions.
  void stopRealTimeSync() {
    if (_subscriptions.isNotEmpty) {
      debugPrint('Stopping real-time sync.');
      for (final sub in _subscriptions) {
        unawaited(sub.cancel());
      }
      _subscriptions.clear();
    }
    _progressInvalidateDebounce?.cancel();
    _progressInvalidateDebounce = null;
  }

  // MARK: - Per-entity write APIs (called by providers)

  Future<void> syncQuest(Quest quest) =>
      _enqueueAndTrySync(_SyncEntity.quest, quest.id, _OutboxOp.put);

  Future<void> syncDeleteQuest(String questId) =>
      _enqueueAndTrySync(_SyncEntity.quest, questId, _OutboxOp.delete);

  Future<void> syncFocusSession(FocusSession session) =>
      _enqueueAndTrySync(_SyncEntity.focusSession, session.id, _OutboxOp.put);

  Future<void> syncDeleteFocusSession(String sessionId) => _enqueueAndTrySync(
    _SyncEntity.focusSession,
    sessionId,
    _OutboxOp.delete,
  );

  Future<void> syncJournalEntry(JournalEntry entry) =>
      _enqueueAndTrySync(_SyncEntity.journalEntry, entry.id, _OutboxOp.put);

  Future<void> syncDeleteJournalEntry(String entryId) => _enqueueAndTrySync(
    _SyncEntity.journalEntry,
    entryId,
    _OutboxOp.delete,
  );

  Future<void> syncUserActivityEvent(UserActivityEvent event) =>
      _enqueueAndTrySync(_SyncEntity.activityEvent, event.id, _OutboxOp.put);

  /// Syncs user progress to Firestore if sync is enabled.
  /// User progress is event-sourced — this is a "snapshot" used by admin
  /// views only. We push it directly (no outbox) because it can always be
  /// recomputed from events on any client.
  Future<void> syncUserProgress(UserProgress progress) async {
    if (!_isSyncEnabled || _userId == null) return;
    try {
      await _firestore.saveUserProgress(_userId!, progress);
    } on Object catch (e) {
      debugPrint('Sync Error (User Progress): $e');
    }
  }

  /// Syncs the user profile/settings to Firestore.
  Future<void> syncUser(AppUser user) async {
    if (user.isGuest) return;
    try {
      await _firestore.saveUser(user);
    } on Object catch (e) {
      debugPrint('Sync Error (User): $e');
    }
  }

  // MARK: - Outbox

  /// Enqueues an operation in the outbox and immediately attempts to flush it.
  /// On failure, the outbox retains the entry for a later flush.
  Future<void> _enqueueAndTrySync(
    _SyncEntity entity,
    String entityId,
    _OutboxOp op,
  ) async {
    if (!_isSyncEnabled || _userId == null) return;
    final ownerUid = _userId!;
    final entryKey = _outboxKey(entity, entityId, op);
    final db = await _sembast.database;
    await _sembast.outbox.record(entryKey).put(db, {
      'type': entity.key,
      'id': entityId,
      'op': op.name,
      'ownerUid': ownerUid,
      'queuedAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    await _processOutboxEntry(entryKey, ownerUid: ownerUid);
  }

  /// Flushes the outbox by attempting every pending entry. Called on
  /// startup (via _bootstrapSync) and before full syncs.
  Future<void> flushOutbox() async {
    if (!_isSyncEnabled || _userId == null) return;
    final db = await _sembast.database;
    final records = await _sembast.outbox.find(db);
    if (records.isEmpty) return;
    debugPrint('Flushing outbox: ${records.length} pending entries');
    // Process in queuedAt order so put-then-delete sequences land correctly.
    records.sort((a, b) {
      final aTs = (a.value['queuedAt'] as String?) ?? '';
      final bTs = (b.value['queuedAt'] as String?) ?? '';
      return aTs.compareTo(bTs);
    });
    for (final r in records) {
      await _processOutboxEntry(r.key);
    }
  }

  Future<void> _processOutboxEntry(
    String entryKey, {
    String? ownerUid,
  }) async {
    if (!_isSyncEnabled || _userId == null) return;
    final db = await _sembast.database;
    final record = await _sembast.outbox.record(entryKey).get(db);
    if (record == null) return;

    final entryOwner = record['ownerUid'] as String?;
    // Defensive: an entry queued for a previous user should not be sent
    // to the now-active user's collection.
    if (entryOwner != null &&
        ownerUid != null &&
        entryOwner != ownerUid &&
        entryOwner != _userId) {
      debugPrint('Outbox entry $entryKey skipped (owner mismatch)');
      return;
    }
    if (entryOwner != null && entryOwner != _userId) {
      // Active user has changed since this entry was queued — drop it.
      await _sembast.outbox.record(entryKey).delete(db);
      return;
    }

    final type = (record['type'] as String?) ?? '';
    final id = (record['id'] as String?) ?? '';
    final op = (record['op'] as String?) ?? '';
    if (type.isEmpty || id.isEmpty || op.isEmpty) {
      await _sembast.outbox.record(entryKey).delete(db);
      return;
    }

    try {
      if (op == _OutboxOp.delete.name) {
        await _firestoreDelete(type, id);
      } else {
        final payload = await _readLocalPayload(type, id);
        if (payload == null) {
          // The local record was removed; nothing to send. Drop the entry.
          await _sembast.outbox.record(entryKey).delete(db);
          return;
        }
        await _firestorePut(type, payload);
      }
      await _sembast.outbox.record(entryKey).delete(db);
    } on Object catch (e) {
      // Bump attempts but retain entry for next flush.
      final attempts = (record['attempts'] as int? ?? 0) + 1;
      await _sembast.outbox.record(entryKey).update(db, {'attempts': attempts});
      debugPrint('Outbox $type/$id/$op failed (attempt $attempts): $e');
    }
  }

  String _outboxKey(_SyncEntity entity, String id, _OutboxOp op) =>
      '${entity.key}:$id:${op.name}';

  Future<Object?> _readLocalPayload(String type, String id) async {
    final db = await _sembast.database;
    switch (type) {
      case 'quest':
        return _sembast.quests.record(id).get(db);
      case 'session':
        return _sembast.focusSessions.record(id).get(db);
      case 'journal':
        return _sembast.journalEntries.record(id).get(db);
      case 'event':
        return _sembast.userActivityEvents.record(id).get(db);
    }
    return null;
  }

  Future<void> _firestorePut(String type, Object payload) async {
    final raw = Map<String, dynamic>.from(payload as Map);
    switch (type) {
      case 'quest':
        await _firestore.saveQuest(_userId!, Quest.fromJson(raw));
      case 'session':
        await _firestore.saveFocusSession(_userId!, FocusSession.fromJson(raw));
      case 'journal':
        await _firestore.saveJournalEntry(_userId!, JournalEntry.fromJson(raw));
      case 'event':
        await _firestore.saveUserActivityEvent(
          _userId!,
          UserActivityEvent.fromJson(raw),
        );
    }
  }

  Future<void> _firestoreDelete(String type, String id) async {
    switch (type) {
      case 'quest':
        await _firestore.deleteQuest(_userId!, id);
      case 'session':
        await _firestore.deleteFocusSession(_userId!, id);
      case 'journal':
        await _firestore.deleteJournalEntry(_userId!, id);
      case 'event':
        // Events are immutable in this app; deletes should be rare. If
        // needed, we can add deleteUserActivityEvent to FirestoreService.
        debugPrint('Outbox: delete of immutable event $id ignored.');
    }
  }

  // MARK: - Full Sync

  /// Performs a full two-way sync between local Sembast and Firestore.
  Future<void> performFullSync() async {
    if (!_isSyncEnabled || _userId == null) return;

    debugPrint('Starting full sync for user: $_userId');

    try {
      final db = await _sembast.database;

      // Always flush outbox FIRST so pending local edits/deletes don't get
      // overwritten by a remote-wins reconciliation step.
      await flushOutbox();

      await Future.wait([
        _safeRun(() => _syncQuests(db), 'Quests'),
        _safeRun(() => _syncFocusSessions(db), 'Focus Sessions'),
        _safeRun(() => _syncJournalEntries(db), 'Journal Entries'),
        _safeRun(() => _syncActivityEvents(db), 'Activity Events'),
      ]);

      debugPrint('Full sync completed successfully');
    } on Object catch (e) {
      debugPrint('Full sync failed: $e');
    }
  }

  Future<void> _safeRun(Future<void> Function() action, String label) async {
    try {
      await action();
    } on Object catch (e) {
      debugPrint('Sync Error ($label): $e');
    }
  }

  Future<void> _syncQuests(Database db) async {
    final remoteQuests = await _firestore.getQuests(_userId!);
    final localRecords = await _sembast.quests.find(db);
    final localQuests = localRecords
        .map((r) => Quest.fromJson(r.value))
        .toList();

    final localMap = {for (final q in localQuests) q.id: q};
    final remoteMap = {for (final q in remoteQuests) q.id: q};

    final allIds = {...localMap.keys, ...remoteMap.keys};

    for (final id in allIds) {
      try {
        final local = localMap[id];
        final remote = remoteMap[id];

        if (local != null && remote != null) {
          final winner = _pickWinner(
            localTs: local.updatedAt ?? local.createdAt,
            remoteTs: remote.updatedAt ?? remote.createdAt,
            localEqualsRemote: local == remote,
          );
          switch (winner) {
            case _Winner.remote:
              await _sembast.quests.record(id).put(db, remote.toJson());
            case _Winner.local:
              await _firestore.saveQuest(_userId!, local);
            case _Winner.tie:
              // Contents already match — nothing to do.
              break;
          }
        } else if (local != null) {
          await _firestore.saveQuest(_userId!, local);
        } else if (remote != null) {
          await _sembast.quests.record(id).put(db, remote.toJson());
        }
      } on Object catch (e) {
        debugPrint('Sync Error (Quest $id): $e');
      }
    }
  }

  Future<void> _syncFocusSessions(Database db) async {
    final remoteSessions = await _firestore.getFocusSessions(_userId!);
    final localRecords = await _sembast.focusSessions.find(db);
    final localSessions = localRecords
        .map((r) => FocusSession.fromJson(r.value))
        .toList();

    final localMap = {for (final s in localSessions) s.id: s};
    final remoteMap = {for (final s in remoteSessions) s.id: s};

    final allIds = {...localMap.keys, ...remoteMap.keys};

    for (final id in allIds) {
      try {
        final local = localMap[id];
        final remote = remoteMap[id];

        if (local != null && remote != null) {
          final winner = _pickWinner(
            localTs: local.updatedAt ?? local.startedAt,
            remoteTs: remote.updatedAt ?? remote.startedAt,
            localEqualsRemote: local == remote,
          );
          switch (winner) {
            case _Winner.remote:
              await _sembast.focusSessions.record(id).put(db, remote.toJson());
            case _Winner.local:
              await _firestore.saveFocusSession(_userId!, local);
            case _Winner.tie:
              break;
          }
        } else if (local != null) {
          await _firestore.saveFocusSession(_userId!, local);
        } else if (remote != null) {
          await _sembast.focusSessions.record(id).put(db, remote.toJson());
        }
      } on Object catch (e) {
        debugPrint('Sync Error (FocusSession $id): $e');
      }
    }
  }

  Future<void> _syncJournalEntries(Database db) async {
    final remoteEntries = await _firestore.getJournalEntries(_userId!);
    final localRecords = await _sembast.journalEntries.find(db);
    final localEntries = localRecords
        .map((r) => JournalEntry.fromJson(r.value))
        .toList();

    final localMap = {for (final e in localEntries) e.id: e};
    final remoteMap = {for (final e in remoteEntries) e.id: e};

    final allIds = {...localMap.keys, ...remoteMap.keys};

    for (final id in allIds) {
      try {
        final local = localMap[id];
        final remote = remoteMap[id];

        if (local != null && remote != null) {
          final winner = _pickWinner(
            localTs: local.updatedAt ?? local.createdAt,
            remoteTs: remote.updatedAt ?? remote.createdAt,
            localEqualsRemote: local == remote,
          );
          switch (winner) {
            case _Winner.remote:
              await _sembast.journalEntries.record(id).put(db, remote.toJson());
            case _Winner.local:
              await _firestore.saveJournalEntry(_userId!, local);
            case _Winner.tie:
              break;
          }
        } else if (local != null) {
          await _firestore.saveJournalEntry(_userId!, local);
        } else if (remote != null) {
          await _sembast.journalEntries.record(id).put(db, remote.toJson());
        }
      } on Object catch (e) {
        debugPrint('Sync Error (JournalEntry $id): $e');
      }
    }
  }

  Future<void> _syncActivityEvents(Database db) async {
    final remoteEvents = await _firestore.getUserActivityEvents(_userId!);
    final localRecords = await _sembast.userActivityEvents.find(db);
    final localEvents = localRecords
        .map((r) => UserActivityEvent.fromJson(r.value))
        .toList();

    final localMap = {for (final e in localEvents) e.id: e};
    final remoteMap = {for (final e in remoteEvents) e.id: e};

    final allIds = {...localMap.keys, ...remoteMap.keys};

    // Events are immutable appendices, so logic is simpler:
    // If it exists in one and not other -> copy it.
    for (final id in allIds) {
      try {
        final local = localMap[id];
        final remote = remoteMap[id];

        if (local == null && remote != null) {
          await _sembast.userActivityEvents.record(id).put(db, remote.toJson());
        } else if (local != null && remote == null) {
          await _firestore.saveUserActivityEvent(_userId!, local);
        }
        // If both exist, we assume they are identical (immutable)
      } on Object catch (e) {
        debugPrint('Sync Error (Event $id): $e');
      }
    }
  }

  // MARK: - Stream handlers

  /// Determines whether a local record can be safely deleted in response to
  /// it being missing from a remote snapshot. Records still in the outbox
  /// (pending upload) are treated as "not yet synced" and preserved.
  Future<bool> _isPendingInOutbox(_SyncEntity entity, String id) async {
    final db = await _sembast.database;
    final putKey = _outboxKey(entity, id, _OutboxOp.put);
    final delKey = _outboxKey(entity, id, _OutboxOp.delete);
    final hasPut = await _sembast.outbox.record(putKey).exists(db);
    final hasDel = await _sembast.outbox.record(delKey).exists(db);
    return hasPut || hasDel;
  }

  Future<void> _handleIncomingQuests(List<Quest> remoteQuests) async {
    debugPrint('Sync: Received ${remoteQuests.length} quests');
    final db = await _sembast.database;
    final remoteIds = {for (final q in remoteQuests) q.id};

    // C5: propagate cross-device deletes — drop local records that have
    // been previously synced (not pending in outbox) and no longer exist
    // remotely.
    final localRecords = await _sembast.quests.find(db);
    for (final r in localRecords) {
      if (!remoteIds.contains(r.key) &&
          !await _isPendingInOutbox(_SyncEntity.quest, r.key)) {
        await _sembast.quests.record(r.key).delete(db);
      }
    }

    for (final remote in remoteQuests) {
      final localRecord = await _sembast.quests.record(remote.id).get(db);
      if (localRecord == null) {
        await _sembast.quests.record(remote.id).put(db, remote.toJson());
        continue;
      }
      final local = Quest.fromJson(localRecord);
      final winner = _pickWinner(
        localTs: local.updatedAt ?? local.createdAt,
        remoteTs: remote.updatedAt ?? remote.createdAt,
        localEqualsRemote: local == remote,
      );
      if (winner == _Winner.remote) {
        await _sembast.quests.record(remote.id).put(db, remote.toJson());
      }
    }
    _ref.invalidate(questListProvider);
  }

  Future<void> _handleIncomingFocusSessions(
    List<FocusSession> remoteSessions,
  ) async {
    debugPrint('Sync: Received ${remoteSessions.length} sessions');
    final db = await _sembast.database;
    final remoteIds = {for (final s in remoteSessions) s.id};

    final localRecords = await _sembast.focusSessions.find(db);
    for (final r in localRecords) {
      if (!remoteIds.contains(r.key) &&
          !await _isPendingInOutbox(_SyncEntity.focusSession, r.key)) {
        await _sembast.focusSessions.record(r.key).delete(db);
      }
    }

    for (final remote in remoteSessions) {
      final localRecord = await _sembast.focusSessions
          .record(remote.id)
          .get(db);
      if (localRecord == null) {
        await _sembast.focusSessions.record(remote.id).put(db, remote.toJson());
        continue;
      }
      final local = FocusSession.fromJson(localRecord);
      final winner = _pickWinner(
        localTs: local.updatedAt ?? local.startedAt,
        remoteTs: remote.updatedAt ?? remote.startedAt,
        localEqualsRemote: local == remote,
      );
      if (winner == _Winner.remote) {
        await _sembast.focusSessions.record(remote.id).put(db, remote.toJson());
      }
    }
    _ref.invalidate(focusSessionProvider);
  }

  Future<void> _handleIncomingJournalEntries(
    List<JournalEntry> remoteEntries,
  ) async {
    debugPrint('Sync: Received ${remoteEntries.length} entries');
    final db = await _sembast.database;
    final remoteIds = {for (final e in remoteEntries) e.id};

    final localRecords = await _sembast.journalEntries.find(db);
    for (final r in localRecords) {
      if (!remoteIds.contains(r.key) &&
          !await _isPendingInOutbox(_SyncEntity.journalEntry, r.key)) {
        await _sembast.journalEntries.record(r.key).delete(db);
      }
    }

    for (final remote in remoteEntries) {
      final localRecord = await _sembast.journalEntries
          .record(remote.id)
          .get(db);
      if (localRecord == null) {
        await _sembast.journalEntries
            .record(remote.id)
            .put(db, remote.toJson());
        continue;
      }
      final local = JournalEntry.fromJson(localRecord);
      final winner = _pickWinner(
        localTs: local.updatedAt ?? local.createdAt,
        remoteTs: remote.updatedAt ?? remote.createdAt,
        localEqualsRemote: local == remote,
      );
      if (winner == _Winner.remote) {
        await _sembast.journalEntries
            .record(remote.id)
            .put(db, remote.toJson());
      }
    }
    _ref.invalidate(journalProvider);
  }

  Future<void> _handleIncomingUserActivityEvents(
    List<UserActivityEvent> remoteEvents,
  ) async {
    debugPrint('Sync: Received ${remoteEvents.length} events');
    final db = await _sembast.database;
    for (final remote in remoteEvents) {
      final localRecord = await _sembast.userActivityEvents
          .record(remote.id)
          .get(db);
      if (localRecord == null) {
        await _sembast.userActivityEvents
            .record(remote.id)
            .put(db, remote.toJson());
      }
      // Events are immutable, so no need to update if exists
    }
    // M6: debounce so a backfill burst doesn't trigger N rebuilds.
    _progressInvalidateDebounce?.cancel();
    _progressInvalidateDebounce = Timer(
      const Duration(milliseconds: 300),
      () {
        _ref
          ..invalidate(userProgressProvider)
          ..invalidate(activityHeatmapProvider);
      },
    );
  }

  // MARK: - Conflict resolution helper (H3)

  _Winner _pickWinner({
    required DateTime localTs,
    required DateTime remoteTs,
    required bool localEqualsRemote,
  }) {
    if (localTs.isBefore(remoteTs)) return _Winner.remote;
    if (localTs.isAfter(remoteTs)) return _Winner.local;
    // Equal timestamps: if contents already match this is a no-op tie;
    // otherwise prefer remote so every client converges deterministically.
    return localEqualsRemote ? _Winner.tie : _Winner.remote;
  }
}

enum _Winner { local, remote, tie }

enum _OutboxOp { put, delete }

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});
