import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:focus_quest/core/services/haptic_service.dart';
import 'package:focus_quest/core/theme/app_colors.dart';
import 'package:focus_quest/features/tasks/providers/quest_provider.dart';
import 'package:focus_quest/features/timer/providers/focus_session_provider.dart';
import 'package:focus_quest/features/timer/widgets/quest_selector.dart';
import 'package:focus_quest/features/timer/widgets/quest_time_log_widget.dart';
import 'package:focus_quest/features/timer/widgets/timer_controls.dart';
import 'package:focus_quest/features/timer/widgets/timer_display.dart';
import 'package:focus_quest/features/timer/widgets/timer_settings_sheet.dart';
import 'package:focus_quest/models/focus_session.dart';
import 'package:focus_quest/models/quest.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

/// Focus Timer screen with Pomodoro functionality
class FocusTimerScreen extends ConsumerStatefulWidget {
  const FocusTimerScreen({
    super.key,
    this.initialQuest,
  });

  /// Optional quest to start the timer with
  final Quest? initialQuest;

  @override
  ConsumerState<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends ConsumerState<FocusTimerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(
            vsync: this,
            duration: const Duration(seconds: 2),
          )
          // AnimationController.repeat() returns TickerFuture, safe to ignore.
          // ignore: discarded_futures
          ..repeat(reverse: true);

