import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/notification_service.dart';
import 'package:focus_quest/features/profile/providers/user_progress_provider.dart';
import 'package:focus_quest/models/focus_session.dart';
import 'package:focus_quest/models/quest.dart';
import 'package:focus_quest/services/sembast_service.dart';
import 'package:sembast/sembast.dart';
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
    );
  }
}

/// Notifier for managing focus session state
class FocusSessionNotifier extends Notifier<FocusState>
    with WidgetsBindingObserver {
  @override
  FocusState build() {
    // Schedule loading of history after build
    unawaited(Future.microtask(_loadSessionHistory));

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
    if (state.isTimerRunning &&
        state.currentSession?.type == FocusSessionType.focus) {
      _wasRunningBeforeBackground = true;
      // Pause the session ticking and save state
      // We await this to ensure old notifications are cancelled BEFORE
      // we schedule the new one
      await pauseSession();

      _backgroundAlertTimer?.cancel();

      // Schedule alarm for 2 mins from now
      await NotificationService().showAlert(
        id: NotificationService.focusAlertId,
        title: 'Focus Alert!',
        body: "You've been out of the app for 2 minutes. Stay focused!",
        // Ensure we add a small buffer or valid future time
        scheduleDate: DateTime.now().add(const Duration(minutes: 2)),
      );
    } else {
      _wasRunningBeforeBackground = false;
    }
  }

  void _onForeground() {
    _backgroundAlertTimer?.cancel();
    unawaited(
      NotificationService().cancelNotification(
        NotificationService.focusAlertId,
      ),
    );

    if (_wasRunningBeforeBackground) {
      unawaited(resumeSession());
      _wasRunningBeforeBackground = false;
    }
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
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to start break: $e');
    }
  }

  /// Pause the current session
  Future<void> pauseSession() async {
    final session = state.currentSession;
    if (session == null || !session.isActive) return;

    final pausedSession = session.pause();

    try {
      final db = await _db.database;
      await _db.focusSessions
          .record(pausedSession.id)
          .put(db, pausedSession.toJson());

      state = state.copyWith(currentSession: pausedSession);
      _stopTicking();
      unawaited(NotificationService().cancelAllNotifications());
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
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to resume session: $e');
    }
  }

  /// Complete the current session
  Future<void> completeSession({String? notes}) async {
    final session = state.currentSession;
    if (session == null) return;

    final completedSession = session.complete(notes: notes);

    try {
      final db = await _db.database;
      await _db.focusSessions
          .record(completedSession.id)
          .put(db, completedSession.toJson());

      // Update stats if it was a focus session
      var completedToday = state.completedSessionsToday;
      var totalTimeToday = state.totalFocusTimeToday;
      var focusSessionsInCycle = state.focusSessionsInCycle;

      if (completedSession.type == FocusSessionType.focus) {
        completedToday++;
        totalTimeToday += completedSession.elapsedDuration;
        focusSessionsInCycle++;

        // Update progress system
        unawaited(
          ref
              .read(userProgressProvider.notifier)
              .completeFocusSession(completedSession.elapsedDuration),
        );
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
          NotificationService().showAlert(
            title: 'Focus Session Complete!',
            body: needsLongBreak
                ? 'Time for a long break!'
                : 'Great job! Take a short break.',
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

  /// Update focus duration setting
  void setFocusDuration(Duration duration) {
    state = state.copyWith(focusDuration: duration);
  }

  /// Update short break duration setting
  void setShortBreakDuration(Duration duration) {
    state = state.copyWith(shortBreakDuration: duration);
  }

  /// Update long break duration setting
  void setLongBreakDuration(Duration duration) {
    state = state.copyWith(longBreakDuration: duration);
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
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final finder = Finder(
      filter: Filter.and([
        Filter.equals('questId', questId),
        Filter.greaterThan('startedAt', todayStart.toIso8601String()),
      ]),
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

    await NotificationService().showAlert(
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

        // Auto-complete when time is up
        if (state.currentSession!.remainingDuration == Duration.zero &&
            state.currentSession!.isActive) {
          final endedType = state.currentSession!.type;
          unawaited(completeSession());

          if (endedType == FocusSessionType.shortBreak) {
            unawaited(
              NotificationService().showAlert(
                title: 'Break Ended!',
                body: 'Time to get back to work!',
              ),
            );
          }
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
