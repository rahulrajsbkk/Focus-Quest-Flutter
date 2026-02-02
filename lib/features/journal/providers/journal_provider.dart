import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/sync_service.dart';
import 'package:focus_quest/models/journal_entry.dart';
import 'package:focus_quest/services/sembast_service.dart';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

/// Repository for handling JournalEntry persistence.
class JournalRepository {
  final SembastService _sembastService = SembastService();
  final _uuid = const Uuid();

  /// Saves or updates a journal entry.
  Future<void> saveEntry(JournalEntry entry) async {
    final db = await _sembastService.database;
    await _sembastService.journalEntries
        .record(entry.id)
        .put(db, entry.toJson());
  }

  /// Retrieves all journal entries, sorted by date (newest first).
  Future<List<JournalEntry>> getEntries() async {
    final db = await _sembastService.database;
    final finder = Finder(sortOrders: [SortOrder('date', false)]);
    final records = await _sembastService.journalEntries.find(
      db,
      finder: finder,
    );

    return records.map((record) {
      return JournalEntry.fromJson(record.value);
    }).toList();
  }

  /// Retrieves an entry for a specific date (ignoring time).
  Future<JournalEntry?> getEntryForDate(DateTime date) async {
    final db = await _sembastService.database;

    // Create start and end of day range
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final finder = Finder(
      filter: Filter.and([
        Filter.greaterThanOrEquals('date', startOfDay.toIso8601String()),
        Filter.lessThanOrEquals('date', endOfDay.toIso8601String()),
      ]),
    );

    final record = await _sembastService.journalEntries.findFirst(
      db,
      finder: finder,
    );

    if (record != null) {
      return JournalEntry.fromJson(record.value);
    }
    return null;
  }

  /// Deletes a journal entry.
  Future<void> deleteEntry(String id) async {
    final db = await _sembastService.database;
    await _sembastService.journalEntries.record(id).delete(db);
  }

  String generateId() => _uuid.v4();
}

/// Provider for the JournalRepository.
final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository();
});

/// State notifier for the list of journal entries.
class JournalNotifier extends AsyncNotifier<List<JournalEntry>> {
  late JournalRepository _repository;

  @override
  Future<List<JournalEntry>> build() async {
    _repository = ref.watch(journalRepositoryProvider);
    return _repository.getEntries();
  }

  /// Adds a new entry.
  Future<void> addEntry(JournalEntry entry) async {
    // Optimistic update
    final previousState = state.asData?.value ?? [];
    state = AsyncData([entry, ...previousState]);

    try {
      await _repository.saveEntry(entry);
      // Sync to Firestore
      await ref.read(syncServiceProvider).syncJournalEntry(entry);
    } on Exception catch (e, stack) {
      state = AsyncError(e, stack);
      // Revert on error
      state = AsyncData(previousState);
    }
  }

  /// Updates an existing entry.
  Future<void> updateEntry(JournalEntry entry) async {
    final previousState = state.asData?.value ?? [];
    final newState = previousState
        .map((e) => e.id == entry.id ? entry : e)
        .toList();
    state = AsyncData(newState);

    try {
      await _repository.saveEntry(entry);
      // Sync to Firestore
      await ref.read(syncServiceProvider).syncJournalEntry(entry);
    } on Exception catch (e, stack) {
      state = AsyncError(e, stack);
      state = AsyncData(previousState);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.getEntries());
  }
}

/// Provider for the JournalNotifier.
final journalProvider =
    AsyncNotifierProvider<JournalNotifier, List<JournalEntry>>(
      JournalNotifier.new,
    );
