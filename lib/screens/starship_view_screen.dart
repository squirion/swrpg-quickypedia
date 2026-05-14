import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/item_quality.dart';
import 'package:swrpg_quickypedia/models/starship.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/services/starship_image_upload.dart';
import 'package:swrpg_quickypedia/theme.dart';
import 'package:swrpg_quickypedia/widgets/defense_diamond.dart';
import 'package:swrpg_quickypedia/widgets/fullscreen_image_viewer.dart';
import 'package:swrpg_quickypedia/widgets/github_repo_image.dart';
import 'package:swrpg_quickypedia/widgets/image_upload_surface.dart';
import 'package:swrpg_quickypedia/widgets/item_detail_layout.dart';
import 'package:swrpg_quickypedia/widgets/starship_placeholder.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detail screen for a single starship. Extends the vehicle layout
/// with Hyperdrive / Navicomputer / Sensors / Complement / Consumables
/// / HP / Price / Rarity capsules + Hull Type/Class and Manufacturer
/// label-value rows (those are long strings, not numbers, so they
/// don't fit the capsule format).
class StarshipViewScreen extends ConsumerWidget {
  final Starship starship;
  const StarshipViewScreen({super.key, required this.starship});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualitiesAsync = ref.watch(itemQualitiesProvider);
    final qualities = qualitiesAsync.asData?.value ?? const {};

    final all =
        ref.watch(starshipsProvider).asData?.value ?? const <Starship>[];
    final live = all.firstWhere(
      (s) => s.name == starship.name,
      orElse: () => starship,
    );

    final hasMechanics = live.mechanics != null && live.mechanics!.isNotEmpty;
    final hasSpecial = live.specialQualities.isNotEmpty;
    final showMechanicsSection = hasMechanics || hasSpecial;
    final hasWeapons = live.weapons != null && live.weapons!.isNotEmpty;
    final hasIdentity =
        (live.hullTypeClass != null && live.hullTypeClass!.isNotEmpty) ||
            (live.manufacturer != null && live.manufacturer!.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: Text(live.name)),
      body: ItemDetailLayout(
        crumbs: _Crumbs(name: live.name, category: live.category),
        hero: _Hero(starship: live),
        firstSectionHeading:
            const _SectionHeading(number: '01', title: 'Specifications'),
        firstSectionBody: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatBlock(starship: live),
            if (hasIdentity) ...[
              const SizedBox(height: 18),
              _IdentityRows(starship: live),
            ],
            if (hasWeapons) ...[
              const SizedBox(height: 18),
              _ArmamentsPanel(text: live.weapons!),
            ],
          ],
        ),
        restSections: [
          if (showMechanicsSection) ...[
            const SizedBox(height: 28),
            const _SectionHeading(number: '02', title: 'Game Mechanics'),
            const SizedBox(height: 14),
            _MechanicsSection(
              specialQualities: live.specialQualities,
              prose: live.mechanics,
              qualities: qualities,
            ),
          ],
          if (live.sourceUrl != null) ...[
            const SizedBox(height: 28),
            const _SectionHeading(number: '03', title: 'Reference'),
            const SizedBox(height: 14),
            _SourceLink(url: live.sourceUrl!),
          ],
        ],
      ),
    );
  }
}

// ── Crumbs ──────────────────────────────────────────────────────────────

class _Crumbs extends StatelessWidget {
  final String name;
  final String? category;
  const _Crumbs({required this.name, this.category});

  @override
  Widget build(BuildContext context) {
    Widget seg(String text) => Text(
          text,
          style: AppFonts.display(
            const TextStyle(
              fontSize: 11,
              letterSpacing: 1.7,
              color: AppColors.inkFaint,
            ),
          ).copyWith(height: 1),
        );
    Widget sep() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('›',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.18),
                fontSize: 12,
              )),
        );
    return Row(
      children: [
        seg('ARMORY'),
        sep(),
        seg('STARSHIPS'),
        if (category != null) ...[
          sep(),
          Flexible(
            child: Text(
              category!.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.display(
                const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.7,
                  color: AppColors.inkFaint,
                ),
              ).copyWith(height: 1),
            ),
          ),
        ],
        sep(),
        Flexible(
          child: Text(
            name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.display(
              const TextStyle(
                fontSize: 11,
                letterSpacing: 1.7,
                color: AppColors.inkDim,
              ),
            ).copyWith(height: 1),
          ),
        ),
      ],
    );
  }
}

