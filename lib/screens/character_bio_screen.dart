import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:swrpg_quickypedia/models/character.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/utils/html_utils.dart';
import 'package:swrpg_quickypedia/widgets/fullscreen_image_viewer.dart';
import 'package:swrpg_quickypedia/widgets/web_body_frame.dart';
import 'package:swrpg_quickypedia/widgets/web_safe_image.dart';

class CharacterBioScreen extends ConsumerWidget {
  final Character character;

  const CharacterBioScreen({super.key, required this.character});

  static String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(characterDetailProvider(character.id));
    // Use detail data if available, otherwise fall back to the list data
    // we already have so the page never shows a blank screen.
    final c = detailAsync.maybeWhen(
      data: (detail) => detail,
      orElse: () => character,
    );
    final isLoadingDetail = detailAsync.isLoading;
    final detailError = detailAsync.hasError ? detailAsync.error : null;

    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: WebBodyFrame(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(characterDetailProvider(character.id));
            await ref.read(characterDetailProvider(character.id).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _HeroImage(url: c.avatarUrl),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _Header(character: c),
              ),
              if (detailError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _ErrorBanner(error: detailError),
                ),
              _BioSection(
                content: c.content,
                isLoading: isLoadingDetail && c.content == null,
              ),
              _DetailsCard(character: c),
              if (c.characterUrl != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View on Obsidian Portal'),
                    onPressed: () async {
                      final uri = Uri.parse(c.characterUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String? url;
  const _HeroImage({this.url});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final fallback = Container(
      color: Colors.grey.shade300,
      height: 240,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 120, color: Colors.grey.shade100),
    );
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) return fallback;

    // Mirrors the weapon hero: GestureDetector OUTSIDE the visible
    // container so taps on the letterboxing (BoxFit.contain leaves
    // black gutters) still open the viewer, with HitTestBehavior.opaque
    // to capture even transparent regions.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FullscreenImageViewer.open(
        context,
        imageUrl: imageUrl,
        heroTag: imageUrl,
      ),
      child: Container(
        color: Colors.black,
        constraints: BoxConstraints(maxHeight: screen.height * 0.6),
        child: Hero(
          tag: imageUrl,
          // CanvasKit's `Image.network` (and `CachedNetworkImage`)
          // fetch via XHR and are blocked by CORS for the Obsidian
          // Portal CDN. On web we drop in an `<img>` element via
          // `HtmlElementView`, which displays cross-origin images
          // without a CORS check.
          child: kIsWeb
              ? webSafeImage(
                  url: imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorPlaceholder: fallback,
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => Container(
                    height: 240,
                    color: Colors.grey.shade200,
                  ),
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Character character;
  const _Header({required this.character});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(character.name, style: theme.textTheme.headlineMedium),
        if (character.author != null) ...[
          const SizedBox(height: 4),
          Text(
            'Played by ${character.author!.username}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.grey.shade700),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              label: Text(character.isPlayerCharacter ? 'PC' : 'NPC'),
              backgroundColor: character.isPlayerCharacter
                  ? Colors.blue.shade100
                  : Colors.orange.shade100,
            ),
            if (character.isGameMasterOnly)
              Chip(
                label: const Text('GM Only'),
                backgroundColor: Colors.red.shade100,
              ),
            ...character.tags.map((tag) => Chip(label: Text(tag))),
          ],
        ),
      ],
    );
  }
}

class _BioSection extends StatelessWidget {
  final String? content;
  final bool isLoading;
  const _BioSection({required this.content, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paragraphs = htmlToParagraphs(content);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bio', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (paragraphs.isEmpty)
            Text(
              'No bio yet.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            )
          else
            ...paragraphs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  p,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Character character;
  const _DetailsCard({required this.character});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Details', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (character.campaign != null)
                _InfoRow(
                  label: 'Campaign',
                  value: character.campaign!.name,
                ),
              _InfoRow(label: 'Visibility', value: character.visibility),
              _InfoRow(
                label: 'Created',
                value: CharacterBioScreen._formatDate(character.createdAt),
              ),
              _InfoRow(
                label: 'Updated',
                value: CharacterBioScreen._formatDate(character.updatedAt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final Object error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not refresh bio: $error',
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