    // If initial quest provided, select it
    if (widget.initialQuest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(focusSessionProvider.notifier)
            .selectQuest(widget.initialQuest);
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTotalTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Color _getSessionTypeColor(FocusSessionType? type, ThemeData theme) {
    switch (type) {
      case FocusSessionType.focus:
        return theme.colorScheme.primary;
      case FocusSessionType.shortBreak:
        return AppColors.lightSecondary;
      case FocusSessionType.longBreak:
        return AppColors.lightAccent;
      case null:
        return theme.colorScheme.primary;
    }
  }

  String _getSessionTypeLabel(FocusSessionType? type) {
    switch (type) {
      case FocusSessionType.focus:
        return 'Focus Time';
      case FocusSessionType.shortBreak:
        return 'Short Break';
      case FocusSessionType.longBreak:
        return 'Long Break';
      case null:
        return 'Ready to Focus';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusState = ref.watch<FocusState>(focusSessionProvider);
    final questsState = ref.watch<AsyncValue<QuestListState>>(
      questListProvider,
    );

    ref.listen<FocusState>(
      focusSessionProvider,
      _checkSessionCompletion,
    );

    final currentSession = focusState.currentSession;
    final hasActiveSession = focusState.hasActiveSession;
    final sessionColor = _getSessionTypeColor(currentSession?.type, theme);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Focus Mode',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getSessionTypeLabel(currentSession?.type),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: sessionColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Settings button
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () => _showSettings(context),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ),
                ],
              ),
            ),

            // Today's stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Sessions',
                        value: '${focusState.completedSessionsToday}',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.schedule_rounded,
                        label: 'Focus Time',
                        value: _formatTotalTime(focusState.totalFocusTimeToday),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Quest selector
            if (!hasActiveSession)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: QuestSelector(
                  selectedQuest: focusState.selectedQuest,
                  quests: questsState.value?.allActiveQuests ?? [],
                  onQuestSelected: (quest) {
                    ref
                        .read<FocusSessionNotifier>(
                          focusSessionProvider.notifier,
                        )
                        .selectQuest(quest);
                  },
                ),
              ),

            // Selected quest indicator during session
            if (hasActiveSession && focusState.selectedQuest != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.flag_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          focusState.selectedQuest!.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      QuestTimeLogWidget(
                        questId: focusState.selectedQuest!.id,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),

            // Timer Display
            Expanded(
              child: Center(
                child: TimerDisplay(
                  session: currentSession,
                  isRunning: focusState.isTimerRunning,
                  isPaused: focusState.isTimerPaused,
                  focusDuration: focusState.focusDuration,
                  sessionColor: sessionColor,
                  pulseController: _pulseController,
                ),
              ),
            ),

            // Control Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 130),
              child: TimerControls(
                hasActiveSession: hasActiveSession,
                isRunning: focusState.isTimerRunning,
                isPaused: focusState.isTimerPaused,
                currentSession: currentSession,
                sessionColor: sessionColor,
                onStartFocus: () {
                  unawaited(HapticService().mediumImpact());
                  unawaited(
                    ref
                        .read<FocusSessionNotifier>(
                          focusSessionProvider.notifier,
                        )
                        .startFocusSession(
                          questId: focusState.selectedQuestId,
                          quest: focusState.selectedQuest,
                        ),
                  );
                },
                onStartShortBreak: () {
                  unawaited(HapticService().lightImpact());
                  unawaited(
                    ref
                        .read<FocusSessionNotifier>(
                          focusSessionProvider.notifier,
                        )
                        .startBreakSession(),
                  );
                },
                onStartLongBreak: () {
                  unawaited(HapticService().lightImpact());
                  unawaited(
                    ref
                        .read<FocusSessionNotifier>(
                          focusSessionProvider.notifier,
                        )
                        .startBreakSession(isLongBreak: true),
                  );
                },
                onPause: () {
                  unawaited(HapticService().lightImpact());
                  unawaited(
                    ref
                        .read<FocusSessionNotifier>(
                          focusSessionProvider.notifier,
                        )
                        .pauseSession(),
                  );
                },
                onResume: () {
                  unawaited(HapticService().lightImpact());
                  unawaited(
                    ref
                        .read<FocusSessionNotifier>(
                          focusSessionProvider.notifier,
                        )
                        .resumeSession(),
                  );
                },
                onComplete: () {
                  unawaited(HapticService().heavyImpact());
                  unawaited(
                    ref
                        .read<FocusSessionNotifier>(
                          focusSessionProvider.notifier,
                        )
                        .completeSession(),
                  );
                },
                onCancel: () {
                  unawaited(HapticService().mediumImpact());
                  _showCancelConfirmation(context);
                },
                onStartFocusLongPress: () => _showDurationPicker(
                  context,
                  'Focus Duration',
                  focusState.focusDuration,
                  (d) => ref
                      .read<FocusSessionNotifier>(focusSessionProvider.notifier)
                      .setFocusDuration(d),
                ),
                onStartShortBreakLongPress: () => _showDurationPicker(
                  context,
                  'Short Break Duration',
                  focusState.shortBreakDuration,
                  (d) => ref
                      .read<FocusSessionNotifier>(focusSessionProvider.notifier)
                      .setShortBreakDuration(d),
                ),
                onStartLongBreakLongPress: () => _showDurationPicker(
                  context,
                  'Long Break Duration',
                  focusState.longBreakDuration,
                  (d) => ref
                      .read<FocusSessionNotifier>(focusSessionProvider.notifier)
                      .setLongBreakDuration(d),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => const TimerSettingsSheet(),
      ),
    );
  }

  void _checkSessionCompletion(FocusState? previous, FocusState next) {
    if (previous?.currentSession == null) return;
    if (next.currentSession != null) return; // Still active or started new one

    // Session ended (currentSession became null)
    // Check if it was a COMPLETED FOCUS session
    if (next.sessionHistory.isEmpty) return;
    final lastSession = next.sessionHistory.first;

    if (lastSession.id == previous!.currentSession!.id &&
        lastSession.status == FocusSessionStatus.completed &&
        lastSession.type == FocusSessionType.focus) {
      // It was a completed focus session
      _showBreakPrompt(context);
    }
  }

  void _showDurationPicker(
    BuildContext context,
    String title,
    Duration currentDuration,
    ValueChanged<Duration> onChanged,
  ) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) {
          var selectedMinutes = currentDuration.inMinutes;
          // Clamp checks
          if (selectedMinutes < 1) selectedMinutes = 1;
          if (selectedMinutes > 120) selectedMinutes = 120;

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(title, textAlign: TextAlign.center),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    SleekCircularSlider(
                      initialValue: selectedMinutes.toDouble(),
                      min: 1,
                      max: 120,
                      appearance: CircularSliderAppearance(
                        size: 200,
                        startAngle: 180,
                        angleRange: 180,
                        customColors: CustomSliderColors(
                          trackColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          progressBarColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          dotColor: Theme.of(context).colorScheme.primary,
                          shadowColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        infoProperties: InfoProperties(
                          mainLabelStyle: Theme.of(
                            context,
                          ).textTheme.displayMedium,
                          modifier: (double value) {
                            return '${value.round()}m';
                          },
                        ),
                      ),
                      onChange: (double value) {
                        setState(() {
                          selectedMinutes = value.round();
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      onChanged(Duration(minutes: selectedMinutes));
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showBreakPrompt(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Great Focus!'),
          content: const Text(
            'You have completed your focus session. '
            'Would you like to take a 5-minute break?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                unawaited(
                  ref
                      .read<FocusSessionNotifier>(focusSessionProvider.notifier)
                      .startBreakSession(),
                );
              },
              child: const Text('Take 5m Break'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Session?'),
          content: const Text(
            'Are you sure you want to cancel this focus session? Your '
            'progress will be saved but the session will be marked as '
            'interrupted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Going'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                unawaited(
                  ref
                      .read<FocusSessionNotifier>(focusSessionProvider.notifier)
                      .cancelSession(),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Cancel Session'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
