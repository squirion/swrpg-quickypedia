import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/campaign.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/home_screen.dart';

class CampaignInputScreen extends ConsumerStatefulWidget {
  const CampaignInputScreen({super.key});

  @override
  ConsumerState<CampaignInputScreen> createState() =>
      _CampaignInputScreenState();
}

class _CampaignInputScreenState extends ConsumerState<CampaignInputScreen> {
  // Used only when falling back to manual entry
  final _controller = TextEditingController();
  Campaign? _selectedCampaign;
  bool _isNavigating = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _restoreLastCampaign();
  }

  Future<void> _restoreLastCampaign() async {
    final lastId = await CampaignStorage.load();
    if (lastId != null && mounted) {
      _controller.text = lastId;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(String campaignId, String campaignName) async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
      _submitError = null;
    });

    try {
      ref.read(campaignIdProvider.notifier).setCampaign(campaignId);
      await CampaignStorage.save(campaignId);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _submitError = 'Could not open campaign: $e';
        _isNavigating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(campaignsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Campaign'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authStateProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map, size: 64, color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text(
                'Select your Campaign',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (_submitError != null) ...[
                Text(
                  _submitError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              campaignsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => _ManualEntryFallback(
                  controller: _controller,
                  isLoading: _isNavigating,
                  onSubmit: () {
                    final id = _controller.text.trim();
                    if (id.isNotEmpty) _open(id, id);
                  },
                  errorMessage:
                      'Could not load your campaigns automatically.\n'
                      'Please enter your campaign ID or slug manually.',
                ),
                data: (campaigns) {
                  if (campaigns.isEmpty) {
                    return _ManualEntryFallback(
                      controller: _controller,
                      isLoading: _isNavigating,
                      onSubmit: () {
                        final id = _controller.text.trim();
                        if (id.isNotEmpty) _open(id, id);
                      },
                      errorMessage: 'No campaigns found. Enter manually:',
                    );
                  }
                  return _CampaignDropdown(
                    campaigns: campaigns,
                    selected: _selectedCampaign,
                    isLoading: _isNavigating,
                    onChanged: (c) => setState(() => _selectedCampaign = c),
                    onOpen: () {
                      if (_selectedCampaign != null) {
                        _open(_selectedCampaign!.id, _selectedCampaign!.name);
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignDropdown extends StatelessWidget {
  final List<Campaign> campaigns;
  final Campaign? selected;
  final bool isLoading;
  final ValueChanged<Campaign?> onChanged;
  final VoidCallback onOpen;

  const _CampaignDropdown({
    required this.campaigns,
    required this.selected,
    required this.isLoading,
    required this.onChanged,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Column(
        children: [
          DropdownButtonFormField<Campaign>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Campaign',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Choose a campaign…'),
            items: campaigns
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: (selected == null || isLoading) ? null : onOpen,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward),
            label: const Text('Open Campaign'),
          ),
        ],
      ),
    );
  }
}

class _ManualEntryFallback extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;
  final String errorMessage;

  const _ManualEntryFallback({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Column(
        children: [
          Text(
            errorMessage,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Campaign ID or slug',
              border: OutlineInputBorder(),
              hintText: 'e.g. my-campaign-slug',
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isLoading ? null : onSubmit,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward),
            label: const Text('Load Campaign'),
          ),
        ],
      ),
    );
  }
}
