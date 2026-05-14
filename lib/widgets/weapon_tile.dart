import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/models/weapon_sort.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/widgets/github_repo_image.dart';

class WeaponTile extends ConsumerWidget {
  final Weapon weapon;
  final VoidCallback onTap;

  const WeaponTile({
    super.key,
    required this.weapon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rarity = _parseRarity(weapon.rarity);
    final accent = _rarityColor(rarity);
    final glow = _rarityGlow(rarity, accent);
    final sort = ref.watch(weaponSortProvider);

    // Price is always shown bottom-right when known; when the user is
    // sorting by something other than price, we add that attribute's
    // value as a second badge in the bottom-left so the visual ordering
    // is justified. Rarity also skips the badge because the tile's
    // colored outline already conveys it.
    final secondaryAttr = switch (sort.attr) {
      WeaponSortAttr.price ||
      WeaponSortAttr.rarity ||
      WeaponSortAttr.alphabetical =>
        null,
      _ => sort.attr,
    };
    final secondaryValue = secondaryAttr == null
        ? null
        : _displayValue(weapon, secondaryAttr);

    final authHeaders = weapon.imageUrl == null
        ? null
        : githubAuthHeadersFor(weapon.imageUrl!, ref);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent, width: 2),
            boxShadow: glow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Background(
                  imageUrl: weapon.imageUrl,
                  authHeaders: authHeaders,
                ),
                const _TopShade(),
                const _BottomShade(),
                Positioned(
                  top: 6,
                  left: 8,
                  right: 8,
                  child: Text(
                    weapon.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.15,
                      shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
                    ),
                  ),
                ),
                if (weapon.price != null)
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: _PriceBadge(price: weapon.price!),
                  ),
                if (secondaryAttr != null && secondaryValue != null)
                  Positioned(
                    bottom: 6,
                    left: 8,
                    // Range values are already self-explanatory words
                    // ("Short", "Long", …), so skip the "RNG" prefix
                    // to save horizontal space on the tile.
                    child: _StatBadge(
                      label: secondaryAttr == WeaponSortAttr.range
                          ? null
                          : secondaryAttr.shortLabel,
                      value: secondaryValue,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  final String? imageUrl;
  final Map<String, String>? authHeaders;
  const _Background({this.imageUrl, this.authHeaders});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFF111827),
      alignment: Alignment.center,
      child: Icon(Icons.flash_on,
          size: 48, color: Colors.grey.shade700),
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;
    if (kIsWeb && authHeaders != null) {
      return GithubRepoImage(
        url: url,
        fit: BoxFit.cover,
        placeholder: Container(color: const Color(0xFF111827)),
        errorPlaceholder: fallback,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: authHeaders,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: const Color(0xFF111827)),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _TopShade extends StatelessWidget {
  const _TopShade();

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

class _BottomShade extends StatelessWidget {
  const _BottomShade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final String price;
  const _PriceBadge({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        price,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.amberAccent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Generic stat badge used for the secondary-sort value in the
/// bottom-left corner. When [label] is provided it shows as a small
/// leading 3-letter prefix (e.g. "DMG 7"); when omitted the badge is
/// just the value (e.g. "Long" for the range attribute).
class _StatBadge extends StatelessWidget {
  final String? label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            if (label != null)
              TextSpan(
                text: '$label ',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _displayValue(Weapon w, WeaponSortAttr attr) => switch (attr) {
      WeaponSortAttr.rarity => w.rarity,
      WeaponSortAttr.price => w.price,
      WeaponSortAttr.range => w.range,
      WeaponSortAttr.encumbrance => w.encumbrance,
      WeaponSortAttr.damage => w.damage,
      WeaponSortAttr.critical => w.critical,
      WeaponSortAttr.hardpoints => w.hardpoints,
      WeaponSortAttr.alphabetical => null,
    };

/// Extract a numeric rarity from strings like `"6"`, `"(R) 6"`, `"6 (R)"`,
/// or `"7+"`. Returns `null` when nothing parseable is present.
int? _parseRarity(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'\d+').firstMatch(raw);
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}

/// Borderlands-style rarity color buckets.
Color _rarityColor(int? rarity) {
  if (rarity == null) return Colors.grey.shade600;
  if (rarity <= 1) return Colors.grey.shade400;
  if (rarity <= 3) return const Color(0xFF22C55E); // green
  if (rarity <= 5) return const Color(0xFF3B82F6); // blue
  if (rarity <= 7) return const Color(0xFFA855F7); // purple
  return const Color(0xFFF59E0B); // orange
}

/// Glow scales with rarity — common items get no glow, legendary items
/// get a strong colored bloom. The shadow spreads outside the tile so
/// rarer items visually pop above their neighbours in the grid.
List<BoxShadow> _rarityGlow(int? rarity, Color accent) {
  if (rarity == null || rarity <= 1) return const [];
  final intensity = switch (rarity) {
    <= 3 => 0.30,
    <= 5 => 0.45,
    <= 7 => 0.60,
    _ => 0.80,
  };
  final blur = switch (rarity) {
    <= 3 => 6.0,
    <= 5 => 10.0,
    <= 7 => 14.0,
    _ => 18.0,
  };
  return [
    BoxShadow(
      color: accent.withValues(alpha: intensity),
      blurRadius: blur,
      spreadRadius: 1,
    ),
  ];
}
