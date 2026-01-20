import 'package:flutter/material.dart';
import 'package:focus_quest/core/theme/app_colors.dart';
import 'package:focus_quest/models/focus_session.dart';

class TimerControls extends StatelessWidget {
  const TimerControls({
    required this.hasActiveSession,
    required this.isRunning,
    required this.isPaused,
    required this.currentSession,
    required this.sessionColor,
    required this.onStartFocus,
    required this.onStartShortBreak,
    required this.onStartLongBreak,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
    required this.onCancel,
    this.onStartFocusLongPress,
    this.onStartShortBreakLongPress,
    this.onStartLongBreakLongPress,
    super.key,
  });

  final bool hasActiveSession;
  final bool isRunning;
  final bool isPaused;
  final FocusSession? currentSession;
  final Color sessionColor;
  final VoidCallback onStartFocus;
  final VoidCallback onStartShortBreak;
  final VoidCallback onStartLongBreak;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback? onStartFocusLongPress;
  final VoidCallback? onStartShortBreakLongPress;
  final VoidCallback? onStartLongBreakLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!hasActiveSession) {
      // No active session - show start buttons
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main focus button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onStartFocus,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              onLongPress: onStartFocusLongPress,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Start Focus',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Break buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onStartShortBreak,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.lightSecondary,
                    side: BorderSide(
                      color: AppColors.lightSecondary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onLongPress: onStartShortBreakLongPress,
                  child: const Text('Short Break'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onStartLongBreak,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.lightAccent,
                    side: BorderSide(
                      color: AppColors.lightAccent.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onLongPress: onStartLongBreakLongPress,
                  child: const Text('Long Break'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Active session controls
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Cancel button
        CircleButton(
          icon: Icons.close_rounded,
          color: theme.colorScheme.error,
          onPressed: onCancel,
          size: 52,
        ),
        const SizedBox(width: 20),

        // Pause/Resume button
        CircleButton(
          icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: sessionColor,
          onPressed: isRunning ? onPause : onResume,
          size: 72,
          isPrimary: true,
        ),
        const SizedBox(width: 20),

        // Complete button
        CircleButton(
          icon: Icons.check_rounded,
          color: AppColors.lightSuccess,
          onPressed: onComplete,
          size: 52,
        ),
      ],
    );
  }
}

class CircleButton extends StatelessWidget {
  const CircleButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.size,
    this.isPrimary = false,
    super.key,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final double size;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? color : color.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      elevation: isPrimary ? 6 : 0,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: isPrimary ? Colors.white : color,
            size: size * 0.45,
          ),
        ),
      ),
    );
  }
}
