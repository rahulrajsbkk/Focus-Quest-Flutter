import 'dart:async';

import 'package:flutter/material.dart';
import 'package:focus_quest/core/services/haptic_service.dart';
import 'package:intl/intl.dart';

class WeeklyCalendar extends StatefulWidget {
  const WeeklyCalendar({
    required this.selectedDate,
    required this.onDateSelected,
    super.key,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<WeeklyCalendar> createState() => _WeeklyCalendarState();
}

class _WeeklyCalendarState extends State<WeeklyCalendar> {
  late DateTime _weekStart;
  final List<DateTime> _days = [];

  @override
  void initState() {
    super.initState();
    _weekStart = _getStartOfWeek(widget.selectedDate);
    _generateDays();
  }

  @override
  void didUpdateWidget(WeeklyCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the selected date changes to a day outside the currently displayed
    // week, update the view to show that week.
    if (!_isDateInVisibleWeek(widget.selectedDate)) {
      setState(() {
        _weekStart = _getStartOfWeek(widget.selectedDate);
        _generateDays();
      });
    }
  }

  DateTime _getStartOfWeek(DateTime date) {
    // Find the Monday (weekday 1) of the week containing the given date
    final dayOnly = DateTime(date.year, date.month, date.day);
    return dayOnly.subtract(Duration(days: dayOnly.weekday - 1));
  }

  bool _isDateInVisibleWeek(DateTime date) {
    if (_days.isEmpty) return false;
    final endOfWeek = _weekStart.add(const Duration(days: 6));
    final checkDate = DateTime(date.year, date.month, date.day);
    return !checkDate.isBefore(_weekStart) && !checkDate.isAfter(endOfWeek);
  }

  void _generateDays() {
    _days.clear();
    for (var i = 0; i < 7; i++) {
      _days.add(_weekStart.add(Duration(days: i)));
    }
  }

  void _nextWeek() {
    unawaited(HapticService().selectionClick());
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _generateDays();
    });
  }

  void _previousWeek() {
    unawaited(HapticService().selectionClick());
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _generateDays();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthYear = DateFormat('MMMM yyyy').format(_weekStart);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Month Label with Navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthYear,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  _NavButton(
                    icon: Icons.chevron_left_rounded,
                    onPressed: _previousWeek,
                  ),
                  const SizedBox(width: 8),
                  _NavButton(
                    icon: Icons.chevron_right_rounded,
                    onPressed: _nextWeek,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Days Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _days.map((date) {
              final isSelected = _isSameDay(date, widget.selectedDate);
              return _DateItem(
                date: date,
                isSelected: isSelected,
                onTap: () => widget.onDateSelected(date),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _DateItem extends StatelessWidget {
  const _DateItem({
    required this.date,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _isSameDay(date, DateTime.now());

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42, // Slightly smaller to fit arrows if needed
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(
                  color: isToday
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('E').format(date).toUpperCase(), // Mon, Tue
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              date.day.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
