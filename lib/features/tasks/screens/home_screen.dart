import 'package:flutter/material.dart';
import 'package:flutter_quest/core/services/haptic_service.dart';
import 'package:flutter_quest/core/widgets/theme_switcher.dart';
import 'package:flutter_quest/features/tasks/providers/quest_provider.dart';
import 'package:flutter_quest/features/tasks/widgets/add_quest_sheet.dart';
import 'package:flutter_quest/features/tasks/widgets/quest_card.dart';
import 'package:flutter_quest/models/quest.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The main home screen displaying quests.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showAddQuestSheet({Quest? existingQuest}) async {
    final result = await showModalBottomSheet<Quest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddQuestSheet(existingQuest: existingQuest),
    );

    if (result != null) {
      if (existingQuest != null) {
        await ref.read(questListProvider.notifier).updateQuest(result);
      } else {
        await ref.read(questListProvider.notifier).addQuest(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questState = ref.watch(questListProvider);
    final activeQuests = ref.watch(activeQuestsProvider);
    final completedQuests = ref.watch(completedQuestsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusQuest'),
        actions: const [
          ThemeSwitcherButton(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Category filter chips
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
              // Tabs
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.rocket_launch_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Active (${activeQuests.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text('Done (${completedQuests.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: questState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (state) => TabBarView(
          controller: _tabController,
          children: [
            // Active quests tab
            _QuestList(
              quests: activeQuests,
              emptyMessage: selectedCategory != null
                  ? 'No active ${selectedCategory.label.toLowerCase()} quests'
                  : 'No active quests',
              emptySubtitle: 'Tap + to create your first quest!',
              emptyIcon: Icons.rocket_launch_outlined,
              onQuestTap: (quest) => _showAddQuestSheet(existingQuest: quest),
              onQuestComplete: (quest) async {
                await HapticService().mediumImpact();
                await ref
                    .read(questListProvider.notifier)
                    .toggleQuestCompletion(quest.id);
              },
              onQuestDelete: (quest) async {
                await ref
                    .read(questListProvider.notifier)
                    .deleteQuest(quest.id);
              },
            ),

            // Completed quests tab
            _QuestList(
              quests: completedQuests,
              emptyMessage: selectedCategory != null
                  ? 'No completed '
                        '${selectedCategory.label.toLowerCase()} quests'
                  : 'No completed quests yet',
              emptySubtitle: 'Complete a quest to see it here',
              emptyIcon: Icons.emoji_events_outlined,
              onQuestTap: (quest) => _showAddQuestSheet(existingQuest: quest),
              onQuestComplete: (quest) async {
                await HapticService().selectionClick();
                await ref
                    .read(questListProvider.notifier)
                    .toggleQuestCompletion(quest.id);
              },
              onQuestDelete: (quest) async {
                await ref
                    .read(questListProvider.notifier)
                    .deleteQuest(quest.id);
              },
            ),
          ],
        ),
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
