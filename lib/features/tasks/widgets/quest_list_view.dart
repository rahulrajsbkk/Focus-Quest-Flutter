import 'package:flutter/material.dart';
import 'package:focus_quest/features/tasks/widgets/quest_card.dart';
import 'package:focus_quest/models/quest.dart';

class QuestListView extends StatelessWidget {
  const QuestListView({
    required this.quests,
    required this.emptyMessage,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.onQuestTap,
    required this.onQuestComplete,
    required this.onQuestDelete,
    this.onStartTimer,
    this.onReorder,
    super.key,
  });

  final List<Quest> quests;
  final String emptyMessage;
  final String emptySubtitle;
  final IconData emptyIcon;
  final void Function(Quest) onQuestTap;
  final void Function(Quest) onQuestComplete;
  final void Function(Quest) onQuestDelete;
  final void Function(Quest)? onStartTimer;
  final void Function(int oldIndex, int newIndex)? onReorder;

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

    if (onReorder != null) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        buildDefaultDragHandles: false,
        itemCount: quests.length,
        onReorderItem: onReorder,
        itemBuilder: (context, index) {
          final quest = quests[index];
          return QuestCard(
            key: ValueKey(quest.id),
            quest: quest,
            index: index,
            onTap: () => onQuestTap(quest),
            onComplete: () => onQuestComplete(quest),
            onDelete: () => onQuestDelete(quest),
            onStartTimer: onStartTimer != null
                ? () => onStartTimer!(quest)
                : null,
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        final quest = quests[index];
        return QuestCard(
          key: ValueKey(quest.id),
          quest: quest,
          onTap: () => onQuestTap(quest),
          onComplete: () => onQuestComplete(quest),
          onDelete: () => onQuestDelete(quest),
          onStartTimer: onStartTimer != null
              ? () => onStartTimer!(quest)
              : null,
        );
      },
    );
  }
}
