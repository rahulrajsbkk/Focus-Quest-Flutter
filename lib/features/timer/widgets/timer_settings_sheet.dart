import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/features/timer/providers/focus_session_provider.dart';

class TimerSettingsSheet extends ConsumerWidget {
  const TimerSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final focusState = ref.watch<FocusState>(focusSessionProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_outlined),
                const SizedBox(width: 12),
                Text(
                  'Timer Settings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Focus duration
            DurationSlider(
              label: 'Focus Duration',
              value: focusState.focusDuration.inMinutes.toDouble(),
              displayValue: '${focusState.focusDuration.inMinutes} min',
              min: 5,
              max: 60,
              onChanged: (duration) {
                ref
                    .read<FocusSessionNotifier>(focusSessionProvider.notifier)
                    .setFocusDuration(Duration(minutes: duration.toInt()));
              },
            ),
            const SizedBox(height: 20),

            // Short break duration
            DurationSlider(
              label: 'Short Break',
              value: focusState.shortBreakDuration.inMinutes.toDouble(),
              displayValue: '${focusState.shortBreakDuration.inMinutes} min',
              min: 1,
              max: 15,
              onChanged: (duration) {
                ref
                    .read<FocusSessionNotifier>(focusSessionProvider.notifier)
                    .setShortBreakDuration(Duration(minutes: duration.toInt()));
              },
            ),
            const SizedBox(height: 20),

            // Long break duration
            DurationSlider(
              label: 'Long Break',
              value: focusState.longBreakDuration.inMinutes.toDouble(),
              displayValue: '${focusState.longBreakDuration.inMinutes} min',
              min: 5,
              max: 30,
              onChanged: (duration) {
                ref
                    .read<FocusSessionNotifier>(focusSessionProvider.notifier)
                    .setLongBreakDuration(Duration(minutes: duration.toInt()));
              },
            ),
            const SizedBox(height: 20),

            // Power saving delay
            DurationSlider(
              label: 'Go Dark Delay',
              value: focusState.powerSavingInactivityThreshold.inSeconds
                  .toDouble(),
              displayValue:
                  '${focusState.powerSavingInactivityThreshold.inSeconds} sec',
              min: 10,
              max: 60,
              onChanged: (delay) {
                ref
                    .read<FocusSessionNotifier>(focusSessionProvider.notifier)
                    .setPowerSavingInactivityThreshold(
                      Duration(seconds: delay.toInt()),
                    );
              },
            ),
            const SizedBox(height: 20),

            // Pause on background
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Pause on Background',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Pauses the timer if you leave the app',
                style: theme.textTheme.bodySmall,
              ),
              value: focusState.pauseOnBackground,
              onChanged: (value) {
                ref
                    .read<FocusSessionNotifier>(focusSessionProvider.notifier)
                    .setPauseOnBackground(pause: value);
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DurationSlider extends StatelessWidget {
  const DurationSlider({
    required this.label,
    required this.value,
    required this.displayValue,
    required this.min,
    required this.max,
    required this.onChanged,
    super.key,
  });

  final String label;
  final double value;
  final String displayValue;
  final double min;
  final double max;
  final void Function(double) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              displayValue,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
