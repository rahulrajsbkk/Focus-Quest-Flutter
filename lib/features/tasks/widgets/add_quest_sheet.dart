import 'package:flutter/material.dart';
import 'package:flutter_quest/core/services/haptic_service.dart';
import 'package:flutter_quest/models/quest.dart';

/// Bottom sheet for adding or editing a quest.
class AddQuestSheet extends StatefulWidget {
  const AddQuestSheet({
    this.existingQuest,
    super.key,
  });

  /// If provided, the sheet will edit this quest instead of creating a new one.
  final Quest? existingQuest;

  @override
  State<AddQuestSheet> createState() => _AddQuestSheetState();
}

class _AddQuestSheetState extends State<AddQuestSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late EnergyLevel _selectedEnergy;
  late QuestCategory _selectedCategory;
  late RepeatFrequency _selectedRepeat;
  late Set<Weekday> _selectedDays;
  final _formKey = GlobalKey<FormState>();

  bool get isEditing => widget.existingQuest != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingQuest?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existingQuest?.description ?? '',
    );
    _selectedEnergy = widget.existingQuest?.energyLevel ?? EnergyLevel.medium;
    _selectedCategory = widget.existingQuest?.category ?? QuestCategory.other;
    _selectedRepeat =
        widget.existingQuest?.repeatFrequency ?? RepeatFrequency.none;
    _selectedDays = Set<Weekday>.from(widget.existingQuest?.repeatDays ?? {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final quest = widget.existingQuest != null
        ? widget.existingQuest!.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            energyLevel: _selectedEnergy,
            category: _selectedCategory,
            repeatFrequency: _selectedRepeat,
            repeatDays: _selectedRepeat == RepeatFrequency.daily
                ? _selectedDays
                : <Weekday>{},
            updatedAt: now,
          )
        : Quest(
            id: 'quest_${now.millisecondsSinceEpoch}',
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            energyLevel: _selectedEnergy,
            category: _selectedCategory,
            repeatFrequency: _selectedRepeat,
            repeatDays: _selectedRepeat == RepeatFrequency.daily
                ? _selectedDays
                : <Weekday>{},
            createdAt: now,
          );

    await HapticService().lightImpact();
    if (mounted) {
      Navigator.pop(context, quest);
    }
  }

  Future<void> _toggleDay(Weekday day) async {
    await HapticService().selectionClick();
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  Future<void> _selectAllDays() async {
    await HapticService().selectionClick();
    setState(() {
      _selectedDays = Set<Weekday>.from(Weekday.values);
    });
  }

  Future<void> _selectWeekdays() async {
    await HapticService().selectionClick();
    setState(() {
      _selectedDays = {
        Weekday.monday,
        Weekday.tuesday,
        Weekday.wednesday,
        Weekday.thursday,
        Weekday.friday,
      };
    });
  }

  Future<void> _selectWeekends() async {
    await HapticService().selectionClick();
    setState(() {
      _selectedDays = {Weekday.saturday, Weekday.sunday};
    });
  }

  Future<void> _clearDays() async {
    await HapticService().selectionClick();
    setState(() {
      _selectedDays.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  isEditing ? 'Edit Quest' : 'New Quest',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  isEditing
                      ? 'Update your quest details'
                      : 'What would you like to accomplish?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),

                // Quest title input
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Quest title',
                    hintText: 'e.g., Review project proposal',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a quest title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description input
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Add some details...',
                  ),
                ),
                const SizedBox(height: 24),

                // Category selector
                Text(
                  'Category',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: QuestCategory.values.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: category != QuestCategory.other ? 6 : 0,
                        ),
                        child: _CategoryButton(
                          category: category,
                          isSelected: isSelected,
                          onTap: () async {
                            await HapticService().selectionClick();
                            setState(() => _selectedCategory = category);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Energy level selector (5 levels)
                Text(
                  'Energy Required',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                _EnergySlider(
                  value: _selectedEnergy,
                  onChanged: (energy) async {
                    await HapticService().selectionClick();
                    setState(() => _selectedEnergy = energy);
                  },
                ),
                const SizedBox(height: 24),

                // Repeat frequency selector
                Text(
                  'Repeat',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: RepeatFrequency.values.map((repeat) {
                    final isSelected = _selectedRepeat == repeat;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: repeat != RepeatFrequency.monthly ? 6 : 0,
                        ),
                        child: _RepeatButton(
                          repeat: repeat,
                          isSelected: isSelected,
                          onTap: () async {
                            await HapticService().selectionClick();
                            setState(() => _selectedRepeat = repeat);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Day of week selector (only shown when Daily is selected)
                if (_selectedRepeat == RepeatFrequency.daily) ...[
                  const SizedBox(height: 16),
                  _DayOfWeekSelector(
                    selectedDays: _selectedDays,
                    onToggleDay: _toggleDay,
                    onSelectAll: _selectAllDays,
                    onSelectWeekdays: _selectWeekdays,
                    onSelectWeekends: _selectWeekends,
                    onClear: _clearDays,
                  ),
                ],

                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: Text(isEditing ? 'Save Changes' : 'Create Quest'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayOfWeekSelector extends StatelessWidget {
  const _DayOfWeekSelector({
    required this.selectedDays,
    required this.onToggleDay,
    required this.onSelectAll,
    required this.onSelectWeekdays,
    required this.onSelectWeekends,
    required this.onClear,
  });

  final Set<Weekday> selectedDays;
  final Future<void> Function(Weekday) onToggleDay;
  final Future<void> Function() onSelectAll;
  final Future<void> Function() onSelectWeekdays;
  final Future<void> Function() onSelectWeekends;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Repeat on',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                selectedDays.isEmpty
                    ? 'Every day'
                    : '${selectedDays.length} days',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Day buttons
          Row(
            children: Weekday.values.map((day) {
              final isSelected = selectedDays.contains(day);
              final isToday = day == Weekday.today;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: day != Weekday.sunday ? 4 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => onToggleDay(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : isToday
                              ? theme.colorScheme.primary.withValues(alpha: 0.5)
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.2,
                                ),
                          width: isToday && !isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          day.shortName.substring(0, 1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                            fontWeight: isSelected || isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Quick select buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickSelectChip(
                label: 'Every day',
                isSelected: selectedDays.isEmpty || selectedDays.length == 7,
                onTap: onClear,
              ),
              _QuickSelectChip(
                label: 'Weekdays',
                isSelected:
                    selectedDays.length == 5 &&
                    selectedDays.contains(Weekday.monday) &&
                    selectedDays.contains(Weekday.friday) &&
                    !selectedDays.contains(Weekday.saturday),
                onTap: onSelectWeekdays,
              ),
              _QuickSelectChip(
                label: 'Weekends',
                isSelected:
                    selectedDays.length == 2 &&
                    selectedDays.contains(Weekday.saturday) &&
                    selectedDays.contains(Weekday.sunday),
                onTap: onSelectWeekends,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickSelectChip extends StatelessWidget {
  const _QuickSelectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final QuestCategory category;
  final bool isSelected;
  final Future<void> Function() onTap;

  Color _getColor(BuildContext context) {
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

  IconData _getIcon() {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor(context);

    return Material(
      color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color
                  : theme.colorScheme.onSurface.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                _getIcon(),
                color: isSelected
                    ? color
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                category.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? color
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnergySlider extends StatelessWidget {
  const _EnergySlider({
    required this.value,
    required this.onChanged,
  });

  final EnergyLevel value;
  final Future<void> Function(EnergyLevel) onChanged;

  Color _getColor(EnergyLevel level, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (level) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentColor = _getColor(value, context);

    return Column(
      children: [
        // Energy level buttons
        Row(
          children: EnergyLevel.values.map((level) {
            final isSelected = value == level;
            final levelColor = _getColor(level, context);

            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: level != EnergyLevel.intense ? 4 : 0,
                  ),
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? levelColor.withValues(alpha: 0.2)
                        : levelColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? levelColor
                          : levelColor.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${level.value}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isSelected
                            ? levelColor
                            : levelColor.withValues(alpha: 0.6),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: currentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(5, (index) {
                final isFilled = index < value.value;
                return Padding(
                  padding: EdgeInsets.only(right: index < 4 ? 3 : 0),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? currentColor
                          : currentColor.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                value.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: currentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RepeatButton extends StatelessWidget {
  const _RepeatButton({
    required this.repeat,
    required this.isSelected,
    required this.onTap,
  });

  final RepeatFrequency repeat;
  final bool isSelected;
  final Future<void> Function() onTap;

  IconData _getIcon() {
    switch (repeat) {
      case RepeatFrequency.none:
        return Icons.block_rounded;
      case RepeatFrequency.daily:
        return Icons.today_rounded;
      case RepeatFrequency.weekly:
        return Icons.date_range_rounded;
      case RepeatFrequency.monthly:
        return Icons.calendar_month_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Material(
      color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color
                  : theme.colorScheme.onSurface.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                _getIcon(),
                color: isSelected
                    ? color
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                repeat.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? color
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
