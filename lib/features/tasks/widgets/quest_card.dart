import 'package:flutter/material.dart';
import 'package:flutter_quest/core/theme/app_colors.dart';
import 'package:flutter_quest/models/quest.dart';

/// A card widget displaying a quest with its status, energy level, and
/// category.
class QuestCard extends StatelessWidget {
  const QuestCard({
    required this.quest,
    required this.onTap,
    required this.onComplete,
    required this.onDelete,
    super.key,
  });

  final Quest quest;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final energyColor = _getEnergyColor(context);
    final categoryColor = _getCategoryColor(context);

    return Dismissible(
      key: Key(quest.id),
      direction: DismissDirection.endToStart,
      background: Container(
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
        return showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Quest?'),
            content: Text('Are you sure you want to delete "${quest.title}"?'),
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
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: onTap,
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
                  onTap: onComplete,
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

                // Status indicator
                Icon(
                  _getStatusIcon(),
                  color: quest.isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
