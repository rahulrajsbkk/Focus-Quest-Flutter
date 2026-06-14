import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/haptic_service.dart';
import 'package:focus_quest/features/journal/providers/journal_provider.dart';
import 'package:focus_quest/features/journal/widgets/mood_selector.dart';
import 'package:focus_quest/models/journal_draft.dart';
import 'package:focus_quest/models/journal_entry.dart';
import 'package:intl/intl.dart';

class DailyReflectionScreen extends ConsumerStatefulWidget {
  const DailyReflectionScreen({
    required this.date,
    this.prefill,
    super.key,
  });

  final DateTime date;

  /// Optional pre-filled values (e.g. inferred by the AI assistant). A saved
  /// entry for [date] always takes precedence over this draft.
  final JournalDraft? prefill;

  @override
  ConsumerState<DailyReflectionScreen> createState() =>
      _DailyReflectionScreenState();
}

class _DailyReflectionScreenState extends ConsumerState<DailyReflectionScreen> {
  String? _selectedMood;
  final _winController = TextEditingController();
  final _distractionController = TextEditingController();
  final _improvementController = TextEditingController();
  final _brainDumpController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Apply any AI-inferred draft up front so the form is pre-filled. The
    // post-frame _loadEntry below overrides it only if a saved entry exists
    // for this date (real data always wins over a draft).
    final prefill = widget.prefill;
    if (prefill != null) {
      _selectedMood = prefill.mood;
      _winController.text = prefill.biggestWin;
      _distractionController.text = prefill.mainDistraction;
      _improvementController.text = prefill.improvementForTomorrow;
      _brainDumpController.text = prefill.freeFlowEntry;
    }
    // Check if there is already an entry for the selected date
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadEntry();
    });
  }

  Future<void> _loadEntry() async {
    final entry = await ref
        .read(journalRepositoryProvider)
        .getEntryForDate(widget.date);
    if (entry != null && mounted) {
      setState(() {
        _selectedMood = entry.mood;
        _winController.text = entry.biggestWin;
        _distractionController.text = entry.mainDistraction;
        _improvementController.text = entry.improvementForTomorrow;
        _brainDumpController.text = entry.freeFlowEntry ?? '';
      });
    }
  }

  @override
  void dispose() {
    _winController.dispose();
    _distractionController.dispose();
    _improvementController.dispose();
    _brainDumpController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (_selectedMood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mood for the day.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    unawaited(HapticService().heavyImpact());

    try {
      final repository = ref.read(journalRepositoryProvider);

      // Check for existing ID to update, or create new
      var id = repository.generateId();
      final existingEntry = await repository.getEntryForDate(widget.date);
      if (existingEntry != null) {
        id = existingEntry.id;
      }

      final entry = JournalEntry(
        id: id,
        date: widget.date,
        mood: _selectedMood!,
        biggestWin: _winController.text.trim(),
        mainDistraction: _distractionController.text.trim(),
        improvementForTomorrow: _improvementController.text.trim(),
        freeFlowEntry: _brainDumpController.text.trim(),
        createdAt: existingEntry?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Use the notifier to update state and save
      if (existingEntry != null) {
        await ref.read(journalProvider.notifier).updateEntry(entry);
      } else {
        await ref.read(journalProvider.notifier).addEntry(entry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reflection saved!')),
        );
        Navigator.pop(context);
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving reflection: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('EEEE, MMMM d').format(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Reflection'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              dateStr,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Take a moment to reflect on this day.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Mood Selector
            Text(
              'How was your day?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            MoodSelector(
              selectedMood: _selectedMood,
              onMoodSelected: (mood) {
                unawaited(HapticService().lightImpact());
                setState(() => _selectedMood = mood);
              },
            ),
            const SizedBox(height: 32),

            // Questions
            _buildQuestion(
              title: 'Biggest Win',
              description: 'What went well today?',
              controller: _winController,
              icon: Icons.emoji_events_outlined,
            ),
            const SizedBox(height: 24),
            _buildQuestion(
              title: 'Main Distraction',
              description: 'What pulled you away?',
              controller: _distractionController,
              icon: Icons.timer_off_outlined,
            ),
            const SizedBox(height: 24),
            _buildQuestion(
              title: "Tomorrow's Improvement",
              description: 'One thing to do differently?',
              controller: _improvementController,
              icon: Icons.trending_up,
            ),

            const SizedBox(height: 32),

            // Brain Dump (Optional)
            Text(
              'Brain Dump (Optional)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _brainDumpController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Anything else on your mind? Park it here.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveEntry,
                icon: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSaving ? 'Saving...' : 'Save Reflection'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion({
    required String title,
    required String description,
    required TextEditingController controller,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          maxLines: null,
          decoration: InputDecoration(
            hintText: 'Type here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}
