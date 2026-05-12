import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:swrpg_quickypedia/models/armor.dart';
import 'package:swrpg_quickypedia/services/github_data_repo.dart';
import 'package:swrpg_quickypedia/services/system_data_store.dart';

/// Armor counterpart of [WeaponImageUploader]. Same flow: decode + resize
/// → PUT `images/armors/<slug>.png` → patch local armors cache → PUT
/// `databases/armors.json`. Cache-buster is the short SHA returned by
/// GitHub so re-uploads don't get masked by the device's image cache.
class ArmorImageUploader {
  static const int _maxEdgePx = 1024;
  static const String _imagesDir = 'images/armors';
  static const String _armorsDbPath = 'databases/armors.json';

  final GithubDataRepo _repo;
  final http.Client _client;

  ArmorImageUploader(this._repo, {http.Client? client})
      : _client = client ?? http.Client();

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

  /// Upload the image and update the armors database in one go.
  /// Returns the URL written into `armor.imageUrl`.
  Future<String> upload({
    required Armor armor,
    required Uint8List bytes,
  }) async {
    final png = _resizeToPng(bytes);
    final slug = slugFor(armor.name);
    final path = '$_imagesDir/$slug.png';

    final currentImage = await _repo.getContents(path);
    final newSha = await _repo.putFile(
      path: path,
      bytes: png,
      commitMessage: 'Add image for ${armor.name}',
      expectedSha: currentImage?.sha,
    );

    final version = newSha.length >= 8
        ? newSha.substring(0, 8)
        : DateTime.now().millisecondsSinceEpoch.toString();
    final newUrl = '${_repo.rawUri(path)}?v=$version';

    final store = const SystemDataStore('armors');
    final cached = await store.read<Armor>(Armor.fromJson);
    final updated = cached
        .map((a) => a.name == armor.name ? _withImageUrl(a, newUrl) : a)
        .toList(growable: false);
    await store.write<Armor>(updated, (a) => a.toJson());

    final dbBytes = await store.readBytes();
    if (dbBytes != null) {
      final currentDb = await _repo.getContents(_armorsDbPath);
      await _repo.putFile(
        path: _armorsDbPath,
        bytes: dbBytes,
        commitMessage: 'Set image for ${armor.name}',
        expectedSha: currentDb?.sha,
      );
    }

    return newUrl;
  }

  Future<String> uploadFromUrl({
    required Armor armor,
    required String url,
  }) async {
    final bytes = await _fetchUrlBytes(url);
    return upload(armor: armor, bytes: bytes);
  }

  void close() => _client.close();
}

/// Return a copy of [a] with [imageUrl] replaced. Armor is immutable and
/// doesn't carry a `copyWith`, so we rebuild from JSON.
Armor _withImageUrl(Armor a, String imageUrl) {
  final json = a.toJson();
  json['imageUrl'] = imageUrl;
  return Armor.fromJson(json);
}
