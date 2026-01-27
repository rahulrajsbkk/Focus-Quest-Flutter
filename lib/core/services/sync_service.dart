import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/firestore_service.dart';
import 'package:focus_quest/features/auth/providers/auth_provider.dart';
import 'package:focus_quest/models/app_user.dart';
import 'package:focus_quest/models/focus_session.dart';
import 'package:focus_quest/models/journal_entry.dart';
import 'package:focus_quest/models/quest.dart';
import 'package:focus_quest/models/user_activity_event.dart';
import 'package:focus_quest/models/user_progress.dart';
import 'package:focus_quest/services/sembast_service.dart';
import 'package:sembast/sembast.dart';

class SyncService {
  SyncService(this._ref);

  final Ref _ref;
  final FirestoreService _firestore = FirestoreService();
  final SembastService _sembast = SembastService();

  AppUser? get _currentUser => _ref.read(authProvider).value;
  bool get _isSyncEnabled => _currentUser?.isSyncEnabled ?? false;
  String? get _userId => _currentUser?.id;

  /// Syncs a quest to Firestore if sync is enabled.
  Future<void> syncQuest(Quest quest) async {
    if (!_isSyncEnabled || _userId == null) return;
    try {
      await _firestore.saveQuest(_userId!, quest);
    } on Exception catch (e) {
      // For now, we just log errors. In a full implementation,
      // we'd use a queue.
      debugPrint('Sync Error (Quest): $e');
    }
  }

  /// Deletes a quest from Firestore if sync is enabled.
  Future<void> syncDeleteQuest(String questId) async {
    if (!_isSyncEnabled || _userId == null) return;
    try {
      await _firestore.deleteQuest(_userId!, questId);
    } on Exception catch (e) {
      debugPrint('Sync Error (Delete Quest): $e');
    }
  }

  /// Syncs a focus session to Firestore if sync is enabled.
  Future<void> syncFocusSession(FocusSession session) async {
    if (!_isSyncEnabled || _userId == null) return;
    try {
      await _firestore.saveFocusSession(_userId!, session);
    } on Exception catch (e) {
      debugPrint('Sync Error (Focus Session): $e');
    }
  }

  /// Syncs a journal entry to Firestore if sync is enabled.
  Future<void> syncJournalEntry(JournalEntry entry) async {
    if (!_isSyncEnabled || _userId == null) return;
    try {
      await _firestore.saveJournalEntry(_userId!, entry);
    } on Exception catch (e) {
      debugPrint('Sync Error (Journal Entry): $e');
    }
  }

  /// Syncs user progress to Firestore if sync is enabled.
  Future<void> syncUserProgress(UserProgress progress) async {
    if (!_isSyncEnabled || _userId == null) return;
    try {
      await _firestore.saveUserProgress(_userId!, progress);
    } on Exception catch (e) {
      debugPrint('Sync Error (User Progress): $e');
    }
  }

  /// Syncs the user profile/settings to Firestore.
  Future<void> syncUser(AppUser user) async {
    if (user.isGuest) return;
    try {
      await _firestore.saveUser(user);
    } on Exception catch (e) {
      debugPrint('Sync Error (User): $e');
    }
  }

  Future<void> syncUserActivityEvent(UserActivityEvent event) async {
    if (!_isSyncEnabled || _userId == null) return;
    try {
      await _firestore.saveUserActivityEvent(_userId!, event);
    } on Exception catch (e) {
      debugPrint('Sync Error (Activity Event): $e');
    }
  }

