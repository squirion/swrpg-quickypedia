import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';

/// Renders a `raw.githubusercontent.com` image from the private data
/// repo on web. Native code keeps using `CachedNetworkImage` because
/// it can attach the PAT to the `Authorization` header; on web that
/// header doesn't survive an `<img>` request, so we fetch the bytes
/// authenticated through the Contents API and render them locally
/// via `Image.memory`. Bytes are cached per-URL by
/// [githubRepoImageBytesProvider] so re-renders inside the same
/// session don't re-fetch.
class GithubRepoImage extends ConsumerWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorPlaceholder;

  const GithubRepoImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorPlaceholder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(githubRepoImageBytesProvider(url));
    return async.when(
      data: (bytes) {
        if (bytes == null || bytes.isEmpty) {
          return errorPlaceholder ?? const SizedBox.shrink();
        }
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              errorPlaceholder ?? const SizedBox.shrink(),
        );
      },
      loading: () => placeholder ?? const SizedBox.shrink(),
      error: (_, _) => errorPlaceholder ?? const SizedBox.shrink(),
    );
  }
}
