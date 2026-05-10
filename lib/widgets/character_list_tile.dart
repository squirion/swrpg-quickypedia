import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:swrpg_quickypedia/models/character.dart';

class CharacterListTile extends StatelessWidget {
  final Character character;

  const CharacterListTile({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: character.avatarUrl != null
              ? CachedNetworkImageProvider(character.avatarUrl!)
              : null,
          child:
              character.avatarUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Text(
          character.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _RoleBadge(isPC: character.isPlayerCharacter),
            if (character.isGameMasterOnly)
              Chip(
                label: const Text('GM Only'),
                labelStyle: const TextStyle(fontSize: 10),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.red.shade100,
              ),
            ...character.tags.map(
              (tag) => Chip(
                label: Text(tag),
                labelStyle: const TextStyle(fontSize: 10),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        trailing: character.author != null
            ? Text(
                character.author!.username,
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final bool isPC;

  const _RoleBadge({required this.isPC});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(isPC ? 'PC' : 'NPC'),
      labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: isPC ? Colors.blue.shade100 : Colors.orange.shade100,
    );
  }
}
