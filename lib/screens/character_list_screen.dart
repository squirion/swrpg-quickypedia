import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/campaign_input_screen.dart';
import 'package:swrpg_quickypedia/widgets/character_list_tile.dart';

class CharacterListScreen extends ConsumerWidget {
  const CharacterListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(charactersProvider);
    final campaignId = ref.watch(campaignIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Characters — $campaignId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Change campaign',
            onPressed: () {
              ref.read(campaignIdProvider.notifier).setCampaign(null);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const CampaignInputScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () {
              ref.read(authStateProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: characters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load characters:\n$error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(charactersProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (characterList) {
          if (characterList.isEmpty) {
            return const Center(
              child: Text('No characters found in this campaign.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(charactersProvider);
              await ref.read(charactersProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: characterList.length,
              itemBuilder: (context, index) {
                return CharacterListTile(character: characterList[index]);
              },
            ),
          );
        },
      ),
    );
  }
}
