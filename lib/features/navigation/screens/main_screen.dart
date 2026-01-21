import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/haptic_service.dart';
import 'package:focus_quest/core/theme/app_colors.dart';
import 'package:focus_quest/features/calendar/screens/calendar_screen.dart';
import 'package:focus_quest/features/journal/screens/daily_reflection_screen.dart';
import 'package:focus_quest/features/navigation/providers/navigation_provider.dart';
import 'package:focus_quest/features/profile/screens/profile_screen.dart';
import 'package:focus_quest/features/tasks/providers/date_provider.dart';
import 'package:focus_quest/features/tasks/providers/quest_provider.dart';
import 'package:focus_quest/features/tasks/screens/home_screen.dart';
import 'package:focus_quest/features/tasks/widgets/add_quest_sheet.dart';
import 'package:focus_quest/features/timer/screens/focus_timer_screen.dart';
import 'package:focus_quest/models/quest.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const CalendarScreen(),
    const HomeScreen(), // Dummy for center button
    const FocusTimerScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) return; // Dedicated for FAB
    ref.read(navigationProvider.notifier).setIndex(index);
    unawaited(HapticService().selectionClick());
  }

  Future<void> _showAddQuestSheet() async {
    final selectedDate = ref.read(selectedDateProvider);

    final result = await showModalBottomSheet<Quest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddQuestSheet(initialDate: selectedDate),
    );

    if (result != null) {
      await ref.read(questListProvider.notifier).addQuest(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedIndex = ref.watch(navigationProvider);

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: _screens,
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        height: 100,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                0,
                Icons.home_rounded,
                Icons.home_outlined,
                selectedIndex,
              ),
              _buildNavItem(
                1,
                Icons.calendar_month_rounded,
                Icons.calendar_month_outlined,
                selectedIndex,
              ),
              _buildCenterButton(theme),
              _buildNavItem(
                3,
                Icons.timer_rounded,
                Icons.timer_outlined,
                selectedIndex,
              ),
              _buildNavItem(
                4,
                Icons.person_rounded,
                Icons.person_outline_rounded,
                selectedIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton(ThemeData theme) {
    return GestureDetector(
      onTap: () async {
        await HapticService().lightImpact();
        if (!mounted) return;
        await _showAddMenu(context);
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Future<void> _showAddMenu(BuildContext context) async {
    final theme = Theme.of(context);
    final selectedDate = ref.read<DateTime>(selectedDateProvider);
    final dateStr =
        selectedDate.year == DateTime.now().year &&
            selectedDate.month == DateTime.now().month &&
            selectedDate.day == DateTime.now().day
        ? 'Today'
        : '${selectedDate.day}/${selectedDate.month}';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E), // Dark premium background
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create for $dateStr',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Grid Layout
                  Row(
                    children: [
                      Expanded(
                        child: _AddMenuItem(
                          title: 'New Quest',
                          subtitle: 'Task or Goal',
                          icon: Icons.task_alt_rounded,
                          color: const Color(0xFF6B8AF8), // Blueish
                          onTap: () async {
                            Navigator.pop(context);
                            await _showAddQuestSheet();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _AddMenuItem(
                          title: 'Reflection',
                          subtitle: 'Mood & Wins',
                          icon: Icons.auto_awesome_rounded,
                          color: const Color(0xFFF86B6B), // Reddish
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => DailyReflectionScreen(
                                  date: selectedDate,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Maintenance / Utilities
                  Consumer(
                    builder: (context, ref, child) {
                      final hasOverdue =
                          ref
                              .watch(questListProvider)
                              .value
                              ?.hasOverdueTasks(selectedDate) ??
                          false;
                      if (!hasOverdue) return const SizedBox.shrink();

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            unawaited(HapticService().mediumImpact());
                            final count = await ref
                                .read(questListProvider.notifier)
                                .rescheduleOverdueTasks(
                                  targetDate: selectedDate,
                                );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    count > 0
                                        ? 'Moved $count overdue tasks '
                                              'to $dateStr'
                                        : 'No overdue non-repeating '
                                              'tasks found.',
                                  ),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD54F).withValues(
                                    alpha: 0.2,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.update_rounded,
                                  color: Color(0xFFFFD54F),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Reschedule Overdue',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Move pending tasks to $dateStr',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    int index,
    IconData selectedIcon,
    IconData unselectedIcon,
    int selectedIndex,
  ) {
    final isSelected = selectedIndex == index;
    final theme = Theme.of(context);
    final color = isSelected
        ? (theme.brightness == Brightness.light
              ? AppColors.lightHighlight
              : AppColors.darkHighlight)
        : theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: color,
          size: 24,
        ),
      ),
    );
  }
}

class _AddMenuItem extends StatelessWidget {
  const _AddMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              title == 'Timer'
                  ? Icons.timer_outlined
                  : Icons.person_outline_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Coming Soon: $title',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