// ── Hero ────────────────────────────────────────────────────────────────

class _Hero extends ConsumerWidget {
  final Starship starship;
  const _Hero({required this.starship});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage =
        starship.imageUrl != null && starship.imageUrl!.isNotEmpty;
    final authHeaders =
        hasImage ? githubAuthHeadersFor(starship.imageUrl!, ref) : null;

    final panel = AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lineStrong),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 60,
              offset: Offset(0, 30),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!hasImage)
                const StarshipPlaceholder()
              else
                Hero(
                  tag: starship.imageUrl!,
                  child: kIsWeb && authHeaders != null
                      ? GithubRepoImage(
                          url: starship.imageUrl!,
                          fit: BoxFit.contain,
                          placeholder:
                              const ColoredBox(color: AppColors.bg2),
                          errorPlaceholder: const StarshipPlaceholder(),
                        )
                      : CachedNetworkImage(
                          imageUrl: starship.imageUrl!,
                          httpHeaders: authHeaders,
                          fit: BoxFit.contain,
                          placeholder: (_, _) =>
                              const ColoredBox(color: AppColors.bg2),
                          errorWidget: (_, _, _) =>
                              const StarshipPlaceholder(),
                        ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black,
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: _HeroOverlay(starship: starship),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _EditImageButton(starship: starship),
              ),
              const _CornerBracket(alignment: Alignment.topLeft),
              const _CornerBracket(alignment: Alignment.bottomLeft),
              const _CornerBracket(alignment: Alignment.bottomRight),
            ],
          ),
        ),
      ),
    );

    final tappable = !hasImage
        ? panel
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FullscreenImageViewer.open(
              context,
              imageUrl: starship.imageUrl!,
              httpHeaders: authHeaders,
              heroTag: starship.imageUrl!,
            ),
            child: panel,
          );

    return ImageUploadSurface(
      onBytes: (bytes) => _runStarshipUpload(
        context,
        ref,
        (u) => u.upload(starship: starship, bytes: bytes),
      ),
      onUrl: (url) => _runStarshipUpload(
        context,
        ref,
        (u) => u.uploadFromUrl(starship: starship, url: url),
      ),
      child: tappable,
    );
  }
}

Future<void> _runStarshipUpload(
  BuildContext context,
  WidgetRef ref,
  Future<String> Function(StarshipImageUploader uploader) action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Uploading image…')),
  );
  try {
    final uploader = ref.read(starshipImageUploaderProvider);
    await action(uploader);
    ref.invalidate(starshipsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image uploaded.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Upload failed: $e')),
    );
  }
}

class _EditImageButton extends ConsumerWidget {
  final Starship starship;
  const _EditImageButton({required this.starship});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.accent, width: 1),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => ImageUploadSurface.showUploadSheet(
          context,
          onBytes: (bytes) => _runStarshipUpload(
            context,
            ref,
            (u) => u.upload(starship: starship, bytes: bytes),
          ),
          onUrl: (url) => _runStarshipUpload(
            context,
            ref,
            (u) => u.uploadFromUrl(starship: starship, url: url),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.edit, size: 16, color: AppColors.accent),
        ),
      ),
    );
  }
}

