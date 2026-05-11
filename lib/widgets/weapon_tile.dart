import 'package:flutter/material.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';

class WeaponTile extends StatelessWidget {
  final Weapon weapon;
  final VoidCallback onTap;

  const WeaponTile({
    super.key,
    required this.weapon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = _skillColor(weapon.skill);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Text(
                  weapon.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.15,
                    shadows: [
                      Shadow(blurRadius: 3, color: Colors.black87),
                    ],
                  ),
                ),
              ),
              if (weapon.damage != null || weapon.skill != null)
                _StatStrip(
                  skill: _skillShortLabel(weapon.skill),
                  damage: weapon.damage,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  final String? skill;
  final String? damage;
  const _StatStrip({this.skill, this.damage});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (skill != null) _Badge(text: skill!),
        if (damage != null) _Badge(text: 'D$damage'),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Map a weapon's `skill` to a tile background color so the grid is visually
/// scannable without per-weapon images. Unknown / null skills fall back to
/// a neutral blue-grey.
Color _skillColor(String? skill) {
  final s = skill?.toLowerCase() ?? '';
  if (s.contains('ranged (heavy)') || s.contains('gunnery')) {
    return const Color(0xFF1F3A5F);
  }
  if (s.contains('ranged (light)') || s.contains('ranged')) {
    return const Color(0xFF2563EB);
  }
  if (s.contains('lightsaber')) {
    return const Color(0xFF5B21B6);
  }
  if (s.contains('melee')) {
    return const Color(0xFF991B1B);
  }
  if (s.contains('brawl')) {
    return const Color(0xFFB45309);
  }
  return Colors.blueGrey.shade700;
}

/// Strip the parenthesised qualifier from skill labels so the badge fits
/// (e.g. "Ranged (Light)" → "Ranged").
String? _skillShortLabel(String? skill) {
  if (skill == null) return null;
  final paren = skill.indexOf('(');
  if (paren < 0) return skill.trim();
  return skill.substring(0, paren).trim();
}
