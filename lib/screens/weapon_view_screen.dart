import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detail screen for a single weapon. Mirrors the bio-screen layout used
/// for characters but stays in its own file because the user wants to
/// tweak this view independently. Renders only the stat rows whose value
/// is non-null so different weapon classes (melee / ranged / lightsaber)
/// share one screen without forcing empty rows.
class WeaponViewScreen extends StatelessWidget {
  final Weapon weapon;
  const WeaponViewScreen({super.key, required this.weapon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statRows = <_StatRow>[
      _StatRow('Skill', weapon.skill),
      _StatRow('Damage', weapon.damage),
      _StatRow('Critical', weapon.critical),
      _StatRow('Range', weapon.range),
      _StatRow('Encumbrance', weapon.encumbrance),
      _StatRow('Hard Points', weapon.hardpoints),
      _StatRow('Price', weapon.price),
      _StatRow('Rarity', weapon.rarity),
    ].where((r) => r.value != null && r.value!.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: Text(weapon.name)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (weapon.imageUrl != null) _HeroImage(url: weapon.imageUrl!),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weapon.name,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (weapon.skill != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      Chip(
                        label: Text(weapon.skill!),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (statRows.isNotEmpty)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          for (final row in statRows) _StatLine(row: row),
                        ],
                      ),
                    ),
                  ),
                if (weapon.specialQualities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Special Qualities',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: [
                      for (final q in weapon.specialQualities)
                        Chip(
                          label: Text(q),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                if (weapon.description != null &&
                    weapon.description!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Description', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    weapon.description!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (weapon.sourceUrl != null) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _openWiki(context, weapon.sourceUrl!),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View on wiki'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWiki(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await canLaunchUrl(uri);
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the wiki page.')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _HeroImage extends StatelessWidget {
  final String url;
  const _HeroImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, _) => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, _, _) => const SizedBox(
          height: 200,
          child: Center(
            child: Icon(Icons.broken_image, size: 56, color: Colors.white24),
          ),
        ),
      ),
    );
  }
}

class _StatRow {
  final String label;
  final String? value;
  const _StatRow(this.label, this.value);
}

class _StatLine extends StatelessWidget {
  final _StatRow row;
  const _StatLine({required this.row});

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
              row.label,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              row.value ?? '',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
