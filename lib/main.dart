import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/notification_service.dart';
import 'package:focus_quest/core/services/widget_service.dart';
import 'package:focus_quest/core/theme/app_theme.dart';
import 'package:focus_quest/features/navigation/screens/main_screen.dart';
import 'package:focus_quest/features/profile/providers/activity_stats_provider.dart';
import 'package:focus_quest/firebase_options.dart';
import 'package:focus_quest/l10n/app_localizations.dart';
import 'package:focus_quest/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load();
  } on Exception catch (e) {
    debugPrint('Failed to load .env file: $e');
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Notification Service
  await NotificationService().initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'FocusQuest',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      home: const _WidgetUpdateWrapper(child: MainScreen()),
    );
  }
}

class _WidgetUpdateWrapper extends ConsumerWidget {
  const _WidgetUpdateWrapper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to activity stats changes to update home widget
    ref.listen(activityHeatmapProvider, (previous, next) {
      if (next.hasValue) {
        // Fire and forget widget update
        // ignore: discarded_futures
        ref.read(widgetServiceProvider).updateWidget().catchError((Object e) {
          debugPrint('Widget update failed: $e');
        });
      }
    });

    return child;
  }
}
