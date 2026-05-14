import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/item_quality.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/services/weapon_image_upload.dart';
import 'package:swrpg_quickypedia/theme.dart';
import 'package:swrpg_quickypedia/widgets/fullscreen_image_viewer.dart';
import 'package:swrpg_quickypedia/widgets/github_repo_image.dart';
import 'package:swrpg_quickypedia/widgets/image_upload_surface.dart';
import 'package:swrpg_quickypedia/widgets/item_detail_layout.dart';
import 'package:swrpg_quickypedia/widgets/weapon_placeholder.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detail screen for a single weapon. Layout matches the
/// `swrpg-weapon-view` Claude Design handoff: breadcrumbs, hero image
/// with corner brackets and overlaid title/lede, numbered sections for
/// Specifications, Game Mechanics, and Reference.
class WeaponViewScreen extends ConsumerWidget {
  final Weapon weapon;
  const WeaponViewScreen({super.key, required this.weapon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualitiesAsync = ref.watch(itemQualitiesProvider);
    final qualities = qualitiesAsync.asData?.value ?? const {};

    // After an image upload, weaponsProvider gets invalidated and the
    // fresh weapon (now with imageUrl) lands in the list. Look it up
    // by name so this screen re-renders with the new pointer without
    // needing the caller to push a new route.
    final allWeapons =
        ref.watch(weaponsProvider).asData?.value ?? const <Weapon>[];
    final live = allWeapons.firstWhere(
      (w) => w.name == weapon.name,
      orElse: () => weapon,
    );

    final hasMechanics =
        live.mechanics != null && live.mechanics!.isNotEmpty;
    final hasSpecial = live.specialQualities.isNotEmpty;
    final showMechanicsSection = hasMechanics || hasSpecial;

    return Scaffold(
      appBar: AppBar(title: Text(live.name)),
      body: ItemDetailLayout(
        crumbs: _Crumbs(name: live.name),
        hero: _Hero(weapon: live),
        firstSectionHeading:
            const _SectionHeading(number: '01', title: 'Specifications'),
        firstSectionBody: _StatBlock(weapon: live),
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

// ── Game Mechanics ──────────────────────────────────────────────────────

/// Renders the Game Mechanics block: per-quality definition rows
/// (name → description) resolved against the qualities glossary, plus
/// any free-form prose the parser pulled out below the stat image.
/// Unmatched qualities still appear, just without a description.
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

// ── Crumbs ──────────────────────────────────────────────────────────────

class _Crumbs extends StatelessWidget {
  final String name;
  const _Crumbs({required this.name});

  @override
  Widget build(BuildContext context) {
    Widget seg(String text, {bool current = false}) => Text(
          text,
          style: AppFonts.display(
            TextStyle(
              fontSize: 11,
              letterSpacing: 1.7,
              color: current ? AppColors.inkDim : AppColors.inkFaint,
            ),
          ).copyWith(height: 1),
        );
    Widget sep() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '›',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.18),
              fontSize: 12,
            ),
          ),
        );
    return Row(
      children: [
        seg('ARMORY'),
        sep(),
        seg('WEAPONS'),
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

/// Hero panel: weapon art fills the panel and feathers to black at its
/// bottom third, where the skill eyebrow, name, and lede description are
/// overlaid. Falls back to a stylized rifle silhouette + hatch pattern
/// when no image URL is available.
class _Hero extends ConsumerWidget {
  final Weapon weapon;
  const _Hero({required this.weapon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage =
        weapon.imageUrl != null && weapon.imageUrl!.isNotEmpty;
    final authHeaders =
        hasImage ? githubAuthHeadersFor(weapon.imageUrl!, ref) : null;

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
                const WeaponPlaceholder()
              else
                Hero(
                  tag: weapon.imageUrl!,
                  // On web, `<img>` requests to our private data repo
                  // can't carry the PAT, so raw.githubusercontent.com
                  // 404s. Route through [GithubRepoImage] which
                  // fetches authed bytes via Contents API and renders
                  // them locally.
                  child: kIsWeb && authHeaders != null
                      ? GithubRepoImage(
                          url: weapon.imageUrl!,
                          fit: BoxFit.contain,
                          placeholder:
                              const ColoredBox(color: AppColors.bg2),
                          errorPlaceholder: const WeaponPlaceholder(),
                        )
                      : CachedNetworkImage(
                          imageUrl: weapon.imageUrl!,
                          httpHeaders: authHeaders,
                          // Preserve aspect ratio (was BoxFit.cover)
                          // so the full image is visible at a glance;
                          // tap to zoom.
                          fit: BoxFit.contain,
                          placeholder: (_, _) =>
                              const ColoredBox(color: AppColors.bg2),
                          errorWidget: (_, _, _) =>
                              const WeaponPlaceholder(),
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
                child: _HeroOverlay(weapon: weapon),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _EditImageButton(weapon: weapon),
              ),
              const _CornerBracket(alignment: Alignment.topLeft),
              const _CornerBracket(alignment: Alignment.bottomLeft),
              const _CornerBracket(alignment: Alignment.bottomRight),
            ],
          ),
        ),
      ),
    );

    // Wrap the whole hero in a single GestureDetector OUTSIDE the
    // Stack. Anything inside (the edit pencil InkWell) absorbs its
    // own taps; everything else flows up to this outer tap → opens
    // the fullscreen viewer.
    final tappable = !hasImage
        ? panel
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FullscreenImageViewer.open(
              context,
              imageUrl: weapon.imageUrl!,
              httpHeaders: authHeaders,
              heroTag: weapon.imageUrl!,
            ),
            child: panel,
          );

    return ImageUploadSurface(
      onBytes: (bytes) => _runWeaponUpload(
        context,
        ref,
        (u) => u.upload(weapon: weapon, bytes: bytes),
      ),
      onUrl: (url) => _runWeaponUpload(
        context,
        ref,
        (u) => u.uploadFromUrl(weapon: weapon, url: url),
      ),
      child: tappable,
    );
  }
}

Future<void> _runWeaponUpload(
  BuildContext context,
  WidgetRef ref,
  Future<String> Function(WeaponImageUploader uploader) action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Uploading image…')),
  );
  try {
    final uploader = ref.read(weaponImageUploaderProvider);
    await action(uploader);
    ref.invalidate(weaponsProvider);
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
  final Weapon weapon;
  const _EditImageButton({required this.weapon});

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
          onBytes: (bytes) => _runWeaponUpload(
            context,
            ref,
            (u) => u.upload(weapon: weapon, bytes: bytes),
          ),
          onUrl: (url) => _runWeaponUpload(
            context,
            ref,
            (u) => u.uploadFromUrl(weapon: weapon, url: url),
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
  final Weapon weapon;
  const _HeroOverlay({required this.weapon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (weapon.skill != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              weapon.skill!.toUpperCase(),
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
          weapon.name,
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
        if (weapon.description != null && weapon.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            weapon.description!.split('\n\n').first,
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
  final Weapon weapon;
  const _StatBlock({required this.weapon});

  @override
  Widget build(BuildContext context) {
    // Flex weights mirror the design CSS (flex: 2.4, 1.3, 0.9, 1.3, 0.9).
    final capsules = <(String, String?, int)>[
      ('SKILL', weapon.skill, 24),
      ('RANGE', weapon.range, 13),
      ('ENCUM', weapon.encumbrance, 9),
      ('PRICE', weapon.price, 13),
      ('RARITY', weapon.rarity, 9),
    ];
    final hexes = <(String, String?)>[
      ('DAMAGE', weapon.damage),
      ('CRITICAL', weapon.critical),
      ('HP', weapon.hardpoints),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
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
            children: [
              for (var i = 0; i < capsules.length; i++) ...[
                Expanded(
                  flex: capsules[i].$3,
                  child: _StatCapsule(
                    label: capsules[i].$1,
                    value: capsules[i].$2 ?? '—',
                  ),
                ),
                if (i < capsules.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final (label, value) in hexes)
                Expanded(child: _StatHex(label: label, value: value)),
            ],
          ),
          if (weapon.specialQualities.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SpecialPanel(qualities: weapon.specialQualities),
          ],
        ],
      ),
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
        // Chevron-shouldered banner tab.
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
                    fontSize: 14,
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

/// Banner with chevron-pointed shoulders. CSS reference:
/// ```
/// clip-path: polygon(
///   10px 0,
///   calc(100% - 10px) 0,
///   100% 50%,
///   calc(100% - 10px) 100%,
///   10px 100%,
///   0 50%
/// );
/// ```
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
          width: 78,
          height: 82,
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
                          fontSize: 28,
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
                fontSize: 10,
                letterSpacing: 2.0,
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

class _SpecialPanel extends StatelessWidget {
  final List<String> qualities;
  const _SpecialPanel({required this.qualities});

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
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 4),
              color: AppColors.statTabBg,
              child: Text(
                'SPECIAL',
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
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.statFieldBorder),
            ),
            child: Text(
              qualities.join(', '),
              textAlign: TextAlign.center,
              style: AppFonts.display(
                const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ],
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
