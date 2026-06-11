import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:focus_quest/models/quest.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  factory NotificationService() => _instance;
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelIdTimer = 'focus_timer_channel';
  static const String channelNameTimer = 'Focus Timer';
  static const String channelDescTimer =
      'Shows the current focus timer progress';

  static const String channelIdFinished = 'focus_finished_channel';
  static const String channelNameFinished = 'Timer Finished';
  static const String channelDescFinished = 'Alerts when the timer completes';

  static const int notificationIdTimer = 1001;
  static const int notificationIdFinished = 1002;

  Future<void> initialize() async {
    // Local notifications and timezone lookups have no web implementation.
    // The plugin itself no-ops on web, but we return early to skip the
    // timezone setup work too and to document the platform boundary.
    if (kIsWeb) return;

    // ITimer initialization
    tz.initializeTimeZones();
    // Handling possible type mismatch if FlutterTimezone returns TimezoneInfo
    var timeZoneName = 'UTC';
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      timeZoneName = localTimezone.toString();

      // Fix for "TimezoneInfo(Asia/Calcutta, ...)" format
      if (timeZoneName.startsWith('TimezoneInfo(')) {
        final match = RegExp(
          r'TimezoneInfo\(([^,]+),',
        ).firstMatch(timeZoneName);
        if (match != null) {
          timeZoneName = match.group(1) ?? 'UTC';
        }
      }
    } on Exception {
      // Fallback to UTC if retrieval fails
      timeZoneName = 'UTC';
    }

    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } on Exception {
      // Fallback to UTC if basic retrieval still fails or ID is invalid
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/quest_icon',
    );

    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettingsLinux = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (notificationResponse) {
        // Handle notification tap
      },
    );
  }

  Future<void> requestPermission() async {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  /// Shows or updates a progress notification.
  /// Only Android supports the actual progress bar.
  /// iOS will simply show a standard notification with text updates.
  Future<void> showTimerNotification({
    required String title,
    required String body,
    required int progress, // 0 to 100
    required int maxProgress,
  }) async {
    if (kIsWeb) return;
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      channelIdTimer,
      channelNameTimer,
      channelDescription: channelDescTimer,
      importance: Importance.low, // vital for smooth progress updates
      priority: Priority.low,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      ongoing: true, // Prevent user from dismissing it easily
      autoCancel: false,
      onlyAlertOnce: true,
    );

    const darwinPlatformChannelSpecifics = DarwinNotificationDetails(
      presentSound: false, // Update silently
      presentBanner: true, // Needed to show banner
      presentList: true,
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics, // iOS updates might be throttled
      macOS: darwinPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id: notificationIdTimer,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> scheduleTimerFinished({
    required DateTime scheduleDate,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationIdFinished,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduleDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelIdFinished,
          channelNameFinished,
          channelDescription: channelDescFinished,
          importance: Importance.max,
          priority: Priority.high,
          playSound:
              true, // ignore: avoid_redundant_argument_values, explicit for clarity
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduleDate,
  }) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduleDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelIdFinished, // Reuse high priority channel
          channelNameFinished,
          channelDescription: channelDescFinished,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Shows a standard notification (no progress bar).
  Future<void> showNotification({
    required String title,
    required String body,
    int? id,
    bool ongoing = false,
  }) async {
    if (kIsWeb) return;
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      channelIdFinished, // Reusing high importance channel for alerts
      channelNameFinished,
      channelDescription: channelDescFinished,
      importance: Importance.max,
      priority: Priority.high,
      playSound:
          true, // ignore: avoid_redundant_argument_values, explicit for clarity
      ongoing: ongoing,
      autoCancel: !ongoing,
    );

    const darwinPlatformChannelSpecifics = DarwinNotificationDetails(
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id: id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> cancelTimerNotification() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancel(id: notificationIdTimer);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Schedules or updates an alarm reminder for a specific quest.
  /// Dynamically computes the next scheduled date that is in the future.
  Future<void> scheduleQuestAlarm(Quest quest) async {
    if (kIsWeb) return;
    final alarmTime = quest.reminderTime;
    if (alarmTime == null) {
      await cancelQuestAlarm(quest.id);
      return;
    }

    final parts = alarmTime.split(':');
    if (parts.length != 2) return;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final now = DateTime.now();

    // Find next scheduled date starting from today
    var targetDate = quest.getNextScheduledDate(now);
    if (targetDate == null) {
      await cancelQuestAlarm(quest.id);
      return;
    }

    var scheduleDateTime = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    );

    // If the scheduled time is in the past, search starting from tomorrow
    if (scheduleDateTime.isBefore(now)) {
      targetDate = quest.getNextScheduledDate(now.add(const Duration(days: 1)));
      if (targetDate == null) {
        await cancelQuestAlarm(quest.id);
        return;
      }
      scheduleDateTime = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        hour,
        minute,
      );
    }

    final id = quest.id.hashCode.abs().remainder(100000000);
    const title = 'Quest Reminder';
    final body = quest.description != null && quest.description!.isNotEmpty
        ? '${quest.title}\n${quest.description}'
        : quest.title;

    await scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduleDate: scheduleDateTime,
    );
  }

  /// Cancels any scheduled alarm reminder for a specific quest.
  Future<void> cancelQuestAlarm(String questId) async {
    if (kIsWeb) return;
    final id = questId.hashCode.abs().remainder(100000000);
    await cancelNotification(id);
  }
}
