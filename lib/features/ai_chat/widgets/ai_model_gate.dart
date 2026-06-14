import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/gemma_service.dart';
import 'package:focus_quest/features/ai_chat/providers/gemma_model_provider.dart';

/// Full-screen state shown on the AI tab when the model isn't ready to chat:
/// a download call-to-action, live download progress, or an error with retry.
class AiModelGate extends ConsumerWidget {
  const AiModelGate({required this.state, super.key});

  final GemmaModelState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(gemmaModelProvider.notifier);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            switch (state) {
              GemmaDownloading(:final progress) => _DownloadingView(
                progress: progress,
                onCancel: notifier.cancelDownload,
              ),
              GemmaModelError(:final message) => _MessageView(
                title: 'Something went wrong',
                body: message,
                actionLabel: 'Try again',
                onAction: notifier.download,
              ),
              _ => _MessageView(
                title: 'On-device AI assistant',
                body:
                    'Download the AI model ($kGemmaModelSizeLabel) to chat '
                    'privately and turn conversations into journal entries. '
                    'Everything runs on your device — no data leaves it.',
                actionLabel: 'Download model',
                onAction: notifier.download,
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.download_rounded),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _DownloadingView extends StatelessWidget {
  const _DownloadingView({required this.progress, required this.onCancel});

  final int progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Downloading model…',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress / 100 : null,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$progress%  •  $kGemmaModelSizeLabel',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    );
  }
}
