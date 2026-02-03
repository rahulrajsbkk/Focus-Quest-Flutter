import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/features/profile/providers/activity_stats_provider.dart';
import 'package:focus_quest/features/profile/widgets/activity_heatmap.dart';
import 'package:home_widget/home_widget.dart';

/// Provider for the WidgetService
final Provider<WidgetService> widgetServiceProvider = Provider<WidgetService>(
  WidgetService.new,
);

/// Service to handle platform home screen widgets.
class WidgetService {
  WidgetService(this.ref);

  final Ref ref;

  static const String androidWidgetName = 'FocusQuestWidget';
  static const String iOSWidgetName = 'HeatmapWighetExtention';
  static const String groupId = 'group.com.rahulrajsbkk.focus_quest';

  /// Updates the home screen widget with the latest data.
  Future<void> updateWidget() async {
    try {
      // Fetch latest data
      final activityStatsProvider = ref.read(activityHeatmapProvider.future);

      final data = await activityStatsProvider;

      // Determine platform brightness for translucent background
      final brightness =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;
      final isDark = brightness == Brightness.dark;

      // Translucent background color based on theme
      final backgroundColor = isDark
          ? Colors.white.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.8);

      // Calculate centered date range for the widget
      // Target ~21 weeks to fit 340px width (approx 16px per week)
      // Center the current date
      final now = DateTime.now();
      final centerDate = DateTime(now.year, now.month, now.day);
      // 10 weeks back, 10 weeks forward = 21 weeks including current
      final startDate = centerDate.subtract(const Duration(days: 10 * 7));
      final endDate = centerDate.add(const Duration(days: 10 * 7));

      await HomeWidget.renderFlutterWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(340, 280),
            ),
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(overscroll: false),
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(12),
                child: FittedBox(
                  child: ActivityHeatmapView(
                    data: data,
                    startDate: startDate,
                    endDate: endDate,
                  ),
                ),
              ),
            ),
          ),
        ),
        key: 'activity_heatmap_image',
        logicalSize: const Size(340, 280),
        pixelRatio: 2,
      );

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
        qualifiedAndroidName: 'me.rahulrajsb.focus.FocusQuestWidgetProvider',
      );
    } on Object catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }
}
