import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/haptic_service.dart';
import 'package:focus_quest/core/widgets/theme_switcher.dart';
import 'package:focus_quest/features/tasks/providers/quest_provider.dart';
import 'package:focus_quest/features/tasks/widgets/add_quest_sheet.dart';
import 'package:focus_quest/features/tasks/widgets/quest_card.dart';
import 'package:focus_quest/features/tasks/widgets/weekly_calendar.dart';
import 'package:focus_quest/models/quest.dart';

/// The main home screen displaying quests.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _showAddQuestSheet({Quest? existingQuest}) async {
    final result = await showModalBottomSheet<Quest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddQuestSheet(
        existingQuest: existingQuest,
        initialDate: _selectedDate,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questState = ref.watch(questListProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    // Filter quests for selected date
    final allQuests = questState.value?.quests ?? [];
    final dailyQuests =
        allQuests
            .where((q) {
              // 1. Check if scheduled for this date
              final isScheduled = q.isScheduledForDate(_selectedDate);

              // 2. If it's today, also show active overdue tasks (due date <
              // today)
              var isOverdue = false;
              if (_isSameDay(_selectedDate, DateTime.now())) {
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
              return q.copyWith(status: q.statusForDate(_selectedDate));
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusQuest'),
        actions: const [
          ThemeSwitcherButton(),
        ],
      ),
      body: Column(
        children: [
          // Weekly Calendar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: WeeklyCalendar(
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
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
                    ref.read(questListProvider.notifier).filterByCategory(null);
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
              data: (state) => _QuestList(
                quests: dailyQuests,
                emptyMessage: 'No quests for this day',
                emptySubtitle: 'Enjoy your free time!',
                emptyIcon: Icons.calendar_month_outlined,
                onQuestTap: (quest) => _showAddQuestSheet(existingQuest: quest),
                onQuestComplete: (quest) async {
                  await HapticService().mediumImpact();
                  await ref
                      .read(questListProvider.notifier)
                      .toggleQuestCompletion(
                        quest.id,
                        completionDate: _selectedDate,
                      );
                },
                onQuestDelete: (quest) async {
                  await ref
                      .read(questListProvider.notifier)
                      .deleteQuest(quest.id);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await HapticService().lightImpact();
          await _showAddQuestSheet();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Quest'),
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

class _QuestList extends StatelessWidget {
  const _QuestList({
    required this.quests,
    required this.emptyMessage,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.onQuestTap,
    required this.onQuestComplete,
    required this.onQuestDelete,
  });

  final List<Quest> quests;
  final String emptyMessage;
  final String emptySubtitle;
  final IconData emptyIcon;
  final void Function(Quest) onQuestTap;
  final void Function(Quest) onQuestComplete;
  final void Function(Quest) onQuestDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (quests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emptyIcon,
                  size: 48,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                emptyMessage,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        final quest = quests[index];
        return QuestCard(
          key: ValueKey(quest.id),
          quest: quest,
          onTap: () => onQuestTap(quest),
          onComplete: () => onQuestComplete(quest),
          onDelete: () => onQuestDelete(quest),
        );
      },
    );
  }
}
