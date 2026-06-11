// Basic smoke test for the FocusQuest app.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/main.dart';

class MockAndroidFlutterLocalNotificationsPlugin
    extends AndroidFlutterLocalNotificationsPlugin {
  @override
  Future<bool?> requestNotificationsPermission() async {
    return true;
  }
}

class MockMacOSFlutterLocalNotificationsPlugin
    extends MacOSFlutterLocalNotificationsPlugin {
  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool providesAppNotificationSettings = false,
  }) async {
    return true;
  }
}

class MockIOSFlutterLocalNotificationsPlugin
    extends IOSFlutterLocalNotificationsPlugin {
  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool carPlay = false,
    bool providesAppNotificationSettings = false,
  }) async {
    return true;
  }
}

void main() {
  setUp(() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      FlutterLocalNotificationsPlatform.instance =
          MockAndroidFlutterLocalNotificationsPlugin();
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      FlutterLocalNotificationsPlatform.instance =
          MockMacOSFlutterLocalNotificationsPlugin();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      FlutterLocalNotificationsPlatform.instance =
          MockIOSFlutterLocalNotificationsPlugin();
    }
  });

  testWidgets('FocusQuest app loads successfully', (tester) async {
    // Build our app wrapped in ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Just pump a single frame - don't wait for async operations to settle
    // because they may involve platform channels that aren't mocked
    await tester.pump();

    // Verify that the greeting is displayed
    expect(find.textContaining('Good'), findsOneWidget);

    // Verify that the default user name is displayed
    expect(find.text('Adventurer'), findsOneWidget);

    // Verify the FAB for creating new quests (with the add icon) is visible
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
