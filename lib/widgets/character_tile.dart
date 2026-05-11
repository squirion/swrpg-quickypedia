import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:swrpg_quickypedia/models/character.dart';

class CharacterTile extends StatelessWidget {
  final Character character;
  final VoidCallback onTap;

  const CharacterTile({
    super.key,
    required this.character,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showOwner =
        character.isPlayerCharacter && character.author != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Avatar(url: character.avatarUrl),
              const _TopShadeOverlay(),
              Positioned(
                top: 6,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      character.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.1,
                        shadows: [
                          Shadow(blurRadius: 3, color: Colors.black87),
                        ],
                      ),
                    ),
                    if (showOwner)
                      Text(
                        character.author!.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          height: 1.1,
                          shadows: [
                            Shadow(blurRadius: 2, color: Colors.black87),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 40, color: Colors.grey.shade100),
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

class _TopShadeOverlay extends StatelessWidget {
  const _TopShadeOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
    );
  }
}