  /// Performs a full two-way sync between local Sembast and Firestore.
  Future<void> performFullSync() async {
    if (!_isSyncEnabled || _userId == null) return;

    debugPrint('Starting full sync for user: $_userId');

    try {
      final db = await _sembast.database;

      await Future.wait([
        _safeRun(() => _syncQuests(db), 'Quests'),
        _safeRun(() => _syncFocusSessions(db), 'Focus Sessions'),
        _safeRun(() => _syncJournalEntries(db), 'Journal Entries'),
        _safeRun(() => _syncActivityEvents(db), 'Activity Events'),
      ]);

      // Sync UserProgress LAST as it depends on events (conceptually)
      // For now, we only push the local state as a "backup/view" since it's derived from events
      await _safeRun(() => _syncUserProgress(db), 'User Progress');

      debugPrint('Full sync completed successfully');
    } on Exception catch (e) {
      debugPrint('Full sync failed: $e');
    }
  }

  Future<void> _safeRun(Future<void> Function() action, String label) async {
    try {
      await action();
    } on Exception catch (e) {
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
          if ((local.updatedAt ?? local.createdAt).isBefore(
            remote.updatedAt ?? remote.createdAt,
          )) {
            // Remote is newer
            await _sembast.quests.record(id).put(db, remote.toJson());
          } else if ((local.updatedAt ?? local.createdAt).isAfter(
            remote.updatedAt ?? remote.createdAt,
          )) {
            // Local is newer
            await _firestore.saveQuest(_userId!, local);
          }
        } else if (local != null) {
          // Only local exists
          await _firestore.saveQuest(_userId!, local);
        } else if (remote != null) {
          // Only remote exists
          await _sembast.quests.record(id).put(db, remote.toJson());
        }
      } on Exception catch (e) {
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
          if ((local.updatedAt ?? local.startedAt).isBefore(
            remote.updatedAt ?? remote.startedAt,
          )) {
            await _sembast.focusSessions.record(id).put(db, remote.toJson());
          } else if ((local.updatedAt ?? local.startedAt).isAfter(
            remote.updatedAt ?? remote.startedAt,
          )) {
            await _firestore.saveFocusSession(_userId!, local);
          }
        } else if (local != null) {
          await _firestore.saveFocusSession(_userId!, local);
        } else if (remote != null) {
          await _sembast.focusSessions.record(id).put(db, remote.toJson());
        }
      } on Exception catch (e) {
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
          if ((local.updatedAt ?? local.createdAt).isBefore(
            remote.updatedAt ?? remote.createdAt,
          )) {
            await _sembast.journalEntries.record(id).put(db, remote.toJson());
          } else if ((local.updatedAt ?? local.createdAt).isAfter(
            remote.updatedAt ?? remote.createdAt,
          )) {
            await _firestore.saveJournalEntry(_userId!, local);
          }
        } else if (local != null) {
          await _firestore.saveJournalEntry(_userId!, local);
        } else if (remote != null) {
          await _sembast.journalEntries.record(id).put(db, remote.toJson());
        }
      } on Exception catch (e) {
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
          // Missing locally -> Download
          await _sembast.userActivityEvents.record(id).put(db, remote.toJson());
          debugPrint('Synced Event (Down): $id');
        } else if (local != null && remote == null) {
          // Missing remotely -> Upload
          await _firestore.saveUserActivityEvent(_userId!, local);
          debugPrint('Synced Event (Up): $id');
        }
        // If both exist, we assume they are identical (immutable)
      } on Exception catch (e) {
        debugPrint('Sync Error (Event $id): $e');
      }
    }
  }

  Future<void> _syncUserProgress(Database db) async {
    const progressId = 'default_user'; // Matches UserProgressNotifier._userId
    final localRecord = await _sembast.userProgress.record(progressId).get(db);

    if (localRecord != null) {
      final localProgress = UserProgress.fromJson(localRecord);
      // We overwrite remote with local because local is the source of truth
      // derived from events. Ideally we might want to also allow downloading
      // progress if it's a fresh install BUT, since we just synced events,
      // the local app will rebuild progress from those events anyway.
      // So pushing local->remote is just for "viewing" purposes (admin, etc).
      await _firestore.saveUserProgress(_userId!, localProgress);
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});
