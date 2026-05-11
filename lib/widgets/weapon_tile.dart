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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade700,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          child: Text(
            weapon.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}
