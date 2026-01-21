import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  factory NotificationService() => _instance;
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();

  Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // default icon
      [
        NotificationChannel(
          channelGroupKey: 'timer_group',
          channelKey: 'timer_channel',
          channelName: 'Timer Notifications',
          channelDescription: 'Notifications for focus and break timers',
          defaultColor: const Color(0xFF9D50BB),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          criticalAlerts: true,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'timer_group',
          channelGroupName: 'Timer Group',
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
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: channelKey ?? 'timer_channel',
        title: title,
        body: body,
        category: NotificationCategory.Alarm,
        wakeUpScreen: true,
        fullScreenIntent: true,
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

  static const int focusAlertId = 999;

  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
}
