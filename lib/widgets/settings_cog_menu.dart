import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';

/// AppBar settings menu surfacing the less-frequent cloud actions —
/// Push to cloud + Test connection. Pull lives in a dedicated button
/// next to this one. Only mounted on the home AppBar; type/grid
/// screens don't need it.
class SettingsCogMenu extends ConsumerWidget {
  const SettingsCogMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudSyncProvider);
    final busy = cloud is CloudSyncRunning;
    return PopupMenuButton<String>(
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
      onSelected: (action) => switch (action) {
        'push' => _pushCloud(context, ref),
        'test' => _testCloud(context, ref),
        _ => null,
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'push',
          child: ListTile(
            leading: Icon(Icons.cloud_upload_outlined),
            title: Text('Push to cloud'),
            subtitle: Text('Share local with cloud'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'test',
          child: ListTile(
            leading: Icon(Icons.cloud_done_outlined),
            title: Text('Test connection'),
          ),
        ),
      ],
    );
  }

  Future<void> _pushCloud(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Pushing databases to cloud…')),
    );
    final result = await ref.read(cloudSyncProvider.notifier).pushDatabases();
    if (!context.mounted) return;
    _showSyncResult(context, result);
  }

  Future<void> _testCloud(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(githubDataRepoProvider);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Checking cloud connection…')),
    );
    final result = await repo.healthCheck();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result.ok ? 'Cloud OK' : 'Cloud unreachable'),
        content: SingleChildScrollView(child: Text(result.detail)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSyncResult(BuildContext context, CloudSyncResult result) {
    final summary = result.errors.isEmpty
        ? 'Pushed ${result.succeeded} '
            '${result.succeeded == 1 ? 'file' : 'files'}'
            '${result.skipped > 0 ? ' (${result.skipped} skipped)' : ''}.'
        : 'Some files failed:\n${result.errors.join('\n')}';
    if (result.errors.isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cloud push report'),
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
