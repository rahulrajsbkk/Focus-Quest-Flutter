import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/notification_service.dart';
import 'package:focus_quest/core/services/sync_service.dart';
import 'package:focus_quest/features/profile/providers/user_progress_provider.dart';
import 'package:focus_quest/models/focus_session.dart';
import 'package:focus_quest/models/quest.dart';
import 'package:focus_quest/services/sembast_service.dart';
import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Default pomodoro durations
class PomodoroDefaults {
  static const Duration focusDuration = Duration(minutes: 25);
  static const Duration shortBreakDuration = Duration(minutes: 5);
  static const Duration longBreakDuration = Duration(minutes: 15);
  static const int sessionsBeforeLongBreak = 4;
}

/// State for the focus/timer feature
class FocusState {
  const FocusState({
    this.currentSession,
    this.sessionHistory = const [],
    this.completedSessionsToday = 0,
    this.totalFocusTimeToday = Duration.zero,
    this.isLoading = false,
    this.error,
    this.selectedQuestId,
    this.selectedQuest,
    this.focusDuration = PomodoroDefaults.focusDuration,
    this.shortBreakDuration = PomodoroDefaults.shortBreakDuration,
    this.longBreakDuration = PomodoroDefaults.longBreakDuration,
    this.focusSessionsInCycle = 0,
    this.isPowerSaving = false,
    this.powerSavingInactivityThreshold = const Duration(seconds: 30),
    this.pauseOnBackground = false,
  });

  final FocusSession? currentSession;
  final List<FocusSession> sessionHistory;
  final int completedSessionsToday;
  final Duration totalFocusTimeToday;
  final bool isLoading;
  final String? error;
  final String? selectedQuestId;
  final Quest? selectedQuest;
  final Duration focusDuration;
  final Duration shortBreakDuration;
  final Duration longBreakDuration;
  final int focusSessionsInCycle;
  final bool isPowerSaving;
  final Duration powerSavingInactivityThreshold;
  final bool pauseOnBackground;

  bool get hasActiveSession =>
      currentSession != null &&
      (currentSession!.isActive || currentSession!.isPaused);

  bool get isTimerRunning => currentSession?.isActive ?? false;
  bool get isTimerPaused => currentSession?.isPaused ?? false;

  FocusState copyWith({
    FocusSession? currentSession,
    bool clearCurrentSession = false,
    List<FocusSession>? sessionHistory,
    int? completedSessionsToday,
    Duration? totalFocusTimeToday,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? selectedQuestId,
    bool clearSelectedQuestId = false,
    Quest? selectedQuest,
    bool clearSelectedQuest = false,
    Duration? focusDuration,
    Duration? shortBreakDuration,
    Duration? longBreakDuration,
    int? focusSessionsInCycle,
    bool? isPowerSaving,
    Duration? powerSavingInactivityThreshold,
    bool? pauseOnBackground,
  }) {
    return FocusState(
      currentSession: clearCurrentSession
          ? null
          : (currentSession ?? this.currentSession),
      sessionHistory: sessionHistory ?? this.sessionHistory,
      completedSessionsToday:
          completedSessionsToday ?? this.completedSessionsToday,
      totalFocusTimeToday: totalFocusTimeToday ?? this.totalFocusTimeToday,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedQuestId: clearSelectedQuestId
          ? null
          : (selectedQuestId ?? this.selectedQuestId),
      selectedQuest: clearSelectedQuest
          ? null
          : (selectedQuest ?? this.selectedQuest),
      focusDuration: focusDuration ?? this.focusDuration,
      shortBreakDuration: shortBreakDuration ?? this.shortBreakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      focusSessionsInCycle: focusSessionsInCycle ?? this.focusSessionsInCycle,
      isPowerSaving: isPowerSaving ?? this.isPowerSaving,
      powerSavingInactivityThreshold:
          powerSavingInactivityThreshold ?? this.powerSavingInactivityThreshold,
      pauseOnBackground: pauseOnBackground ?? this.pauseOnBackground,
    );
  }
}

