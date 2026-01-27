import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/features/timer/providers/focus_session_provider.dart';
import 'package:focus_quest/models/focus_session.dart';

/// Widget to display time logged for a specific quest
class QuestTimeLogWidget extends ConsumerWidget {
  const QuestTimeLogWidget({
    required this.questId,
    this.compact = false,
    super.key,
  });

  final String questId;
  final bool compact;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    }
    return '0m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeLogged = ref.watch(questTimeLoggedProvider(questId));
    final theme = Theme.of(context);

    return timeLogged.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (duration) {
        if (duration == Duration.zero) {
          return const SizedBox.shrink();
        }

        if (compact) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 12,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 3),
                Text(
                  _formatDuration(duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDuration(duration),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'logged',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Widget to display detailed session history for a quest
class QuestSessionHistoryWidget extends ConsumerWidget {
  const QuestSessionHistoryWidget({
    required this.questId,
    super.key,
  });

  final String questId;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  String _formatSessionDayOnly(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(date.year, date.month, date.day);

    if (sessionDay == today) {
      return 'Today';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (sessionDay == yesterday) {
      return 'Yesterday';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(FocusSessionStatus status, ThemeData theme) {
    switch (status) {
      case FocusSessionStatus.completed:
        return theme.colorScheme.primary;
      case FocusSessionStatus.interrupted:
        return theme.colorScheme.error;
      case FocusSessionStatus.active:
      case FocusSessionStatus.paused:
        return theme.colorScheme.secondary;
    }
  }

  IconData _getStatusIcon(FocusSessionStatus status) {
    switch (status) {
      case FocusSessionStatus.completed:
        return Icons.check_circle_outline_rounded;
      case FocusSessionStatus.interrupted:
        return Icons.cancel_outlined;
      case FocusSessionStatus.active:
        return Icons.play_circle_outline_rounded;
      case FocusSessionStatus.paused:
        return Icons.pause_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(questSessionsProvider(questId));
    final theme = Theme.of(context);

    return sessions.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $error'),
        ),
      ),
      data: (sessionList) {
        // Only show focus sessions
        final focusSessions = sessionList
            .where((s) => s.type == FocusSessionType.focus)
            .toList();

        if (focusSessions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_off_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No focus sessions yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a timer to track time on this quest',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Calculate total time and completed count
        final completedSessions = focusSessions
            .where((s) => s.status == FocusSessionStatus.completed)
            .toList();
        final totalTime = completedSessions.fold<Duration>(
          Duration.zero,
          (total, session) => total + session.elapsedDuration,
        );
        final completedCount = completedSessions.length;

        // Group sessions by day
        final groupedByDay = <String, List<FocusSession>>{};
        for (final session in focusSessions) {
          final s = session.startedAt;
          final dateKey = '${s.year}-${s.month}-${s.day}';
          groupedByDay.putIfAbsent(dateKey, () => []).add(session);
        }

        final sortedDayKeys = groupedByDay.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Focus Time',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(totalTime),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$completedCount sessions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Session list
            Text(
              'Session History',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            ...sortedDayKeys.take(7).map((dayKey) {
              final daySessions = groupedByDay[dayKey]!;
              final firstSession = daySessions.first;
              final dayDuration = daySessions.fold<Duration>(
                Duration.zero,
                (total, s) => total + s.elapsedDuration,
              );
              final dayStatus =
                  daySessions.any(
                    (s) => s.status == FocusSessionStatus.completed,
                  )
                  ? FocusSessionStatus.completed
                  : daySessions.first.status;

              final statusColor = _getStatusColor(dayStatus, theme);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        dayStatus == FocusSessionStatus.completed
                            ? Icons.check_circle_rounded
                            : _getStatusIcon(dayStatus),
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatSessionDayOnly(firstSession.startedAt),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${daySessions.length} session'
                              '${daySessions.length > 1 ? 's' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatDuration(dayDuration),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            if (sortedDayKeys.length > 7)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${sortedDayKeys.length - 7} more days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
