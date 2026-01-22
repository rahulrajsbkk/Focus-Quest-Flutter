import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  factory NotificationService() => _instance;
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();

  // Channel IDs
  static const String channelFocusRunning = 'focus_running_channel';
  static const String channelFocusTaskCompleted =
      'focus_task_completed_channel';
  static const String channelFocusTimerFinished =
      'focus_timer_finished_channel';
  static const String channelBreakTimerFinished =
      'break_timer_finished_channel';
  static const String channelSystemAlerts = 'system_alerts_channel';

  // Group IDs
  static const String groupTimer = 'timer_group';
  static const String groupSystem = 'system_group';

  Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // default icon
      [
        // 1. Focus Timer Running (Silent, Low Priority)
        NotificationChannel(
          channelGroupKey: groupTimer,
          channelKey: channelFocusRunning,
          channelName: 'Focus Timer Running',
          channelDescription:
              'Indicates that a focus session is currently active',
          defaultColor: const Color(0xFF9D50BB),
          ledColor: Colors.white,
          importance: NotificationImportance.Low, // No pop-up
          channelShowBadge: false,
          playSound: false,
          enableVibration: false,
          locked: true, // Persistent
          onlyAlertOnce: true,
        ),
        // 2. Focus Task Completed (Silent, for manual completion or status)
        NotificationChannel(
          channelGroupKey: groupTimer,
          channelKey: channelFocusTaskCompleted,
          channelName: 'Focus Task Completed',
          channelDescription:
              'Notifications when a focus task is marked complete',
          defaultColor: const Color(0xFF4CAF50),
          ledColor: Colors.green,
          importance: NotificationImportance.Default,
          channelShowBadge: true,
          playSound: false,
          enableVibration: false,
        ),
        // 3. Focus Timer Finished (Loud, High Priority)
        NotificationChannel(
          channelGroupKey: groupTimer,
          channelKey: channelFocusTimerFinished,
          channelName: 'Focus Timer Finished',
          channelDescription: 'Alerts when your focus session time is up',
          defaultColor: const Color(0xFF9D50BB),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          criticalAlerts: true,
        ),
        // 4. Break Timer Finished (Loud, High Priority)
        NotificationChannel(
          channelGroupKey: groupTimer,
          channelKey: channelBreakTimerFinished,
          channelName: 'Break Timer Finished',
          channelDescription: 'Alerts when your break time is over',
          defaultColor: const Color(0xFF2196F3),
          ledColor: Colors.blue,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          criticalAlerts: true,
        ),
        // 5. System Alerts (Standard)
        NotificationChannel(
          channelGroupKey: groupSystem,
          channelKey: channelSystemAlerts,
          channelName: 'System Alerts',
          channelDescription: 'General application alerts',
          defaultColor: Colors.amber,
          importance: NotificationImportance.Default,
          channelShowBadge: true,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: groupTimer,
          channelGroupName: 'Timer Notifications',
        ),
        NotificationChannelGroup(
          channelGroupKey: groupSystem,
          channelGroupName: 'System Notifications',
        ),
      ],
    );
  }

  Future<void> requestPermission() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  Future<void> showAlert({
    required String title,
    required String body,
    String? channelKey,
    DateTime? scheduleDate,
    int? id,
    Duration? chronometer,
    bool ongoing = false,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: channelKey ?? channelSystemAlerts,
        title: title,
        body: body,
        category: _getCategoryForChannel(channelKey),
        wakeUpScreen: true,
        fullScreenIntent: true,
        chronometer: chronometer,
        locked: ongoing,
        autoDismissible: !ongoing,
      ),
      schedule: scheduleDate != null
          ? NotificationCalendar.fromDate(
              date: scheduleDate,
              preciseAlarm: true,
              allowWhileIdle: true,
            )
          : null,
    );
  }

  NotificationCategory _getCategoryForChannel(String? channelKey) {
    if (channelKey == channelFocusTimerFinished ||
        channelKey == channelBreakTimerFinished) {
      return NotificationCategory.Alarm;
    }
    if (channelKey == channelFocusRunning) {
      return NotificationCategory.Service; // Ongoing service
    }
    return NotificationCategory.Status;
  }

  static const int focusAlertId = 999;

  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
}