class _HeroOverlay extends StatelessWidget {
  final Starship starship;
  const _HeroOverlay({required this.starship});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (starship.category != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              starship.category!.toUpperCase(),
              style: AppFonts.display(
                const TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.2,
                  color: AppColors.accent,
                  height: 1,
                ),
              ),
            ),
          ),
        Text(
          starship.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.display(
            const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.05,
              letterSpacing: -0.2,
              color: AppColors.ink,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
        if (starship.description != null &&
            starship.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            starship.description!.split('\n\n').first,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.inkDim,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final Alignment alignment;
  const _CornerBracket({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final top = alignment.y < 0;
    final left = alignment.x < 0;
    final border = BorderSide(
      color: AppColors.accent.withValues(alpha: 0.7),
      width: 1,
    );
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: 18,
          height: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: top ? border : BorderSide.none,
                bottom: top ? BorderSide.none : border,
                left: left ? border : BorderSide.none,
                right: left ? BorderSide.none : border,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section heading ─────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  final String number;
  final String title;
  const _SectionHeading({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          number,
          style: AppFonts.mono(
            const TextStyle(
              fontSize: 11,
              color: AppColors.accent,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.display(
              const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 3.0,
                color: AppColors.inkDim,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.lineStrong, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stat block ──────────────────────────────────────────────────────────

class _StatBlock extends StatelessWidget {
  final Starship starship;
  const _StatBlock({required this.starship});

  @override
  Widget build(BuildContext context) {
    final capacity = <(String, String?)>[
      ('HULL', starship.hullTrauma),
      ('STRAIN', starship.systemStrain),
      ('ENC CAP', starship.encumbranceCapacity),
      ('PAX', starship.passengerCapacity),
    ];
    final logistics = <(String, String?)>[
      ('HYPER', starship.hyperdrive),
      ('NAVI', starship.navicomputer),
      ('SENSORS', starship.sensorRange),
      ('COMPL', starship.shipsComplement),
      ('CONSUM', starship.consumables),
      ('HP', starship.hardpoints),
    ];
    final commerce = <(String, String?)>[
      ('PRICE', starship.price),
      ('RARITY', starship.rarity),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Color(0x05FFFFFF), Colors.transparent],
        ),
        color: const Color(0xFF181D25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lineStrong),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _StatHex(label: 'SIL', value: starship.silhouette),
              ),
              Expanded(
                child: _StatHex(label: 'SPEED', value: starship.speed),
              ),
              Expanded(
                child: _StatHex(label: 'HNDL', value: starship.handling),
              ),
              Expanded(
                child: _StatHex(label: 'ARMOR', value: starship.armor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DefenseDiamond(
            fore: starship.defenseFore,
            port: starship.defensePort,
            starboard: starship.defenseStarboard,
            aft: starship.defenseAft,
          ),
          const SizedBox(height: 14),
          _CapsuleRow(items: capacity),
          const SizedBox(height: 10),
          _CapsuleRow(items: logistics),
          const SizedBox(height: 10),
          _CapsuleRow(items: commerce),
        ],
      ),
    );
  }
}

class _CapsuleRow extends StatelessWidget {
  final List<(String, String?)> items;
  const _CapsuleRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: _StatCapsule(
              label: items[i].$1,
              value: items[i].$2 ?? '—',
            ),
          ),
          if (i < items.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _StatCapsule extends StatelessWidget {
  final String label;
  final String value;
  const _StatCapsule({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipPath(
          clipper: const _ChevronBannerClipper(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 3),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppColors.statTabBg,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppFonts.display(
                  const TextStyle(
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.8,
                    color: AppColors.statTabInkItalic,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.statFieldBorder),
            ),
            constraints: const BoxConstraints(minHeight: 38),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppFonts.display(
                  const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatHex extends StatelessWidget {
  final String label;
  final String? value;
  const _StatHex({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 70,
          height: 74,
          child: ClipPath(
            clipper: const _HexagonClipper(),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.statHexLight, AppColors.statHexDark],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipPath(
                  clipper: const _HexagonClipper(),
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Text(
                      value ?? '–',
                      style: AppFonts.display(
                        const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.statTabBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: AppFonts.display(
              const TextStyle(
                fontSize: 9,
                letterSpacing: 1.8,
                color: AppColors.statTabInk,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  const _HexagonClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ChevronBannerClipper extends CustomClipper<Path> {
  const _ChevronBannerClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const shoulder = 8.0;
    return Path()
      ..moveTo(shoulder, 0)
      ..lineTo(w - shoulder, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w - shoulder, h)
      ..lineTo(shoulder, h)
      ..lineTo(0, h / 2)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Identity rows (Hull Type/Class, Manufacturer) ──────────────────────

class _IdentityRows extends StatelessWidget {
  final Starship starship;
  const _IdentityRows({required this.starship});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String?)>[
      ('Hull Type / Class', starship.hullTypeClass),
      ('Manufacturer', starship.manufacturer),
    ].where((row) => row.$2 != null && row.$2!.isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    rows[i].$1.toUpperCase(),
                    style: AppFonts.display(
                      const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[i].$2!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: AppColors.inkDim,
                    ),
                  ),
                ),
              ],
            ),
            if (i < rows.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ── Armaments panel ─────────────────────────────────────────────────────

class _ArmamentsPanel extends StatelessWidget {
  final String text;
  const _ArmamentsPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: ClipPath(
            clipper: const _ChevronBannerClipper(),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 5, 22, 4),
              color: AppColors.statTabBg,
              child: Text(
                'ARMAMENTS',
                style: AppFonts.display(
                  const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.4,
                    color: AppColors.statTabInkItalic,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.statFieldBorder),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: AppColors.inkDim,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Game Mechanics ──────────────────────────────────────────────────────

class _MechanicsSection extends StatelessWidget {
  final List<String> specialQualities;
  final String? prose;
  final Map<String, ItemQuality> qualities;

  const _MechanicsSection({
    required this.specialQualities,
    required this.prose,
    required this.qualities,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < specialQualities.length; i++) {
      final raw = specialQualities[i];
      final key = ItemQuality.lookupKey(raw);
      final match = qualities[key];
      rows.add(_MechanicRow(
        name: raw,
        description: match?.description,
        first: i == 0,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rows.isNotEmpty) ...rows,
        if (prose != null && prose!.isNotEmpty) ...[
          if (rows.isNotEmpty) const SizedBox(height: 18),
          _Prose(text: prose!),
        ],
      ],
    );
  }
}

class _MechanicRow extends StatelessWidget {
  final String name;
  final String? description;
  final bool first;

  const _MechanicRow({
    required this.name,
    required this.description,
    required this.first,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: first
              ? BorderSide.none
              : const BorderSide(color: AppColors.line),
        ),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final wide = constraints.maxWidth >= 480;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 180, child: _nameLabel()),
                const SizedBox(width: 24),
                Expanded(child: _descBody()),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _nameLabel(),
              const SizedBox(height: 6),
              _descBody(),
            ],
          );
        },
      ),
    );
  }

  Widget _nameLabel() => Text(
        name.toUpperCase(),
        style: AppFonts.display(
          const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
            color: AppColors.accent,
            height: 1.1,
          ),
        ),
      );

  Widget _descBody() {
    final text = description ?? 'No description in glossary yet.';
    return Text(
      text,
      style: TextStyle(
        fontSize: 14.5,
        height: 1.6,
        color: description == null
            ? AppColors.inkFaint
            : AppColors.inkDim,
        fontStyle:
            description == null ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}

// ── Prose ───────────────────────────────────────────────────────────────

class _Prose extends StatelessWidget {
  final String text;
  const _Prose({required this.text});

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split('\n\n').where((p) => p.trim().isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              p.trim(),
              style: const TextStyle(
                fontSize: 15,
                height: 1.65,
                color: AppColors.inkDim,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Source link ─────────────────────────────────────────────────────────

class _SourceLink extends StatelessWidget {
  final String url;
  const _SourceLink({required this.url});

  @override
  Widget build(BuildContext context) {
    final display = url.replaceFirst(RegExp(r'^https?://'), '');
    return InkWell(
      onTap: () => _open(context, url),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.lineStrong),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentDim,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.open_in_new,
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'View on the Star Wars RPG Fandom wiki',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.mono(
                      const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
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
