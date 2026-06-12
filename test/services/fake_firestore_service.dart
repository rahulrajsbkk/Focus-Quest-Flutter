import 'dart:async';

import 'package:focus_quest/core/services/firestore_service.dart';
import 'package:focus_quest/models/app_user.dart';
import 'package:focus_quest/models/focus_session.dart';
import 'package:focus_quest/models/journal_entry.dart';
import 'package:focus_quest/models/quest.dart';
import 'package:focus_quest/models/user_activity_event.dart';
import 'package:focus_quest/models/user_progress.dart';

/// In-memory [FirestoreService] for sync tests: no Firebase app required,
/// no network. Streams are driven manually via the exposed controllers so
/// tests can emit cache/server snapshots and errors on demand.
class FakeFirestoreService extends FirestoreService {
  final Map<String, AppUser> users = {};
  final Map<String, Quest> quests = {};
  final Map<String, FocusSession> sessions = {};
  final Map<String, JournalEntry> journalEntries = {};
  final Map<String, UserActivityEvent> events = {};
  final Map<String, UserProgress> progress = {};

  /// When true every save/delete throws, simulating an offline device or a
  /// rejected write (e.g. permission-denied).
  bool failWrites = false;

  /// How many times the sessions stream was (re)requested — lets tests
  /// observe stream restarts.
  int sessionStreamRequests = 0;

  final questsController = StreamController<RemoteSnapshot<Quest>>.broadcast();
  final sessionsController =
      StreamController<RemoteSnapshot<FocusSession>>.broadcast();
  final journalController =
      StreamController<RemoteSnapshot<JournalEntry>>.broadcast();
  final eventsController =
      StreamController<RemoteSnapshot<UserActivityEvent>>.broadcast();

  void _checkWrite() {
    if (failWrites) {
      throw Exception('FakeFirestoreService: writes are disabled');
    }
  }

  // MARK: - Users

  @override
  Future<void> saveUser(AppUser user) async {
    if (user.isGuest) return;
    _checkWrite();
    users[user.id] = user;
  }

  @override
  Future<AppUser?> getUser(String userId) async => users[userId];

  // MARK: - Quests

  @override
  Future<void> saveQuest(String userId, Quest quest) async {
    _checkWrite();
    quests[quest.id] = quest;
  }

  @override
  Future<List<Quest>> getQuests(String userId) async => quests.values.toList();

  @override
  Stream<RemoteSnapshot<Quest>> getQuestsStream(String userId) =>
      questsController.stream;

  @override
  Future<void> deleteQuest(String userId, String questId) async {
    _checkWrite();
    quests.remove(questId);
  }

  // MARK: - Focus Sessions

  @override
  Future<void> saveFocusSession(String userId, FocusSession session) async {
    _checkWrite();
    sessions[session.id] = session;
  }

  @override
  Future<List<FocusSession>> getFocusSessions(String userId) async =>
      sessions.values.toList();

  @override
  Stream<RemoteSnapshot<FocusSession>> getFocusSessionsStream(String userId) {
    sessionStreamRequests++;
    return sessionsController.stream;
  }

  @override
  Future<void> deleteFocusSession(String userId, String sessionId) async {
    _checkWrite();
    sessions.remove(sessionId);
  }

  // MARK: - Journal Entries

  @override
  Future<void> saveJournalEntry(String userId, JournalEntry entry) async {
    _checkWrite();
    journalEntries[entry.id] = entry;
  }

  @override
  Future<List<JournalEntry>> getJournalEntries(String userId) async =>
      journalEntries.values.toList();

  @override
  Stream<RemoteSnapshot<JournalEntry>> getJournalEntriesStream(
    String userId,
  ) => journalController.stream;

  @override
  Future<void> deleteJournalEntry(String userId, String entryId) async {
    _checkWrite();
    journalEntries.remove(entryId);
  }

  // MARK: - User Progress

  @override
  Future<void> saveUserProgress(String userId, UserProgress value) async {
    _checkWrite();
    progress[userId] = value;
  }

  @override
  Future<UserProgress?> getUserProgress(String userId) async =>
      progress[userId];

  // MARK: - Activity Events

  @override
  Future<void> saveUserActivityEvent(
    String userId,
    UserActivityEvent event,
  ) async {
    _checkWrite();
    events[event.id] = event;
  }

  @override
  Future<List<UserActivityEvent>> getUserActivityEvents(
    String userId,
  ) async => events.values.toList();

  @override
  Stream<RemoteSnapshot<UserActivityEvent>> getUserActivityEventsStream(
    String userId,
  ) => eventsController.stream;

  Future<void> dispose() async {
    await questsController.close();
    await sessionsController.close();
    await journalController.close();
    await eventsController.close();
  }
}
