import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

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

  /// Opens the database with corruption recovery.
  Future<Database> _openDatabase() async {
    final dbPath = await _getDatabasePath();

    try {
      return await databaseFactoryIo.openDatabase(dbPath);
    } on DatabaseException catch (e) {
      // Database might be corrupted, attempt recovery
      debugPrint('SembastService: Database open failed, attempting recovery.');
      debugPrint('Error: $e');

      return _recoverDatabase(dbPath);
    }
  }

  /// Recovers from a corrupted database by deleting and recreating it.
  Future<Database> _recoverDatabase(String dbPath) async {
    try {
      // Attempt to delete the corrupted database file
      final dbFile = File(dbPath);
      if (dbFile.existsSync()) {
        await dbFile.delete();
        debugPrint('SembastService: Corrupted database deleted.');
      }

      // Create a fresh database
      final freshDb = await databaseFactoryIo.openDatabase(dbPath);
      debugPrint('SembastService: Fresh database created after recovery.');
      return freshDb;
    } on Exception catch (recoveryError) {
      // If recovery fails, throw with context
      throw StateError(
        'SembastService: Failed to recover database. '
        'Recovery error: $recoveryError',
      );
    }
  }

  /// Gets the full path to the database file.
  Future<String> _getDatabasePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return join(appDir.path, _dbName);
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
    final dbPath = await _getDatabasePath();

    // Close existing connection
    await close();

    // Delete the database file
    final dbFile = File(dbPath);
    if (dbFile.existsSync()) {
      await dbFile.delete();
    }

    // Database will be recreated on next access
    debugPrint('SembastService: Database reset complete.');
  }

  /// Gets the database path for testing/debugging purposes.
  @visibleForTesting
  Future<String> getDatabasePathForTesting() => _getDatabasePath();

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
