import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:focus_quest/models/app_user.dart';
import 'package:focus_quest/models/focus_session.dart';
import 'package:focus_quest/models/journal_entry.dart';
import 'package:focus_quest/models/quest.dart';
import 'package:focus_quest/models/user_activity_event.dart';
import 'package:focus_quest/models/user_progress.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // MARK: - User Profile & Settings

  Future<void> saveUser(AppUser user) async {
    if (user.isGuest) return;
    await _firestore
        .collection('users')
        .doc(user.id)
        .set(user.toJson(), SetOptions(merge: true));
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
        .set(quest.toJson());
  }

  Future<List<Quest>> getQuests(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('quests')
        .get();
    return snapshot.docs
        .map((doc) {
          try {
            return Quest.fromJson(doc.data());
          } on Exception catch (e) {
            debugPrint('Error parsing quest ${doc.id}: $e');
            return null;
          }
        })
        .whereType<Quest>()
        .toList();
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
        .set(session.toJson());
  }

  Future<List<FocusSession>> getFocusSessions(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('focus_sessions')
        .get();
    return snapshot.docs
        .map((doc) {
          try {
            return FocusSession.fromJson(doc.data());
          } on Exception catch (e) {
            debugPrint('Error parsing session ${doc.id}: $e');
            return null;
          }
        })
        .whereType<FocusSession>()
        .toList();
  }

  // MARK: - Journal Entries

  Future<void> saveJournalEntry(String userId, JournalEntry entry) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('journal_entries')
        .doc(entry.id)
        .set(entry.toJson());
  }

  Future<List<JournalEntry>> getJournalEntries(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('journal_entries')
        .get();
    return snapshot.docs
        .map((doc) {
          try {
            return JournalEntry.fromJson(doc.data());
          } on Exception catch (e) {
            debugPrint('Error parsing entry ${doc.id}: $e');
            return null;
          }
        })
        .whereType<JournalEntry>()
        .toList();
  }

  // MARK: - User Progress

  Future<void> saveUserProgress(String userId, UserProgress progress) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('progress')
        .doc('current')
        .set(progress.toJson());
  }

  Future<UserProgress?> getUserProgress(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('progress')
        .doc('current')
        .get();
    if (!doc.exists) return null;
    return UserProgress.fromJson(doc.data()!);
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
        .set(event.toJson());
  }

  Future<List<UserActivityEvent>> getUserActivityEvents(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('activity_events')
        .orderBy('occurredAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) {
          try {
            return UserActivityEvent.fromJson(doc.data());
          } on Exception catch (e) {
            debugPrint('Error parsing activity event ${doc.id}: $e');
            return null;
          }
        })
        .whereType<UserActivityEvent>()
        .toList();
  }
}
