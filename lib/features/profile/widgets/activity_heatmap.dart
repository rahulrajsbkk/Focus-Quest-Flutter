import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/features/profile/providers/activity_stats_provider.dart';

/// A GitHub-style contribution heatmap widget (Smart Wrapper).
class ActivityHeatmap extends ConsumerWidget {
  const ActivityHeatmap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityDataAsync = ref.watch(activityHeatmapProvider);

    return activityDataAsync.when(
      data: (data) => ActivityHeatmapView(
        data: data,
        startDate: DateTime(DateTime.now().year),
        endDate: DateTime(DateTime.now().year, 12, 31),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}

/// Pure UI component for the heatmap, decoupled from Riverpod.
class ActivityHeatmapView extends StatelessWidget {
  const ActivityHeatmapView({
    required this.data,
    super.key,
    this.startDate,
    this.endDate,
  });

  final Map<DateTime, int> data;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    // Default to current year Jan 1 to Dec 31 if not provided
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year);
    final end = endDate ?? DateTime(now.year, 12, 31);

    // Ensure we align start to Sunday for the grid
    final daysFromSunday = start.weekday == 7 ? 0 : start.weekday;
    final adjustedStartDate = start.subtract(Duration(days: daysFromSunday));

    // Calculate total days to display
    final totalDays = end.difference(adjustedStartDate).inDays + 1;
    final totalWeeks = (totalDays / 7).ceil();

    const fullHeight = 70.0;
    const cellWidth = 8.0;
    const cellSpacing = 1.0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_calculateTotalContributions()} contributions in ${start.year}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: fullHeight, // Height for 7 items + spacing
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            // If current date is far right, maybe initialScrollOffset?
            // For "Jan to Dec" usually we start at Jan (left).
            itemCount: totalWeeks,
            itemBuilder: (context, weekIndex) {
              final weekStartDate = adjustedStartDate.add(
                Duration(days: weekIndex * 7),
              );

              return Column(
                // mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // No month labels for now to keep it simple, or add later
                  ...List.generate(7, (dayIndex) {
                    final date = weekStartDate.add(Duration(days: dayIndex));

                    // If date is outside the requested range, show empty or
                    // invisible
                    if (date.isBefore(start) || date.isAfter(end)) {
                      return Container(
                        width: cellWidth,
                        height: cellWidth,
                        margin: const EdgeInsets.all(cellSpacing),
                      );
                    }

                    // Check intensity
                    final dateKey = DateTime(date.year, date.month, date.day);
                    final intensity = data[dateKey] ?? 0;

                    return Container(
                      width: cellWidth,
                      height: cellWidth,
                      margin: const EdgeInsets.all(cellSpacing),
                      decoration: BoxDecoration(
                        color: _getColorForIntensity(context, intensity),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 4),
            _legendBox(context, 0),
            _legendBox(context, 2),
            _legendBox(context, 4),
            _legendBox(context, 6),
            _legendBox(context, 8),
            const SizedBox(width: 4),
            Text('More', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );

    return content;
  }

  int _calculateTotalContributions() {
    // Sum all values in data that are within the range
    var total = 0;
    // We can just sum all data values for simplicity as we usually only load
    // relevant data. Or filter:
    final s = startDate ?? DateTime(DateTime.now().year);
    final e = endDate ?? DateTime(DateTime.now().year, 12, 31);

    data.forEach((key, value) {
      if (!key.isBefore(s) && !key.isAfter(e)) {
        total += value;
      }
    });

    return total;
  }

  Widget _legendBox(BuildContext context, int intensity) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: _getColorForIntensity(context, intensity),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Color _getColorForIntensity(BuildContext context, int count) {
    if (count == 0) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]!
          : Colors.grey[200]!;
    }

    final primary = Theme.of(context).colorScheme.primary;

    if (count <= 2) return primary.withValues(alpha: 0.3);
    if (count <= 4) return primary.withValues(alpha: 0.5);
    if (count <= 6) return primary.withValues(alpha: 0.7);
    return primary; // Solid
  }
}
