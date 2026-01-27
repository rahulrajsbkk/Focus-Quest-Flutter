import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/haptic_service.dart';
import 'package:focus_quest/core/theme/app_colors.dart';
import 'package:focus_quest/features/tasks/providers/date_provider.dart';
import 'package:focus_quest/features/tasks/providers/quest_provider.dart';
import 'package:focus_quest/features/timer/widgets/quest_time_log_widget.dart';
import 'package:focus_quest/models/quest.dart';

/// A card widget displaying a quest with its status, energy level, and
/// category.
class QuestCard extends ConsumerWidget {
  const QuestCard({
    required this.quest,
    required this.onTap,
    required this.onComplete,
    required this.onDelete,
    this.onStartTimer,
    super.key,
  });

  final Quest quest;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback? onStartTimer;

  Color _getEnergyColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (quest.energyLevel) {
      case EnergyLevel.minimal:
        return isDark ? const Color(0xFF6B9A9A) : const Color(0xFF6B9A9A);
      case EnergyLevel.low:
        return isDark ? const Color(0xFF7A9E7E) : const Color(0xFF7A9E7E);
      case EnergyLevel.medium:
        return isDark ? const Color(0xFFB8A67A) : const Color(0xFFD4A574);
      case EnergyLevel.high:
        return isDark ? const Color(0xFFD4A574) : const Color(0xFFCC8855);
      case EnergyLevel.intense:
        return isDark ? const Color(0xFFC97D7D) : const Color(0xFFC97D7D);
    }
  }

  Color _getCategoryColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (quest.category) {
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

  IconData _getCategoryIcon() {
    switch (quest.category) {
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

  IconData _getRepeatIcon() {
    switch (quest.repeatFrequency) {
      case RepeatFrequency.none:
        return Icons.arrow_forward_rounded;
      case RepeatFrequency.daily:
        return Icons.today_rounded;
      case RepeatFrequency.weekly:
        return Icons.date_range_rounded;
      case RepeatFrequency.monthly:
        return Icons.calendar_month_rounded;
    }
  }

  String _getRepeatLabel() {
    switch (quest.repeatFrequency) {
      case RepeatFrequency.none:
        return '';
      case RepeatFrequency.daily:
        return quest.repeatDaysFormatted;
      case RepeatFrequency.weekly:
        return 'Weekly';
      case RepeatFrequency.monthly:
        return 'Monthly';
    }
  }

  IconData _getStatusIcon() {
    switch (quest.status) {
      case QuestStatus.pending:
        return Icons.radio_button_unchecked_rounded;
      case QuestStatus.inProgress:
        return Icons.play_circle_outline_rounded;
      case QuestStatus.completed:
        return Icons.check_circle_rounded;
      case QuestStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final energyColor = _getEnergyColor(context);
    final categoryColor = _getCategoryColor(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Dismissible(
        key: ValueKey<String>(quest.id),
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.green,
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkError : AppColors.lightError)
                .withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: isDark ? AppColors.darkError : AppColors.lightError,
          ),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Swipe Right: Complete
            if (quest.isCompleted) return false;
            final note = await _showNoteDialog(context);
            if (note != null) {
              await _handleComplete(ref, note: note);
            } else {
              // User cancelled the note dialog, but we might still want to
              // complete?
              // User request says "add option to add notes when a task is
              // getting done"
              // Let's assume they might complete without a note too.
              // If note is null, they cancelled.
              return false;
            }
            return false; // We handled it manually
          } else {
            // Swipe Left: Delete
            if (quest.isRepeating) {
              final result = await _showDeleteOptions(context);
              if (result != null) {
                await _handleDelete(ref, result);
              }
              return false;
            }

            return showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Quest?'),
                content: Text(
                  'Are you sure you want to delete '
                  '"${quest.title}"?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.darkError
                          : AppColors.lightError,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          }
        },
        onDismissed: (_) => onDelete(),
        child: InkWell(
          onTap: () => _showActionMenu(context, ref),
          onLongPress: () async {
            await HapticService().heavyImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: quest.status == QuestStatus.inProgress
                  ? Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      width: 2,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Completion checkbox
                GestureDetector(
                  onTap: () async {
                    if (quest.isCompleted) {
                      await _handleComplete(ref);
                    } else {
                      final note = await _showNoteDialog(context);
                      if (note != null) {
                        await _handleComplete(ref, note: note);
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: quest.isCompleted
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: quest.isCompleted
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                        width: 2,
                      ),
                    ),
                    child: quest.isCompleted
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: theme.colorScheme.onPrimary,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),

                // Quest content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with repeat indicator
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              quest.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                decoration: quest.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: quest.isCompleted
                                    ? theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          if (quest.isRepeating) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getRepeatIcon(),
                                    size: 12,
                                    color: theme.colorScheme.primary,
                                  ),
                                  if (quest.repeatFrequency ==
                                          RepeatFrequency.daily &&
                                      quest.repeatDays.isNotEmpty &&
                                      quest.repeatDays.length < 7) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      _getRepeatLabel(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontSize: 9,
                                          ),
                                    ),
                                  ],
                                  if (quest.completionCount > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '×${quest.completionCount}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                  if (quest.isRepeating &&
                                      quest.currentStreak > 0) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '🔥 ${quest.currentStreak}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: Colors.orange,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (quest.description != null &&
                          quest.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          quest.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Today's Note
                      Consumer(
                        builder: (context, ref, child) {
                          final selectedDate = ref.watch(selectedDateProvider);
                          final y = selectedDate.year;
                          final m = selectedDate.month.toString().padLeft(
                            2,
                            '0',
                          );
                          final d = selectedDate.day.toString().padLeft(2, '0');
                          final dateKey = '$y-$m-$d';
                          final note = quest.completionNotes[dateKey];

                          if (note == null || note.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.sticky_note_2_rounded,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      note,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.8),
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // Category, Energy level, and tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Category chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCategoryIcon(),
                                  size: 12,
                                  color: categoryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  quest.category.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: categoryColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Energy level indicator (5 dots)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: energyColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...List.generate(5, (index) {
                                  final isFilled = index < quest.energyValue;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: index < 4 ? 2 : 0,
                                    ),
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isFilled
                                            ? energyColor
                                            : energyColor.withValues(
                                                alpha: 0.3,
                                              ),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 6),
                                Text(
                                  quest.energyLevel.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: energyColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Tags
                          ...quest.tags
                              .take(2)
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    tag,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Timer button and time logged
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time logged indicator
                    QuestTimeLogWidget(
                      questId: quest.id,
                      compact: true,
                    ),
                    const SizedBox(height: 6),

                    // Timer button (only for active quests)
                    if (!quest.isCompleted && onStartTimer != null)
                      GestureDetector(
                        onTap: onStartTimer,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: theme.colorScheme.secondary,
                            size: 20,
                          ),
                        ),
                      )
                    else
                      // Status indicator for completed quests
                      Icon(
                        _getStatusIcon(),
                        color: quest.isCompleted
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                        size: 20,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _showNoteDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Quest'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a note for "${quest.title}" (optional):'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Great work! Any notes?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showDeleteOptions(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Delete Repeating Task',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Today only'),
              onTap: () => Navigator.pop(context, 'today'),
            ),
            ListTile(
              leading: const Icon(Icons.next_plan),
              title: const Text('Today and following days'),
              onTap: () => Navigator.pop(context, 'following'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete completely',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(context, 'complete'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleComplete(WidgetRef ref, {String note = ''}) async {
    final selectedDate = ref.read(selectedDateProvider);
    await ref
        .read(questListProvider.notifier)
        .toggleQuestCompletion(
          quest.id,
          note: note,
          completionDate: selectedDate,
        );
  }

  Future<void> _handleDelete(WidgetRef ref, String option) async {
    final notifier = ref.read(questListProvider.notifier);
    final selectedDate = ref.read(selectedDateProvider);
    switch (option) {
      case 'today':
        await notifier.skipQuestForToday(quest.id, targetDate: selectedDate);
      case 'following':
        await notifier.stopQuestRecurrence(quest.id, targetDate: selectedDate);
      case 'complete':
        await notifier.deleteQuest(quest.id);
    }
  }

  Future<void> _showActionMenu(BuildContext context, WidgetRef ref) async {
    await HapticService().selectionClick();
    if (!context.mounted) return;

    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Quest Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(
                          context,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getCategoryIcon(),
                        color: _getCategoryColor(context),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quest.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${quest.category.label} • '
                            '${quest.energyLevel.label}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Action Buttons
                _ActionTile(
                  icon: Icons.edit_rounded,
                  label: 'Edit Quest',
                  color: theme.colorScheme.primary,
                  onTap: () {
                    Navigator.pop(context);
                    onTap();
                  },
                ),

                if (onStartTimer != null && !quest.isCompleted) ...[
                  const SizedBox(height: 8),
                  _ActionTile(
                    icon: Icons.play_arrow_rounded,
                    label: 'Start Focus Session',
                    color: Colors.orange,
                    isHighlighted: true,
                    onTap: () {
                      Navigator.pop(context);
                      onStartTimer?.call();
                    },
                  ),
                ],

                const SizedBox(height: 8),

                _ActionTile(
                  icon: quest.isCompleted
                      ? Icons.undo_rounded
                      : Icons.check_circle_outline_rounded,
                  label: quest.isCompleted
                      ? 'Mark as Not Done'
                      : 'Complete Quest',
                  color: Colors.green,
                  onTap: () async {
                    Navigator.pop(context);
                    if (quest.isCompleted) {
                      await _handleComplete(ref);
                    } else {
                      final note = await _showNoteDialog(context);
                      if (note != null) {
                        await _handleComplete(ref, note: note);
                      }
                    }
                  },
                ),

                const SizedBox(height: 8),
                const Divider(height: 24),

                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete Quest',
                  color: theme.colorScheme.error,
                  isDestructive: true,
                  onTap: () async {
                    Navigator.pop(context);
                    if (quest.isRepeating) {
                      final result = await _showDeleteOptions(context);
                      if (result != null) {
                        await _handleDelete(ref, result);
                      }
                    } else {
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Quest?'),
                          content: Text(
                            'Are you sure you want to delete '
                            '"${quest.title}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: isDark
                                    ? AppColors.darkError
                                    : AppColors.lightError,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm ?? false) {
                        onDelete();
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isHighlighted = false,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isHighlighted;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = color ?? theme.colorScheme.onSurface;

    return Material(
      color: isHighlighted
          ? tileColor.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? tileColor.withValues(alpha: 0.2)
                      : tileColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: tileColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDestructive ? tileColor : null,
                  ),
                ),
              ),
              if (isHighlighted)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: tileColor.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