/// Notifier for managing focus session state
class FocusSessionNotifier extends Notifier<FocusState>
    with WidgetsBindingObserver {
  // Settings keys
  static const String _kFocusDuration = 'focus_duration_pref';
  static const String _kShortBreakDuration = 'short_break_duration_pref';
  static const String _kLongBreakDuration = 'long_break_duration_pref';
  static const String _kPauseOnBackground = 'pause_on_background_pref';
  static const String _kPowerSavingThreshold = 'power_saving_threshold_pref';

  /// Update focus duration setting
  void setFocusDuration(Duration duration) {
    state = state.copyWith(focusDuration: duration);
    unawaited(_saveSettings());
  }

  /// Update short break duration setting
  void setShortBreakDuration(Duration duration) {
    state = state.copyWith(shortBreakDuration: duration);
    unawaited(_saveSettings());
  }

  /// Update long break duration setting
  void setLongBreakDuration(Duration duration) {
    state = state.copyWith(longBreakDuration: duration);
    unawaited(_saveSettings());
  }

  /// Update pause on background setting
  void setPauseOnBackground({required bool pause}) {
    state = state.copyWith(pauseOnBackground: pause);
    unawaited(_saveSettings());
  }

  /// Set power saving mode
  void setPowerSaving({required bool value}) {
    state = state.copyWith(isPowerSaving: value);
  }

  /// Set power saving inactivity threshold
  void setPowerSavingInactivityThreshold(Duration duration) {
    state = state.copyWith(powerSavingInactivityThreshold: duration);
    unawaited(_saveSettings());
  }

  @override
  FocusState build() {
    // Schedule loading of history after build
    unawaited(
      Future.microtask(() async {
        await _loadSettings();
        await _loadSessionHistory();
      }),
    );

    // Register as observer for lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Clean up when provider is disposed
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _stopTicking();
      _backgroundAlertTimer?.cancel();
    });

    return const FocusState();
  }

  final SembastService _db = SembastService();
  final Uuid _uuid = const Uuid();
  Timer? _tickTimer;
  Timer? _backgroundAlertTimer;
  bool _wasRunningBeforeBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_onBackground());
    } else if (state == AppLifecycleState.resumed) {
      _onForeground();
    }
  }

  Future<void> _onBackground() async {
    if (!state.isTimerRunning) {
      _wasRunningBeforeBackground = false;
      return;
    }

    final session = state.currentSession!;

    // Logic:
    // If it's a Focus session AND pauseOnBackground is true -> Pause
    // If it's a Break session -> DO NOT Pause (as per requirements "don't
    // pause break timer")
    // If it's a Focus session AND pauseOnBackground is false -> Keep running

    final shouldPause =
        session.type == FocusSessionType.focus && state.pauseOnBackground;

    if (shouldPause) {
      _wasRunningBeforeBackground = true;
      await pauseSession();

      // Schedule alert for inactive user
      _backgroundAlertTimer?.cancel();
      await NotificationService().showNotification(
        id: 999, // focusAlertId
        title: 'Focus Paused',
        body: "Your session is paused while you're away.",
      );
    } else {
      // Keep running (Background Timer)
      _wasRunningBeforeBackground = true;
      _stopTicking(); // Stop UI tick, rely on logic

      final endTime = DateTime.now().add(session.remainingDuration);
      final formattedTime =
          '${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}';

      final progress =
          (session.elapsedDuration.inSeconds /
                  session.plannedDuration.inSeconds *
                  100)
              .clamp(0, 100)
              .toInt();

      await NotificationService().showTimerNotification(
        title: session.type == FocusSessionType.focus
            ? 'Focus App Running'
            : 'Break Time',
        body: 'Session ends at $formattedTime',
        progress: progress,
        maxProgress: 100,
      );
    }
  }

  void _onForeground() {
    unawaited(
      NotificationService().cancelNotification(999),
    );

    if (_wasRunningBeforeBackground) {
      // If we paused it, we should resume it (or keep it paused? Usually
      // auto-resume is annoying if auto-paused, but if we auto-paused, the
      // user expects it to be paused.
      // Wait, if we AUTO-paused, we should probably let the user MANUALLY
      // resume or auto-resume.
      // Usually "pause on background" implies "don't count time while away".
      // If we simply unpause, we count the time? No, resume() calculates diff.

      // If we kept running (didn't pause), we just restart ticking.
      // If we DID pause, the state is isPaused=true. We shouldn't auto-resume
      // unless we want to.
      // The previous code had `unawaited(resumeSession())` for the
      // auto-pause case.
      // Let's stick to: If we kept running (didn't pause), start ticking.
      // If we paused, leaving it paused is safer, OR we can follow the
      // previous logic which resumed.
      // Previous logic: `unawaited(resumeSession());`
      // Let's assume if it auto-paused, it should auto-resume for seamlessness,
      // OR stay paused?
      // "pause focus on background" -> User doesn't want to lose time.
      // Upon returning, they probably want to resume.

      if (state.isTimerRunning && !state.isTimerPaused) {
        // Was running in background
        _startTicking();
        state = state.copyWith(); // Refresh UI
      } else if (state.isTimerPaused && state.pauseOnBackground) {
        // It was paused because of background setting.
        // Do we auto resume?
        // Let's auto-resume to match previous "Fixing Sync" behaviour if
        // that was the case?
        // Actually, let's just leave it paused so user has control, OR
        // auto-resume.
        // Let's restart ticking if it was running.
      }

      _wasRunningBeforeBackground = false;
    }
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      focusDuration: Duration(
        minutes:
            prefs.getInt(_kFocusDuration) ??
            PomodoroDefaults.focusDuration.inMinutes,
      ),
      shortBreakDuration: Duration(
        minutes:
            prefs.getInt(_kShortBreakDuration) ??
            PomodoroDefaults.shortBreakDuration.inMinutes,
      ),
      longBreakDuration: Duration(
        minutes:
            prefs.getInt(_kLongBreakDuration) ??
            PomodoroDefaults.longBreakDuration.inMinutes,
      ),
      pauseOnBackground: prefs.getBool(_kPauseOnBackground) ?? false,
      powerSavingInactivityThreshold: Duration(
        seconds: prefs.getInt(_kPowerSavingThreshold) ?? 30,
      ),
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFocusDuration, state.focusDuration.inMinutes);
    await prefs.setInt(
      _kShortBreakDuration,
      state.shortBreakDuration.inMinutes,
    );
    await prefs.setInt(
      _kLongBreakDuration,
      state.longBreakDuration.inMinutes,
    );
    await prefs.setBool(_kPauseOnBackground, state.pauseOnBackground);
    await prefs.setInt(
      _kPowerSavingThreshold,
      state.powerSavingInactivityThreshold.inSeconds,
    );
  }

  /// Load today's session history
  Future<void> _loadSessionHistory() async {
    try {
      state = state.copyWith(isLoading: true);

      final db = await _db.database;
      final records = await _db.focusSessions.find(db);

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final sessions =
          records
              .map(
                (RecordSnapshot<String, Map<String, Object?>> record) =>
                    FocusSession.fromJson(
                      Map<String, dynamic>.from(record.value),
                    ),
              )
              .toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

      final todaySessions = sessions
          .where(
            (s) =>
                s.startedAt.isAfter(todayStart) &&
                s.type == FocusSessionType.focus &&
                s.status == FocusSessionStatus.completed,
          )
          .toList();

      final completedToday = todaySessions.length;
      final totalTimeToday = todaySessions.fold<Duration>(
        Duration.zero,
        (total, session) => total + session.elapsedDuration,
      );

      // Check for active session that might have been interrupted
      final activeSession = sessions
          .where((s) => s.isActive || s.isPaused)
          .cast<FocusSession?>()
          .firstOrNull;

      state = state.copyWith(
        sessionHistory: sessions
            .where((s) => s.startedAt.isAfter(todayStart))
            .toList(),
        completedSessionsToday: completedToday,
        totalFocusTimeToday: totalTimeToday,
        currentSession: activeSession,
        isLoading: false,
        clearError: true,
      );

      if (activeSession != null) {
        _startTicking();
        if (activeSession.isActive) {
          unawaited(_scheduleSessionEndNotification());
        }
      }
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load sessions: $e',
      );
    }
  }

  /// Start a new focus session
  Future<void> startFocusSession({
    String? questId,
    Quest? quest,
    Duration? customDuration,
  }) async {
    if (state.hasActiveSession) {
      return; // Already have an active session
    }

    final session = FocusSession.start(
      id: _uuid.v4(),
      plannedDuration: customDuration ?? state.focusDuration,
      questId: questId ?? state.selectedQuestId,
    );

    try {
      final db = await _db.database;
      await _db.focusSessions.record(session.id).put(db, session.toJson());

      state = state.copyWith(
        currentSession: session,
        selectedQuestId: questId,
        selectedQuest: quest,
        clearError: true,
      );

      _startTicking();
      unawaited(_scheduleSessionEndNotification());
      // Sync to Firestore
      await ref.read(syncServiceProvider).syncFocusSession(session);
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to start session: $e');
    }
  }

  /// Start a break session
  Future<void> startBreakSession({bool isLongBreak = false}) async {
    if (state.hasActiveSession) {
      return;
    }

    final breakDuration = isLongBreak
        ? state.longBreakDuration
        : state.shortBreakDuration;
    final breakType = isLongBreak
        ? FocusSessionType.longBreak
        : FocusSessionType.shortBreak;

    final session = FocusSession.start(
      id: _uuid.v4(),
      plannedDuration: breakDuration,
      type: breakType,
    );

    try {
      final db = await _db.database;
      await _db.focusSessions.record(session.id).put(db, session.toJson());

      state = state.copyWith(
        currentSession: session,
        clearError: true,
      );

      _startTicking();
      unawaited(_scheduleSessionEndNotification());
      // Sync to Firestore
      await ref.read(syncServiceProvider).syncFocusSession(session);
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to start break: $e');
    }
  }

  /// Pause the current session
  Future<void> pauseSession() async {
    final session = state.currentSession;
    if (session == null || !session.isActive) return;

    // Check if pausing is allowed for breaks (never allowed based on user
    // request)
    if (session.type == FocusSessionType.shortBreak ||
        session.type == FocusSessionType.longBreak) {
      return;
    }

    final pausedSession = session.pause();

    try {
      final db = await _db.database;
      await _db.focusSessions
          .record(pausedSession.id)
          .put(db, pausedSession.toJson());

      state = state.copyWith(currentSession: pausedSession);
      _stopTicking();
      unawaited(NotificationService().cancelAllNotifications());

      // Sync to Firestore
      await ref.read(syncServiceProvider).syncFocusSession(pausedSession);
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to pause session: $e');
    }
  }

  /// Resume a paused session
  Future<void> resumeSession() async {
    final session = state.currentSession;
    if (session == null || !session.isPaused) return;

    final resumedSession = session.resume();

    try {
      final db = await _db.database;
      await _db.focusSessions
          .record(resumedSession.id)
          .put(db, resumedSession.toJson());

      state = state.copyWith(currentSession: resumedSession);
      _startTicking();
      unawaited(_scheduleSessionEndNotification());

      // Sync to Firestore
      await ref.read(syncServiceProvider).syncFocusSession(resumedSession);
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to resume session: $e');
    }
  }

  /// Complete the current session
  Future<void> completeSession({
    String? notes,
    bool isTimerFinished = false,
  }) async {
    final session = state.currentSession;
    if (session == null) return;

    final completedSession = session.complete(notes: notes);

    try {
      final db = await _db.database;
      await _db.focusSessions
          .record(completedSession.id)
          .put(db, completedSession.toJson());

      // Sync to Firestore
      await ref.read(syncServiceProvider).syncFocusSession(completedSession);

      // Update stats if it was a focus session
      var completedToday = state.completedSessionsToday;
      var totalTimeToday = state.totalFocusTimeToday;
      var focusSessionsInCycle = state.focusSessionsInCycle;

      if (completedSession.type == FocusSessionType.focus) {
        completedToday++;
        totalTimeToday += completedSession.elapsedDuration;
        focusSessionsInCycle++;

        // Update progress system ONLY if linked to a quest
        if (completedSession.questId != null) {
          unawaited(
            ref
                .read(userProgressProvider.notifier)
                .completeFocusSession(completedSession.elapsedDuration),
          );
        }
      } else {
        // Break completed, reset focusSessionsInCycle if it reached limit
        if (focusSessionsInCycle >= PomodoroDefaults.sessionsBeforeLongBreak) {
          focusSessionsInCycle = 0;
        }
      }

      state = state.copyWith(
        clearCurrentSession: true,
        sessionHistory: [completedSession, ...state.sessionHistory],
        completedSessionsToday: completedToday,
        totalFocusTimeToday: totalTimeToday,
        focusSessionsInCycle: focusSessionsInCycle,
      );

      _stopTicking();
      unawaited(NotificationService().cancelAllNotifications());

      // Show completion feedback/next steps
      if (completedSession.type == FocusSessionType.focus) {
        final needsLongBreak =
            focusSessionsInCycle >= PomodoroDefaults.sessionsBeforeLongBreak;
        unawaited(
          NotificationService().showNotification(
            title: 'Focus Session Complete!',
            body: needsLongBreak
                ? 'Time for a long break!'
                : 'Great job! Take a short break.',
          ),
        );
      } else if (isTimerFinished &&
          (completedSession.type == FocusSessionType.shortBreak ||
              completedSession.type == FocusSessionType.longBreak)) {
        unawaited(
          NotificationService().showNotification(
            title: 'Break Ended!',
            body: 'Time to get back to work!',
          ),
        );
      }
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to complete session: $e');
    }
  }

  /// Cancel/interrupt the current session
  Future<void> cancelSession() async {
    final session = state.currentSession;
    if (session == null) return;

    final interruptedSession = session.interrupt();

    try {
      final db = await _db.database;
      await _db.focusSessions
          .record(interruptedSession.id)
          .put(db, interruptedSession.toJson());

      // Sync to Firestore
      await ref.read(syncServiceProvider).syncFocusSession(interruptedSession);

      state = state.copyWith(
        clearCurrentSession: true,
        clearSelectedQuestId: true,
        clearSelectedQuest: true,
        sessionHistory: [interruptedSession, ...state.sessionHistory],
      );

      _stopTicking();
      unawaited(NotificationService().cancelAllNotifications());
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to cancel session: $e');
    }
  }

  /// Set the quest for the next focus session
  void selectQuest(Quest? quest) {
    state = state.copyWith(
      selectedQuestId: quest?.id,
      selectedQuest: quest,
      clearSelectedQuestId: quest == null,
      clearSelectedQuest: quest == null,
    );
  }

  /// Get time logged for a specific quest today
  Future<Duration> getTimeLoggedForQuest(String questId) async {
    final db = await _db.database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final finder = Finder(
      filter: Filter.and([
        Filter.equals('questId', questId),
        Filter.equals('status', FocusSessionStatus.completed.name),
        Filter.equals('type', FocusSessionType.focus.name),
        Filter.greaterThan('startedAt', todayStart.toIso8601String()),
      ]),
    );

    final records = await _db.focusSessions.find(db, finder: finder);
    final sessions = records.map(
      (r) => FocusSession.fromJson(Map<String, dynamic>.from(r.value)),
    );

    return sessions.fold<Duration>(
      Duration.zero,
      (total, session) => total + session.elapsedDuration,
    );
  }

  /// Get all sessions for a specific quest today
  Future<List<FocusSession>> getSessionsForQuest(String questId) async {
    final db = await _db.database;

    final finder = Finder(
      filter: Filter.equals('questId', questId),
      sortOrders: [SortOrder('startedAt', false)],
    );

    final records = await _db.focusSessions.find(db, finder: finder);
    return records
        .map((r) => FocusSession.fromJson(Map<String, dynamic>.from(r.value)))
        .toList();
  }

  Future<void> _scheduleSessionEndNotification() async {
    final session = state.currentSession;
    if (session == null || !session.isActive) return;

    final remaining = session.remainingDuration;
    if (remaining <= Duration.zero) return;

    final scheduleDate = DateTime.now().add(remaining);
    final isFocus = session.type == FocusSessionType.focus;

    await NotificationService().scheduleTimerFinished(
      title: isFocus ? 'Focus Session Complete!' : 'Break Ended!',
      body: isFocus
          ? 'Great job! You finished your focus session.'
          : 'Time to get back to work!',
      scheduleDate: scheduleDate,
    );
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Trigger a state update to refresh UI
      if (state.currentSession != null) {
        state = state.copyWith();

        if (state.currentSession!.remainingDuration == Duration.zero &&
            state.currentSession!.isActive) {
          unawaited(completeSession(isTimerFinished: true));
        }
      }
    });
  }

  void _stopTicking() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  @override
  bool updateShouldNotify(FocusState previous, FocusState next) => true;
}

/// Provider for focus session state
final focusSessionProvider = NotifierProvider<FocusSessionNotifier, FocusState>(
  FocusSessionNotifier.new,
);

/// Provider for getting time logged on a specific quest today
// ignore: specify_nonobvious_property_types
final questTimeLoggedProvider = FutureProvider.family<Duration, String>((
  ref,
  questId,
) async {
  final notifier = ref.watch(focusSessionProvider.notifier);
  return notifier.getTimeLoggedForQuest(questId);
});

/// Provider for getting all sessions for a specific quest today
// ignore: specify_nonobvious_property_types
final questSessionsProvider = FutureProvider.family<List<FocusSession>, String>(
  (ref, questId) async {
    final notifier = ref.watch(focusSessionProvider.notifier);
    return notifier.getSessionsForQuest(questId);
  },
);
