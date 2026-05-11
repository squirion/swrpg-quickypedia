import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:swrpg_quickypedia/models/character.dart';

class CharacterBioScreen extends StatelessWidget {
  final Character character;

  const CharacterBioScreen({super.key, required this.character});

  static String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(character.name)),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: _HeroImage(url: character.avatarUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(character.name, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        character.isPlayerCharacter ? 'PC' : 'NPC',
                      ),
                      backgroundColor: character.isPlayerCharacter
                          ? Colors.blue.shade100
                          : Colors.orange.shade100,
                    ),
                    if (character.isGameMasterOnly)
                      Chip(
                        label: const Text('GM Only'),
                        backgroundColor: Colors.red.shade100,
                      ),
                    ...character.tags.map((tag) => Chip(label: Text(tag))),
                  ],
                ),
                const SizedBox(height: 24),
                if (character.author != null)
                  _InfoRow(
                    label: 'Played by',
                    value: character.author!.username,
                  ),
                if (character.campaign != null)
                  _InfoRow(
                    label: 'Campaign',
                    value: character.campaign!.name,
                  ),
                _InfoRow(label: 'Visibility', value: character.visibility),
                _InfoRow(
                  label: 'Created',
                  value: _formatDate(character.createdAt),
                ),
                _InfoRow(
                  label: 'Updated',
                  value: _formatDate(character.updatedAt),
                ),
                if (character.characterUrl != null) ...[
                  const SizedBox(height: 24),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View on Obsidian Portal'),
                    onPressed: () async {
                      final uri = Uri.parse(character.characterUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String? url;
  const _HeroImage({this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 120, color: Colors.grey.shade100),
    );
    if (url == null || url!.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: Colors.grey.shade200),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
