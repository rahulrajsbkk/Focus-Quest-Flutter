import 'package:flutter/foundation.dart';
import 'package:focus_quest/core/database/database_helper.dart';
import 'package:sembast/sembast.dart';

/// Central Sembast database service with lazy initialization,
/// singleton pattern, and corruption recovery.
///
/// Provides access to all application stores for persistent data.
class SembastService {
  factory SembastService() => _instance;
  SembastService._();

  static final SembastService _instance = SembastService._();

  static const String _dbName = 'focus_quest.db';

  Database? _database;
  bool _isInitializing = false;

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

  /// Returns the database instance, initializing it lazily if needed.
  Future<Database> get database async {
    if (_database != null) return _database!;

    // Prevent multiple simultaneous initialization attempts
    if (_isInitializing) {
      // Wait for initialization to complete
      while (_isInitializing) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return _database!;
    }

    _isInitializing = true;
    try {
      _database = await _openDatabase();
      return _database!;
    } finally {
      _isInitializing = false;
    }
  }

  /// Opens the database using the platform-specific helper.
  Future<Database> _openDatabase() async {
    return openAppDatabase(_dbName);
  }

  /// Checks if the database has been initialized.
  bool get isInitialized => _database != null;

  /// Closes the database connection.
  ///
  /// Useful for testing or when the app is being destroyed.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Resets the database by deleting all data.
  ///
  /// This is a destructive operation - use with caution.
  Future<void> reset() async {
    // Close existing connection
    await close();

    // Delete the database using platform-specific helper
    await deleteAppDatabase(_dbName);

    // Database will be recreated on next access
    debugPrint('SembastService: Database reset complete.');
  }

  /// Gets the raw database reference for testing purposes.
  @visibleForTesting
  Database? get databaseForTesting => _database;

  /// Injects a database for testing purposes.
  @visibleForTesting
  set databaseForTesting(Database db) => _database = db;

  /// Clears the database reference for testing purposes.
  @visibleForTesting
  void clearForTesting() {
    _database = null;
  }
}
