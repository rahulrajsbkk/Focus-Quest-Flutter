import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
    // ITimer initialization
    tz.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

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
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
            // Handle notification tap
          },
    );
  }

  Future<void> requestPermission() async {
    if (Platform.isIOS || Platform.isMacOS) {
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
    } else if (Platform.isAndroid) {
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
      notificationIdTimer,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> scheduleTimerFinished({
    required DateTime scheduleDate,
    required String title,
    required String body,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationIdFinished,
      title,
      body,
      tz.TZDateTime.from(scheduleDate, tz.local),
      const NotificationDetails(
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
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Shows a standard notification (no progress bar).
  Future<void> showNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      channelIdFinished, // Reusing high importance channel for alerts
      channelNameFinished,
      channelDescription: channelDescFinished,
      importance: Importance.max,
      priority: Priority.high,
      playSound:
          true, // ignore: avoid_redundant_argument_values, explicit for clarity
    );

    const darwinPlatformChannelSpecifics = DarwinNotificationDetails(
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelTimerNotification() async {
    await flutterLocalNotificationsPlugin.cancel(notificationIdTimer);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
