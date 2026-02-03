import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/models/user_activity_event.dart';
import 'package:focus_quest/services/sembast_service.dart';
import 'package:sembast/sembast.dart';

/// Provider for activity heatmap data.
/// Returns a map of DateTime to intensity value (count of activities).
final activityHeatmapProvider = FutureProvider<Map<DateTime, int>>((ref) async {
  final db = await SembastService().database;
  final store = SembastService().userActivityEvents;

  // Query all events sorted by date
  final finder = Finder(sortOrders: [SortOrder('occurredAt')]);
  final records = await store.find(db, finder: finder);

  final events = records.map((record) {
    return UserActivityEvent.fromJson(record.value);
  });

  final heatmapData = <DateTime, int>{};

  for (final event in events) {
    // Only count relevant activities for intensity
    if (event.type == UserActivityType.questCompleted ||
        event.type == UserActivityType.subQuestCompleted ||
        event.type == UserActivityType.focusSessionCompleted) {
      // Normalize to date (midnight)
      final date = DateTime(
        event.occurredAt.year,
        event.occurredAt.month,
        event.occurredAt.day,
      );

      // Increment count
      heatmapData[date] = (heatmapData[date] ?? 0) + 1;
    }
  }

  return heatmapData;
});
