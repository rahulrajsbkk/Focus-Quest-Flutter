import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/haptic_service.dart';
import 'package:focus_quest/features/ai_chat/models/chat_message.dart';
import 'package:focus_quest/features/ai_chat/providers/chat_provider.dart';
import 'package:focus_quest/features/ai_chat/providers/gemma_model_provider.dart';
import 'package:focus_quest/features/ai_chat/providers/journal_inference_provider.dart';
import 'package:focus_quest/features/ai_chat/widgets/ai_model_gate.dart';
import 'package:focus_quest/features/ai_chat/widgets/chat_bubble.dart';
import 'package:focus_quest/features/ai_chat/widgets/chat_input_bar.dart';
import 'package:focus_quest/features/ai_chat/widgets/typing_indicator.dart';
import 'package:focus_quest/features/journal/screens/daily_reflection_screen.dart';
import 'package:focus_quest/models/journal_draft.dart';

/// The AI assistant tab. Only mounted when the device supports the model
/// (see MainScreen). Shows a download/loading gate until the model file is
/// present, then the chat UI.
class AiChatScreen extends ConsumerWidget {
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(gemmaModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        centerTitle: true,
        actions: const [_ChatActions()],
      ),
      body: modelState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AiModelGate(
          state: GemmaModelError(e.toString()),
        ),
        data: (state) => switch (state) {
          GemmaInstalled() => const _ChatView(),
          _ => AiModelGate(state: state),
        },
      ),
    );
  }
}

/// AppBar actions (create journal + clear) — only meaningful in the chat view.
class _ChatActions extends ConsumerWidget {
  const _ChatActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelReady = ref.watch(
      gemmaModelProvider.select(
        (s) => s.asData?.value is GemmaInstalled,
      ),
    );
    if (!modelReady) return const SizedBox.shrink();

    final chat = ref.watch(chatProvider);
    final hasMessages = chat.messages.isNotEmpty;

    return Row(
      children: [
        IconButton(
          tooltip: 'Create journal from chat',
          icon: const Icon(Icons.auto_awesome_rounded),
          onPressed: chat.isBusy ? null : () => _createJournal(context, ref),
        ),
        IconButton(
          tooltip: 'Clear chat',
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: hasMessages && !chat.isBusy
              ? () => ref.read(chatProvider.notifier).clearChat()
              : null,
        ),
      ],
    );
  }

  Future<void> _createJournal(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(chatProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (ref.read(chatProvider).completedMessageCount < 2) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Chat a little more first, then I can summarize it.'),
        ),
      );
      return;
    }

    unawaited(HapticService().mediumImpact());
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ReadingDialog(),
      ),
    );

    JournalDraft? draft;
    try {
      draft = await ref
          .read(journalInferenceProvider)
          .infer(notifier.buildTranscript());
    } on Object {
      draft = null;
    }

    if (navigator.canPop()) navigator.pop(); // close the reading dialog

    if (draft == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't read that — try again, or fill the reflection in "
            'manually.',
          ),
        ),
      );
      return;
    }

    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => DailyReflectionScreen(
          date: DateTime.now(),
          prefill: draft,
        ),
      ),
    );
  }
}

class _ReadingDialog extends StatelessWidget {
  const _ReadingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 16),
          Expanded(child: Text('Reading your chat…')),
        ],
      ),
    );
  }
}

class _ChatView extends ConsumerWidget {
  const _ChatView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider);
    final messages = state.messages;

    ref.listen(chatProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
      }
    });

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[messages.length - 1 - i];
                    if (m.role == ChatRole.assistant &&
                        m.isStreaming &&
                        m.text.isEmpty) {
                      return const TypingIndicator();
                    }
                    return ChatBubble(message: m);
                  },
                ),
        ),
        if (state.isPreparing) const _PreparingBanner(),
        ChatInputBar(
          enabled: !state.isBusy,
          onSend: (text) {
            unawaited(HapticService().selectionClick());
            unawaited(ref.read(chatProvider.notifier).send(text));
          },
        ),
      ],
    );
  }
}

class _PreparingBanner extends StatelessWidget {
  const _PreparingBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        'Waking up the assistant… (the first reply can take a moment)',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Tell me about your day',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Chat about wins, distractions, and how you feel — then tap '
              '✨ to turn it into a journal entry.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
