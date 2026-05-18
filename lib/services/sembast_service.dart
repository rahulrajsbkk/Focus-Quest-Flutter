import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:focus_quest/core/database/database_helper.dart';
import 'package:sembast/sembast.dart';

/// Central Sembast database service with lazy, **per-user** initialization.
///
/// Each signed-in user (and each guest session) gets an isolated database
/// file (`focus_quest_<uid>.db`). Switching users closes/opens the correct
/// file so local data never leaks across accounts.
class SembastService {
  factory SembastService() => _instance;
  SembastService._();

  static final SembastService _instance = SembastService._();

  static const String _anonymousUid = '__anonymous__';
  static const String _dbPrefix = 'focus_quest';
  static const String _dbExtension = '.db';

  /// Store definitions
  final StoreRef<String, Map<String, Object?>> quests = stringMapStoreFactory
      .store('quests');

  final StoreRef<String, Map<String, Object?>> subQuests = stringMapStoreFactory
      .store('subQuests');

  final StoreRef<String, Map<String, Object?>> focusSessions =
      stringMapStoreFactory.store('focusSessions');

  final StoreRef<String, Map<String, Object?>> journalEntries =
      stringMapStoreFactory.store('journalEntries');

  final StoreRef<String, Map<String, Object?>> userProgress =
      stringMapStoreFactory.store('userProgress');

  final StoreRef<String, Map<String, Object?>> userActivityEvents =
      stringMapStoreFactory.store('userActivityEvents');

  /// Outbox of pending sync operations (retry queue for offline edits).
  final StoreRef<String, Map<String, Object?>> outbox = stringMapStoreFactory
      .store('outbox');

  /// Open databases keyed by uid. We keep them open across switches so
  /// switching back to a previous user is cheap.
  final Map<String, Database> _openDatabases = {};

  String _activeUid = _anonymousUid;
  Database? _testDatabase;
  Completer<Database>? _opening;

  /// Current active user id (or `__anonymous__` if signed out).
  String get activeUid => _activeUid;

  /// Switches the active user. The corresponding database is opened lazily
  /// on the next [database] access. No-op when [uid] matches the current one.
  Future<void> setActiveUser(String? uid) async {
    final newUid = (uid == null || uid.isEmpty) ? _anonymousUid : uid;
    if (newUid == _activeUid) return;
    debugPrint('SembastService: switching active user → $newUid');
    _activeUid = newUid;
  }

  /// Returns the database for the currently active user.
  Future<Database> get database async {
    if (_testDatabase != null) return _testDatabase!;

    final uid = _activeUid;
    final existing = _openDatabases[uid];
    if (existing != null) return existing;

    // Coalesce concurrent opens of the same db.
    if (_opening != null) return _opening!.future;
    final completer = Completer<Database>();
    _opening = completer;
    try {
      final db = await openAppDatabase(_fileNameFor(uid));
      _openDatabases[uid] = db;
      completer.complete(db);
      return db;
    } on Object catch (e, s) {
      completer.completeError(e, s);
      rethrow;
    } finally {
      _opening = null;
    }
  }

  String _fileNameFor(String uid) => '${_dbPrefix}_$uid$_dbExtension';

  /// Whether a database is currently open for the active user (or in tests).
  bool get isInitialized =>
      _testDatabase != null || _openDatabases.containsKey(_activeUid);

  /// Closes all open databases.
  Future<void> close() async {
    if (_testDatabase != null) {
      await _testDatabase!.close();
      _testDatabase = null;
      return;
    }
    for (final db in _openDatabases.values) {
      await db.close();
    }
    _openDatabases.clear();
  }

  /// Closes (and evicts) the database for the given uid.
  Future<void> closeUser(String? uid) async {
    final key = (uid == null || uid.isEmpty) ? _anonymousUid : uid;
    final db = _openDatabases.remove(key);
    await db?.close();
  }

  /// Deletes the active user's database file. Use on sign-out cleanup
  /// when the user's local data should not survive on this device.
  Future<void> reset() async {
    final uid = _activeUid;
    final db = _openDatabases.remove(uid);
    await db?.close();
    await deleteAppDatabase(_fileNameFor(uid));
    debugPrint('SembastService: database reset for $uid.');
  }

  @visibleForTesting
  Database? get databaseForTesting => _testDatabase;

  @visibleForTesting
  set databaseForTesting(Database? db) => _testDatabase = db;

  @visibleForTesting
  void clearForTesting() {
    _testDatabase = null;
    _openDatabases.clear();
    _activeUid = _anonymousUid;
  }
}
