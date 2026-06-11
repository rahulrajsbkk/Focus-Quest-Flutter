import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/haptic_service.dart';
import 'package:focus_quest/features/journal/providers/journal_provider.dart';
import 'package:focus_quest/features/journal/screens/daily_reflection_screen.dart';
import 'package:focus_quest/features/tasks/providers/date_provider.dart';
import 'package:focus_quest/features/tasks/providers/quest_provider.dart';
import 'package:focus_quest/features/tasks/widgets/add_quest_sheet.dart';
import 'package:focus_quest/features/tasks/widgets/quest_card.dart';
import 'package:focus_quest/models/journal_entry.dart';
import 'package:focus_quest/models/quest.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedDate = ref.watch(selectedDateProvider);
    final questState = ref.watch(questListProvider);

    // Replicating filtering logic from HomeScreen
    final allQuests = questState.value?.quests ?? [];
    final dailyQuests =
        allQuests
            .where((q) {
              final isScheduled = q.isScheduledForDate(selectedDate);

              var isOverdue = false;
              final now = DateTime.now();
              if (selectedDate.year == now.year &&
                  selectedDate.month == now.month &&
                  selectedDate.day == now.day) {
                if (q.isActive && q.dueDate != null) {
                  final due = DateTime(
                    q.dueDate!.year,
                    q.dueDate!.month,
                    q.dueDate!.day,
                  );
                  final today = DateTime(now.year, now.month, now.day);
                  isOverdue = due.isBefore(today);
                }
              }

              return isScheduled || isOverdue;
            })
            .map((q) => q.copyWith(status: q.statusForDate(selectedDate)))
            .toList()
          ..sort((a, b) {
            if (a.isCompleted != b.isCompleted) {
              return a.isCompleted ? 1 : -1;
            }
            final orderCompare = a.sortOrder.compareTo(b.sortOrder);
            if (orderCompare != 0) return orderCompare;
            return b.createdAt.compareTo(a.createdAt);
          });

    final journalState = ref.watch(journalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TableCalendar<Quest>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: selectedDate,
              currentDay: DateTime.now(),
              selectedDayPredicate: (day) => isSameDay(selectedDate, day),
              onDaySelected: (selected, focused) {
                if (!isSameDay(selectedDate, selected)) {
                  ref.read(selectedDateProvider.notifier).date = selected;
                  unawaited(HapticService().selectionClick());
                }
              },
              eventLoader: (day) {
                return allQuests
                    .where((q) => q.isScheduledForDate(day))
                    .toList();
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: theme.colorScheme.primary),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),

                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  // Find reflection if any
                  final entries = journalState.value ?? [];
                  final entry = entries.fold<JournalEntry?>(
                    null,
                    (prev, e) => isSameDay(e.date, date) ? e : prev,
                  );

                  if (entry == null && events.isEmpty) return null;

                  return Positioned(
                    bottom: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (entry != null)
                          Text(
                            entry.mood,
                            style: const TextStyle(fontSize: 10),
                          ),
                        if (events.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 2),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 16),
              children: [
                journalState.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) => Center(child: Text('Error: $error')),
                  data: (entries) {
                    final selectedEntry = entries.fold<JournalEntry?>(
                      null,
                      (prev, e) => isSameDay(e.date, selectedDate) ? e : prev,
                    );

                    if (selectedEntry != null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _ReflectionDetailsCard(entry: selectedEntry),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => DailyReflectionScreen(
                                  date: selectedDate,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add Reflection',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),

                // Quests Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Quests',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                questState.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) => Center(child: Text('Error: $error')),
                  data: (_) => dailyQuests.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 48,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No quests for this day',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: dailyQuests
                              .map(
                                (quest) => Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  child: QuestCard(
                                    key: ValueKey(quest.id),
                                    quest: quest,
                                    onTap: () async {
                                      final result =
                                          await showModalBottomSheet<Quest>(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor:
                                                theme.colorScheme.surface,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                    top: Radius.circular(20),
                                                  ),
                                            ),
                                            builder: (context) => AddQuestSheet(
                                              existingQuest: quest,
                                              initialDate: selectedDate,
                                            ),
                                          );

                                      if (result != null) {
                                        await ref
                                            .read(questListProvider.notifier)
                                            .updateQuest(result);
                                      }
                                    },
                                    onComplete: () async {
                                      await HapticService().mediumImpact();
                                      await ref
                                          .read(questListProvider.notifier)
                                          .toggleQuestCompletion(
                                            quest.id,
                                            completionDate: selectedDate,
                                          );
                                    },
                                    onDelete: () async {
                                      await ref
                                          .read(questListProvider.notifier)
                                          .deleteQuest(quest.id);
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                // Padding for bottom nav
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionDetailsCard extends StatelessWidget {
  const _ReflectionDetailsCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.mood,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Reflection',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      entry.biggestWin.isNotEmpty
                          ? entry.biggestWin
                          : 'Relaxed day',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DailyReflectionScreen(
                        date: entry.date,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          if (entry.improvementForTomorrow.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Goal: ${entry.improvementForTomorrow}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
