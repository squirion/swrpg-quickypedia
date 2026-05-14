import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/vehicle.dart';
import 'package:swrpg_quickypedia/models/vehicle_sort.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/widgets/vehicle_placeholder.dart';

class VehicleTile extends ConsumerWidget {
  final Vehicle vehicle;
  final VoidCallback onTap;

  const VehicleTile({
    super.key,
    required this.vehicle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rarity = _parseRarity(vehicle.rarity);
    final accent = _rarityColor(rarity);
    final glow = _rarityGlow(rarity, accent);
    final sort = ref.watch(vehicleSortProvider);

    final secondaryAttr = switch (sort.attr) {
      VehicleSortAttr.price ||
      VehicleSortAttr.rarity ||
      VehicleSortAttr.alphabetical =>
        null,
      _ => sort.attr,
    };
    final secondaryValue = secondaryAttr == null
        ? null
        : _displayValue(vehicle, secondaryAttr);

    final authHeaders = vehicle.imageUrl == null
        ? null
        : githubAuthHeadersFor(vehicle.imageUrl!, ref);

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
                  imageUrl: vehicle.imageUrl,
                  authHeaders: authHeaders,
                ),
                const _TopShade(),
                const _BottomShade(),
                Positioned(
                  top: 6,
                  left: 8,
                  right: 8,
                  child: Text(
                    vehicle.name,
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
                if (vehicle.price != null)
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: _PriceBadge(price: vehicle.price!),
                  ),
                if (secondaryAttr != null && secondaryValue != null)
                  Positioned(
                    bottom: 6,
                    left: 8,
                    child: _StatBadge(
                      label: secondaryAttr.shortLabel,
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
    final url = imageUrl;
    if (url == null || url.isEmpty) return const VehiclePlaceholder();
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: authHeaders,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: const Color(0xFF111827)),
      errorWidget: (_, _, _) => const VehiclePlaceholder(),
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

class _StatBadge extends StatelessWidget {
  final String label;
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

String? _displayValue(Vehicle v, VehicleSortAttr attr) => switch (attr) {
      VehicleSortAttr.rarity => v.rarity,
      VehicleSortAttr.price => v.price,
      VehicleSortAttr.silhouette => v.silhouette,
      VehicleSortAttr.speed => v.speed,
      VehicleSortAttr.handling => v.handling,
      VehicleSortAttr.armor => v.armor,
      VehicleSortAttr.hullTrauma => v.hullTrauma,
      VehicleSortAttr.encumbranceCapacity => v.encumbranceCapacity,
      VehicleSortAttr.passengerCapacity => v.passengerCapacity,
      VehicleSortAttr.alphabetical => null,
    };

int? _parseRarity(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'\d+').firstMatch(raw);
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}

Color _rarityColor(int? rarity) {
  if (rarity == null) return Colors.grey.shade600;
  if (rarity <= 1) return Colors.grey.shade400;
  if (rarity <= 3) return const Color(0xFF22C55E);
  if (rarity <= 5) return const Color(0xFF3B82F6);
  if (rarity <= 7) return const Color(0xFFA855F7);
  return const Color(0xFFF59E0B);
}

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
