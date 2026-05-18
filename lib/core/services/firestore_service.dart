import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:focus_quest/models/app_user.dart';
import 'package:focus_quest/models/focus_session.dart';
import 'package:focus_quest/models/journal_entry.dart';
import 'package:focus_quest/models/quest.dart';
import 'package:focus_quest/models/user_activity_event.dart';
import 'package:focus_quest/models/user_progress.dart';

/// Field used to carry a server-side timestamp alongside the client ISO
/// string in [Quest]/[FocusSession]/[JournalEntry] etc. Conflict resolution
/// in the sync layer prefers this value over the client-supplied `updatedAt`
/// because it removes client-clock skew from the equation.
const String _serverUpdatedAtField = '_serverUpdatedAt';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // MARK: - User Profile & Settings

  Future<void> saveUser(AppUser user) async {
    if (user.isGuest) return;
    try {
      await _firestore
          .collection('users')
          .doc(user.id)
          .set(_withServerTimestamp(user.toJson()), SetOptions(merge: true));
    } on Object catch (e) {
      debugPrint('Firestore.saveUser error: $e');
      rethrow;
    }
  }

  Future<AppUser?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return AppUser.fromJson(doc.data()!);
  }

  // MARK: - Quests

  Future<void> saveQuest(String userId, Quest quest) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('quests')
        .doc(quest.id)
        .set(_withServerTimestamp(quest.toJson()), SetOptions(merge: true));
  }

  Future<List<Quest>> getQuests(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('quests')
        .get();
    return snapshot.docs
        .map((doc) => _parseDoc(doc.id, doc.data(), Quest.fromJson, 'quest'))
        .whereType<Quest>()
        .toList();
  }

  Stream<List<Quest>> getQuestsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('quests')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _parseDoc(doc.id, doc.data(), Quest.fromJson, 'quest'),
              )
              .whereType<Quest>()
              .toList(),
        );
  }

  Future<void> deleteQuest(String userId, String questId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('quests')
        .doc(questId)
        .delete();
  }

  // MARK: - Focus Sessions

  Future<void> saveFocusSession(String userId, FocusSession session) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('focus_sessions')
        .doc(session.id)
        .set(_withServerTimestamp(session.toJson()), SetOptions(merge: true));
  }

  Future<void> deleteFocusSession(String userId, String sessionId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('focus_sessions')
        .doc(sessionId)
        .delete();
  }

  Future<List<FocusSession>> getFocusSessions(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('focus_sessions')
        .get();
    return snapshot.docs
        .map(
          (doc) =>
              _parseDoc(doc.id, doc.data(), FocusSession.fromJson, 'session'),
        )
        .whereType<FocusSession>()
        .toList();
  }

  Stream<List<FocusSession>> getFocusSessionsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('focus_sessions')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _parseDoc(
                  doc.id,
                  doc.data(),
                  FocusSession.fromJson,
                  'session',
                ),
              )
              .whereType<FocusSession>()
              .toList(),
        );
  }

  // MARK: - Journal Entries

  Future<void> saveJournalEntry(String userId, JournalEntry entry) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('journal_entries')
        .doc(entry.id)
        .set(_withServerTimestamp(entry.toJson()), SetOptions(merge: true));
  }

  Future<void> deleteJournalEntry(String userId, String entryId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('journal_entries')
        .doc(entryId)
        .delete();
  }

  Future<List<JournalEntry>> getJournalEntries(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('journal_entries')
        .get();
    return snapshot.docs
        .map(
          (doc) =>
              _parseDoc(doc.id, doc.data(), JournalEntry.fromJson, 'entry'),
        )
        .whereType<JournalEntry>()
        .toList();
  }

  Stream<List<JournalEntry>> getJournalEntriesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('journal_entries')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _parseDoc(
                  doc.id,
                  doc.data(),
                  JournalEntry.fromJson,
                  'entry',
                ),
              )
              .whereType<JournalEntry>()
              .toList(),
        );
  }

  // MARK: - User Progress

  Future<void> saveUserProgress(String userId, UserProgress progress) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('progress')
        .doc('current')
        .set(_withServerTimestamp(progress.toJson()), SetOptions(merge: true));
  }

  Future<UserProgress?> getUserProgress(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('progress')
        .doc('current')
        .get();
    if (!doc.exists) return null;
    return UserProgress.fromJson(_stripInternalFields(doc.data()!));
  }

  // MARK: - User Activity Events

  Future<void> saveUserActivityEvent(
    String userId,
    UserActivityEvent event,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('activity_events')
        .doc(event.id)
        .set(_withServerTimestamp(event.toJson()), SetOptions(merge: true));
  }

  Future<List<UserActivityEvent>> getUserActivityEvents(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('activity_events')
        .orderBy('occurredAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => _parseDoc(
            doc.id,
            doc.data(),
            UserActivityEvent.fromJson,
            'activity event',
          ),
        )
        .whereType<UserActivityEvent>()
        .toList();
  }

  Stream<List<UserActivityEvent>> getUserActivityEventsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('activity_events')
        .orderBy('occurredAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => _parseDoc(
                  doc.id,
                  doc.data(),
                  UserActivityEvent.fromJson,
                  'activity event',
                ),
              )
              .whereType<UserActivityEvent>()
              .toList(),
        );
  }

  // MARK: - Helpers

  /// Adds a Firestore server timestamp under [_serverUpdatedAtField]. This
  /// gives sync conflict resolution a clock that does not depend on the
  /// originating device.
  Map<String, dynamic> _withServerTimestamp(Map<String, dynamic> json) {
    return {
      ...json,
      _serverUpdatedAtField: FieldValue.serverTimestamp(),
    };
  }

  /// Promotes the server timestamp into the model's `updatedAt` field when
  /// it is more recent than the client-supplied one, and strips internal
  /// fields before deserialization.
  T? _parseDoc<T>(
    String docId,
    Map<String, dynamic>? raw,
    T Function(Map<String, dynamic>) fromJson,
    String label,
  ) {
    if (raw == null) return null;
    try {
      return fromJson(_stripInternalFields(raw));
    } on Object catch (e) {
      // L2: log to debug for now; production builds should pipe this into
      // Crashlytics/Sentry once an error reporter is wired up.
      debugPrint('Error parsing $label $docId: $e');
      return null;
    }
  }

  Map<String, dynamic> _stripInternalFields(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    final serverTs = data.remove(_serverUpdatedAtField);
    if (serverTs is Timestamp) {
      final serverIso = serverTs.toDate().toIso8601String();
      final clientUpdatedAt = data['updatedAt'] as String?;
      if (clientUpdatedAt == null ||
          clientUpdatedAt.compareTo(serverIso) < 0) {
        data['updatedAt'] = serverIso;
      }
    }
    return data;
  }
}
