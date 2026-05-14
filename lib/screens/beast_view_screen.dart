import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/beast.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/services/beast_image_upload.dart';
import 'package:swrpg_quickypedia/theme.dart';
import 'package:swrpg_quickypedia/widgets/beast_placeholder.dart';
import 'package:swrpg_quickypedia/widgets/fullscreen_image_viewer.dart';
import 'package:swrpg_quickypedia/widgets/github_repo_image.dart';
import 'package:swrpg_quickypedia/widgets/image_upload_surface.dart';
import 'package:swrpg_quickypedia/widgets/item_detail_layout.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detail screen for a single beast. Creatures get a bespoke layout
/// that doesn't fit the item categories' shape:
///   01 Characteristics — 6 hex tiles (BR / AG / INT / CUN / WIL / PRE)
///   02 Combat Stats    — Soak / Wounds / Melee Def / Ranged Def hexes
///   03 Commerce        — Price / Encum / Rarity capsules
///   04 Skills          — chip list
///   05 Talents         — paragraph
///   06 Abilities       — paragraph
///   07 Natural Weapons — Equipment text in a chevron-banner panel
///   08 Reference       — wiki link
///
/// Sections with no data are skipped.
class BeastViewScreen extends ConsumerWidget {
  final Beast beast;
  const BeastViewScreen({super.key, required this.beast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(beastsProvider).asData?.value ?? const <Beast>[];
    final live = all.firstWhere(
      (b) => b.name == beast.name,
      orElse: () => beast,
    );

    final hasCommerce = (live.price != null && live.price!.isNotEmpty) ||
        (live.encumbrance != null && live.encumbrance!.isNotEmpty) ||
        (live.rarity != null && live.rarity!.isNotEmpty);
    final hasSkills = live.skills != null && live.skills!.isNotEmpty;
    final hasTalents = live.talents != null &&
        live.talents!.isNotEmpty &&
        live.talents!.toLowerCase() != 'none';
    final hasAbilities =
        live.abilities != null && live.abilities!.isNotEmpty;
    final hasEquipment =
        live.equipment != null && live.equipment!.isNotEmpty;

    var sectionNumber = 0;
    String nextNum() => (++sectionNumber).toString().padLeft(2, '0');

    // Build the first-section heading first so the section counter
    // increments in render order (the inner `restSections` builder
    // runs next).
    final firstHeading =
        _SectionHeading(number: nextNum(), title: 'Characteristics');

    return Scaffold(
      appBar: AppBar(title: Text(live.name)),
      body: ItemDetailLayout(
        crumbs: _Crumbs(name: live.name, category: live.category),
        hero: _Hero(beast: live),
        firstSectionHeading: firstHeading,
        firstSectionBody: _CharacteristicsRow(beast: live),
        restSections: [
          const SizedBox(height: 22),
          _SectionHeading(number: nextNum(), title: 'Combat Stats'),
          const SizedBox(height: 14),
          _CombatRow(beast: live),
          if (hasCommerce) ...[
            const SizedBox(height: 22),
            _SectionHeading(number: nextNum(), title: 'Commerce'),
            const SizedBox(height: 14),
            _CommerceRow(beast: live),
          ],
          if (hasSkills) ...[
            const SizedBox(height: 22),
            _SectionHeading(number: nextNum(), title: 'Skills'),
            const SizedBox(height: 10),
            _SkillsChips(skills: live.skills!),
          ],
          if (hasTalents) ...[
            const SizedBox(height: 22),
            _SectionHeading(number: nextNum(), title: 'Talents'),
            const SizedBox(height: 10),
            _ProseBlock(text: live.talents!),
          ],
          if (hasAbilities) ...[
            const SizedBox(height: 22),
            _SectionHeading(number: nextNum(), title: 'Abilities'),
            const SizedBox(height: 10),
            _ProseBlock(text: live.abilities!),
          ],
          if (hasEquipment) ...[
            const SizedBox(height: 22),
            _SectionHeading(number: nextNum(), title: 'Natural Weapons'),
            const SizedBox(height: 10),
            _ArmamentsPanel(text: live.equipment!),
          ],
          if (live.sourceUrl != null) ...[
            const SizedBox(height: 22),
            _SectionHeading(number: nextNum(), title: 'Reference'),
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
        seg('BEASTS'),
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
  final Beast beast;
  const _Hero({required this.beast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = beast.imageUrl != null && beast.imageUrl!.isNotEmpty;
    final authHeaders =
        hasImage ? githubAuthHeadersFor(beast.imageUrl!, ref) : null;

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
                const BeastPlaceholder()
              else
                Hero(
                  tag: beast.imageUrl!,
                  child: kIsWeb && authHeaders != null
                      ? GithubRepoImage(
                          url: beast.imageUrl!,
                          fit: BoxFit.contain,
                          placeholder:
                              const ColoredBox(color: AppColors.bg2),
                          errorPlaceholder: const BeastPlaceholder(),
                        )
                      : CachedNetworkImage(
                          imageUrl: beast.imageUrl!,
                          httpHeaders: authHeaders,
                          fit: BoxFit.contain,
                          placeholder: (_, _) =>
                              const ColoredBox(color: AppColors.bg2),
                          errorWidget: (_, _, _) =>
                              const BeastPlaceholder(),
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
                child: _HeroOverlay(beast: beast),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _EditImageButton(beast: beast),
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
              imageUrl: beast.imageUrl!,
              httpHeaders: authHeaders,
              heroTag: beast.imageUrl!,
            ),
            child: panel,
          );

    return ImageUploadSurface(
      onBytes: (bytes) => _runBeastUpload(
        context,
        ref,
        (u) => u.upload(beast: beast, bytes: bytes),
      ),
      onUrl: (url) => _runBeastUpload(
        context,
        ref,
        (u) => u.uploadFromUrl(beast: beast, url: url),
      ),
      child: tappable,
    );
  }
}

Future<void> _runBeastUpload(
  BuildContext context,
  WidgetRef ref,
  Future<String> Function(BeastImageUploader uploader) action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Uploading image…')),
  );
  try {
    final uploader = ref.read(beastImageUploaderProvider);
    await action(uploader);
    ref.invalidate(beastsProvider);
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
  final Beast beast;
  const _EditImageButton({required this.beast});

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
          onBytes: (bytes) => _runBeastUpload(
            context,
            ref,
            (u) => u.upload(beast: beast, bytes: bytes),
          ),
          onUrl: (url) => _runBeastUpload(
            context,
            ref,
            (u) => u.uploadFromUrl(beast: beast, url: url),
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
  final Beast beast;
  const _HeroOverlay({required this.beast});

  @override
  Widget build(BuildContext context) {
    final showSilhouette = beast.silhouette != null;
    final eyebrow = [
      if (beast.category != null) beast.category!.toUpperCase(),
      if (showSilhouette) 'SILHOUETTE ${beast.silhouette}',
    ].join('  ·  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              eyebrow,
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
          beast.name,
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
        if (beast.description != null && beast.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            beast.description!.split('\n\n').first,
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

// ── Characteristics row (6 hex tiles) ───────────────────────────────────

class _CharacteristicsRow extends StatelessWidget {
  final Beast beast;
  const _CharacteristicsRow({required this.beast});

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String?)>[
      ('BR', beast.brawn),
      ('AG', beast.agility),
      ('INT', beast.intellect),
      ('CUN', beast.cunning),
      ('WIL', beast.willpower),
      ('PRE', beast.presence),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (label, value) in entries)
          Expanded(child: _StatHex(label: label, value: value)),
      ],
    );
  }
}

// ── Combat row (Soak / Wounds / M-Def / R-Def) ──────────────────────────

class _CombatRow extends StatelessWidget {
  final Beast beast;
  const _CombatRow({required this.beast});

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String?)>[
      ('SOAK', beast.soak),
      ('WOUNDS', beast.woundThreshold),
      ('M-DEF', beast.meleeDefense),
      ('R-DEF', beast.rangedDefense),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final (label, value) in entries)
            Expanded(child: _StatHex(label: label, value: value)),
        ],
      ),
    );
  }
}

// ── Commerce row (Price / Encum / Rarity capsules) ──────────────────────

class _CommerceRow extends StatelessWidget {
  final Beast beast;
  const _CommerceRow({required this.beast});

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String?)>[
      ('PRICE', beast.price),
      ('ENCUM', beast.encumbrance),
      ('RARITY', beast.rarity),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          Expanded(
            child: _StatCapsule(
              label: entries[i].$1,
              value: entries[i].$2 ?? '—',
            ),
          ),
          if (i < entries.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

// ── Skills chips ────────────────────────────────────────────────────────

class _SkillsChips extends StatelessWidget {
  final String skills;
  const _SkillsChips({required this.skills});

  @override
  Widget build(BuildContext context) {
    // Skills come back as a single comma-separated string like
    // "Athletics 2, Brawl 3, Perception 2". Split on commas and trim.
    final entries = skills
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.statTabBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.statFieldBorder),
            ),
            child: Text(
              entry,
              style: AppFonts.display(
                const TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Plain prose block ───────────────────────────────────────────────────

class _ProseBlock extends StatelessWidget {
  final String text;
  const _ProseBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14.5,
        height: 1.6,
        color: AppColors.inkDim,
      ),
    );
  }
}

// ── Hex stat tile (shared shape used by characteristics + combat) ──────

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
          width: 56,
          height: 60,
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
                          fontSize: 20,
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

// ── Natural-weapons panel ───────────────────────────────────────────────

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
                'NATURAL WEAPONS',
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
