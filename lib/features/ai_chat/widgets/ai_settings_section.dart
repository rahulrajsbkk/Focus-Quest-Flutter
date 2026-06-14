import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/device_capability_service.dart';
import 'package:focus_quest/core/services/gemma_service.dart';
import 'package:focus_quest/features/ai_chat/providers/gemma_model_provider.dart';

/// Settings card for managing the on-device AI model (download / delete /
/// status). Hidden entirely on devices that can't run the model.
class AiSettingsSection extends ConsumerWidget {
  const AiSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(deviceCapabilityProvider);

    // While the capability check resolves, render nothing to avoid flicker.
    final supported = capability.asData?.value.aiSupported ?? false;
    if (!supported) {
      final reason = capability.asData?.value.reason;
      if (reason == null) return const SizedBox.shrink();
      return _Section(
        child: Card(
          elevation: 6,
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: _iconBox(
              context,
              Icons.psychology_outlined,
              Colors.grey,
            ),
            title: const Text('AI Assistant'),
            subtitle: Text(reason),
            enabled: false,
          ),
        ),
      );
    }

    final modelState = ref.watch(gemmaModelProvider);
    final notifier = ref.read(gemmaModelProvider.notifier);

    return _Section(
      child: Card(
        elevation: 6,
        margin: EdgeInsets.zero,
        child: switch (modelState.asData?.value) {
          GemmaDownloading(:final progress) => _DownloadingTile(
            progress: progress,
            onCancel: notifier.cancelDownload,
          ),
          GemmaInstalled() => _InstalledTile(
            onDelete: () => _confirmDelete(context, notifier),
          ),
          GemmaModelError(:final message) => _ActionTile(
            icon: Icons.error_outline_rounded,
            color: Colors.red,
            title: 'AI Assistant',
            subtitle: message,
            actionIcon: Icons.refresh_rounded,
            onAction: notifier.download,
          ),
          _ => _ActionTile(
            icon: Icons.psychology_rounded,
            color: const Color(0xFF4DB6AC),
            title: 'AI Assistant',
            subtitle:
                'Download the model ($kGemmaModelSizeLabel) to chat '
                'and auto-write journals — fully on-device.',
            actionIcon: Icons.download_rounded,
            onAction: notifier.download,
          ),
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    GemmaModelNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete AI model?'),
        content: const Text(
          'This frees up storage. You can download it again anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await notifier.deleteModel();
    }
  }

  static Widget _iconBox(BuildContext context, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'ASSISTANT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.actionIcon,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AiSettingsSection._iconBox(context, icon, color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: IconButton(
        icon: Icon(actionIcon),
        onPressed: onAction,
      ),
      isThreeLine: true,
    );
  }
}

class _InstalledTile extends StatelessWidget {
  const _InstalledTile({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AiSettingsSection._iconBox(
        context,
        Icons.psychology_rounded,
        const Color(0xFF7A9E7E),
      ),
      title: const Text('AI Assistant'),
      subtitle: const Text('Model installed ($kGemmaModelSizeLabel)'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded),
        tooltip: 'Delete model',
        onPressed: onDelete,
      ),
    );
  }
}

class _DownloadingTile extends StatelessWidget {
  const _DownloadingTile({required this.progress, required this.onCancel});

  final int progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: AiSettingsSection._iconBox(
        context,
        Icons.downloading_rounded,
        const Color(0xFF4DB6AC),
      ),
      title: const Text('Downloading AI model…'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress > 0 ? progress / 100 : null,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
          ),
        ),
      ),
      trailing: TextButton(
        onPressed: onCancel,
        child: const Text('Cancel'),
      ),
    );
  }
}
