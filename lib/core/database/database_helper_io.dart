import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openDatabase(String dbName) async {
  final appDir = await getApplicationDocumentsDirectory();
  await appDir.create(recursive: true);
  final dbPath = join(appDir.path, dbName);

  try {
    return await databaseFactoryIo.openDatabase(dbPath);
  } on DatabaseException catch (e) {
    // Database might be corrupted, attempt recovery
    debugPrint('Database open failed, attempting recovery.');
    debugPrint('Error: $e');

    return _recoverDatabase(dbPath);
  }
}

Future<Database> _recoverDatabase(String dbPath) async {
  try {
    // Attempt to delete the corrupted database file
    final dbFile = File(dbPath);
    if (dbFile.existsSync()) {
      await dbFile.delete();
      debugPrint('Corrupted database deleted.');
    }

    // Create a fresh database
    final freshDb = await databaseFactoryIo.openDatabase(dbPath);
    debugPrint('Fresh database created after recovery.');
    return freshDb;
  } on Exception catch (recoveryError) {
    // If recovery fails, throw with context
    throw StateError(
      'Failed to recover database. '
      'Recovery error: $recoveryError',
    );
  }
}

Future<void> deleteAppDatabase(String dbName) async {
  final appDir = await getApplicationDocumentsDirectory();
  final dbPath = join(appDir.path, dbName);
  final dbFile = File(dbPath);
  if (dbFile.existsSync()) {
    await dbFile.delete();
  }
}
