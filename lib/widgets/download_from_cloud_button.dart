import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';

/// AppBar action that pulls every cloud-backed database in one tap.
///
/// While the pull is running the icon swaps to a small spinner; on
/// completion a snackbar reports the count, and per-file errors fall
/// out into a dialog (handled by [_showSyncResult]). The widget is
/// safe to drop into any screen's AppBar — the shared
/// [cloudSyncProvider] state means concurrent taps from different
/// screens won't double-trigger.
class DownloadFromCloudButton extends ConsumerWidget {
  const DownloadFromCloudButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncProvider);
    final pulling = state is CloudSyncRunning && state.direction == 'pull';
    return IconButton(
      tooltip: 'Download from cloud',
      icon: pulling
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_download_outlined),
      onPressed: pulling ? null : () => _pull(context, ref),
    );
  }

  Future<void> _pull(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Downloading databases from cloud…')),
    );
    final result = await ref.read(cloudSyncProvider.notifier).pullDatabases();
    if (!context.mounted) return;
    _showSyncResult(context, result);
  }

  void _showSyncResult(BuildContext context, CloudSyncResult result) {
    final summary = result.errors.isEmpty
        ? 'Pulled ${result.succeeded} '
            '${result.succeeded == 1 ? 'file' : 'files'}'
            '${result.skipped > 0 ? ' (${result.skipped} skipped)' : ''}.'
        : 'Some files failed:\n${result.errors.join('\n')}';
    if (result.errors.isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cloud download report'),
          content: SingleChildScrollView(child: Text(summary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(summary)));
    }
  }
}
