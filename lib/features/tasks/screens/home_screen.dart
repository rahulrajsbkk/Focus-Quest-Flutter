import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/haptic_service.dart';
import 'package:focus_quest/core/widgets/theme_switcher.dart';
import 'package:focus_quest/features/auth/providers/auth_provider.dart';
import 'package:focus_quest/features/navigation/providers/navigation_provider.dart';
import 'package:focus_quest/features/tasks/providers/date_provider.dart';
import 'package:focus_quest/features/tasks/providers/quest_provider.dart';
import 'package:focus_quest/features/tasks/widgets/add_quest_sheet.dart';
import 'package:focus_quest/features/tasks/widgets/quest_list_view.dart';
import 'package:focus_quest/features/tasks/widgets/weekly_calendar.dart';
import 'package:focus_quest/features/timer/providers/focus_session_provider.dart';
import 'package:focus_quest/models/quest.dart';

/// The main home screen displaying quests.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // DateTime _selectedDate = DateTime.now(); // REMOVED local state

  Future<void> _showAddQuestSheet({Quest? existingQuest}) async {
    final selectedDate = ref.read(selectedDateProvider);

    final result = await showModalBottomSheet<Quest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddQuestSheet(
        existingQuest: existingQuest,
        initialDate: selectedDate,
      ),
    );

    if (result != null) {
      if (existingQuest != null) {
        await ref.read(questListProvider.notifier).updateQuest(result);
      } else {
        await ref.read(questListProvider.notifier).addQuest(result);
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questState = ref.watch(questListProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final authState = ref.watch(authProvider);

    // Filter quests for selected date
    final allQuests = questState.value?.quests ?? [];
    final dailyQuests =
        allQuests
            .where((q) {
              // 1. Check if scheduled for this date
              final isScheduled = q.isScheduledForDate(selectedDate);

              // 2. If it's today, also show active overdue tasks (due date <
              // today)
              var isOverdue = false;
              if (_isSameDay(selectedDate, DateTime.now())) {
                if (q.isActive && q.dueDate != null) {
                  final due = DateTime(
                    q.dueDate!.year,
                    q.dueDate!.month,
                    q.dueDate!.day,
                  );
                  final today = DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  );
                  isOverdue = due.isBefore(today);
                }
              }

              // 3. Category filter
              if (selectedCategory != null && q.category != selectedCategory) {
                return false;
              }

              return isScheduled || isOverdue;
            })
            .map((q) {
              // Create a view-specific quest object with the correct status for
              // this day
              return q.copyWith(status: q.statusForDate(selectedDate));
            })
            .toList()
          ..sort((a, b) {
            if (a.isCompleted != b.isCompleted) {
              return a.isCompleted ? 1 : -1; // Uncompleted first
            }
            return b.createdAt.compareTo(a.createdAt);
          });

    final completedCount = dailyQuests.where((q) => q.isCompleted).length;
    final totalCount = dailyQuests.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    // Get user display name
    final userName = authState.value?.displayName ?? 'Adventurer';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()},',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        Text(
                          userName,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      onPressed: () {},
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ThemeSwitcherButton(),
                ],
              ),
            ),
            // Weekly Calendar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: WeeklyCalendar(
                selectedDate: selectedDate, // Use variable
                onDateSelected: (date) {
                  // Update provider
                  ref.read(selectedDateProvider.notifier).date = date;
                  unawaited(HapticService().selectionClick());
                },
              ),
            ),

            // Daily Progress Summary (Optional but matches "ideas" image style)
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$completedCount Task'
                            '${completedCount == 1 ? '' : 's'} Completed',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "You've completed daily tasks",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        value: progress,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        strokeWidth: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Category Chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CategoryChip(
                    label: 'All',
                    icon: Icons.apps_rounded,
                    isSelected: selectedCategory == null,
                    onTap: () {
                      unawaited(HapticService().selectionClick());
                      ref
                          .read(questListProvider.notifier)
                          .filterByCategory(null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ...QuestCategory.values.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CategoryChip(
                        label: category.label,
                        icon: _getCategoryIcon(category),
                        color: _getCategoryColor(context, category),
                        isSelected: selectedCategory == category,
                        onTap: () {
                          unawaited(HapticService().selectionClick());
                          ref
                              .read(questListProvider.notifier)
                              .filterByCategory(category);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Task List
            Expanded(
              child: questState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (state) => QuestListView(
                  quests: dailyQuests,
                  emptyMessage: 'No quests for this day',
                  emptySubtitle: 'Enjoy your free time!',
                  emptyIcon: Icons.calendar_month_outlined,
                  onQuestTap: (quest) =>
                      _showAddQuestSheet(existingQuest: quest),
                  onQuestComplete: (quest) async {
                    await HapticService().mediumImpact();
                    await ref
                        .read(questListProvider.notifier)
                        .toggleQuestCompletion(
                          quest.id,
                          completionDate: selectedDate,
                        );
                  },
                  onQuestDelete: (quest) async {
                    await ref
                        .read(questListProvider.notifier)
                        .deleteQuest(quest.id);
                  },
                  onStartTimer: (Quest quest) {
                    // Select the quest for timer and navigate to timer tab
                    ref.read(focusSessionProvider.notifier).selectQuest(quest);
                    // Navigate to timer tab (index 3)
                    ref.read(navigationProvider.notifier).setIndex(3);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(QuestCategory category) {
    switch (category) {
      case QuestCategory.work:
        return Icons.work_outline_rounded;
      case QuestCategory.personal:
        return Icons.person_outline_rounded;
      case QuestCategory.learning:
        return Icons.school_outlined;
      case QuestCategory.other:
        return Icons.category_outlined;
    }
  }

  Color _getCategoryColor(BuildContext context, QuestCategory category) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (category) {
      case QuestCategory.work:
        return isDark ? const Color(0xFF7A9ECE) : const Color(0xFF5A7EA8);
      case QuestCategory.personal:
        return isDark ? const Color(0xFFCE7AA0) : const Color(0xFFA85A7E);
      case QuestCategory.learning:
        return isDark ? const Color(0xFF9E7ACE) : const Color(0xFF7E5AA8);
      case QuestCategory.other:
        return isDark ? const Color(0xFF9A9A9A) : const Color(0xFF6B6B6B);
    }
  }
}

/// Helper function to explicitly ignore a future.
void unawaited(Future<void>? future) {}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return Material(
      color: isSelected
          ? chipColor.withValues(alpha: 0.15)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? chipColor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.15),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? chipColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? chipColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
