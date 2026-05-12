import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/services/github_data_repo.dart';
import 'package:swrpg_quickypedia/services/system_data_store.dart';

/// One image upload + the follow-up `weapons.json` patch, packaged as
/// a single async operation. Performs the work in this order so a
/// failure at any step leaves the cloud in a consistent state:
///   1. Decode + resize the image (no network yet)
///   2. PUT `images/weapons/<slug>.png` to the data repo
///   3. Patch the local weapons cache with the new `imageUrl`
///   4. PUT `databases/weapons.json` so the pointer reaches everyone
class WeaponImageUploader {
  static const int _maxEdgePx = 1024;
  static const String _imagesDir = 'images/weapons';
  static const String _weaponsDbPath = 'databases/weapons.json';

  final GithubDataRepo _repo;
  final http.Client _client;

  WeaponImageUploader(this._repo, {http.Client? client})
      : _client = client ?? http.Client();

  /// Slug used for the filename. `"Heavy Blaster Pistol"` →
  /// `"heavy-blaster-pistol"`. Strips punctuation; preserves digits.
  static String slugFor(String name) {
    final lower = name.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r"[^a-z0-9]+"), '-');
    return cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<Uint8List> _fetchUrlBytes(String url) async {
    final resp = await _client.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw Exception('GET $url returned ${resp.statusCode}');
    }
    return resp.bodyBytes;
  }

  /// Re-encode to PNG, capped at [_maxEdgePx] on the longest side so
  /// the repo doesn't accumulate multi-MB blobs. PNG keeps any
  /// transparency the source had.
  Uint8List _resizeToPng(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode the supplied image bytes.');
    }
    final w = decoded.width;
    final h = decoded.height;
    final longest = w >= h ? w : h;
    final shrunk = longest <= _maxEdgePx
        ? decoded
        : img.copyResize(
            decoded,
            width: w >= h ? _maxEdgePx : null,
            height: h > w ? _maxEdgePx : null,
            interpolation: img.Interpolation.cubic,
          );
    return Uint8List.fromList(img.encodePng(shrunk));
  }

  /// Upload the image and update the weapons database in one go.
  /// Returns the URL written into `weapon.imageUrl`.
  Future<String> upload({
    required Weapon weapon,
    required Uint8List bytes,
  }) async {
    final png = _resizeToPng(bytes);
    final slug = slugFor(weapon.name);
    final path = '$_imagesDir/$slug.png';

    // Step 1: image binary
    final currentImage = await _repo.getContents(path);
    final newSha = await _repo.putFile(
      path: path,
      bytes: png,
      commitMessage: 'Add image for ${weapon.name}',
      expectedSha: currentImage?.sha,
    );

    // Cache-buster: the raw URL is keyed by path so re-uploads to the
    // same slug would otherwise hit the device's CachedNetworkImage
    // cache. Tack on `?v=<short-sha>` so each new content version is
    // a different URL and the cache misses on purpose. Falls back to
    // a timestamp if GitHub didn't return a SHA (shouldn't happen).
    final version = newSha.length >= 8
        ? newSha.substring(0, 8)
        : DateTime.now().millisecondsSinceEpoch.toString();
    final newUrl = '${_repo.rawUri(path)}?v=$version';

    // Step 2: local cache
    final store = const SystemDataStore('weapons');
    final cached = await store.read<Weapon>(Weapon.fromJson);
    final updated = cached
        .map((w) => w.name == weapon.name ? _withImageUrl(w, newUrl) : w)
        .toList(growable: false);
    await store.write<Weapon>(updated, (w) => w.toJson());

    // Step 3: cloud weapons.json (so other users see the pointer)
    final dbBytes = await store.readBytes();
    if (dbBytes != null) {
      final currentDb = await _repo.getContents(_weaponsDbPath);
      await _repo.putFile(
        path: _weaponsDbPath,
        bytes: dbBytes,
        commitMessage: 'Set image for ${weapon.name}',
        expectedSha: currentDb?.sha,
      );
    }

    return newUrl;
  }

  /// Convenience: fetch image bytes from a URL, then [upload].
  Future<String> uploadFromUrl({
    required Weapon weapon,
    required String url,
  }) async {
    final bytes = await _fetchUrlBytes(url);
    return upload(weapon: weapon, bytes: bytes);
  }

  void close() => _client.close();
}

/// Return a copy of [w] with [imageUrl] replaced. Weapon is immutable
/// and doesn't carry a `copyWith` yet, so we rebuild from JSON.
Weapon _withImageUrl(Weapon w, String imageUrl) {
  final json = w.toJson();
  json['imageUrl'] = imageUrl;
  return Weapon.fromJson(json);
}
