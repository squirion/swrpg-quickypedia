import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:swrpg_quickypedia/models/gear.dart';
import 'package:swrpg_quickypedia/services/github_data_repo.dart';
import 'package:swrpg_quickypedia/services/image_resize.dart';
import 'package:swrpg_quickypedia/services/system_data_store.dart';

class GearImageUploader {
  static const int _maxEdgePx = 1024;
  static const String _imagesDir = 'images/gear';
  static const String _gearDbPath = 'databases/gear.json';

  final GithubDataRepo _repo;
  final http.Client _client;

  GearImageUploader(this._repo, {http.Client? client})
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

  Future<String> upload({
    required Gear gear,
    required Uint8List bytes,
  }) async {
    final png = await resizeToPng(bytes, _maxEdgePx);
    final slug = slugFor(gear.name);
    final path = '$_imagesDir/$slug.png';

    final currentImage = await _repo.getContents(path);
    final newSha = await _repo.putFile(
      path: path,
      bytes: png,
      commitMessage: 'Add image for ${gear.name}',
      expectedSha: currentImage?.sha,
    );

    final version = newSha.length >= 8
        ? newSha.substring(0, 8)
        : DateTime.now().millisecondsSinceEpoch.toString();
    final newUrl = '${_repo.rawUri(path)}?v=$version';

    final store = const SystemDataStore('gear');
    final cached = await store.read<Gear>(Gear.fromJson);
    final updated = cached
        .map((g) => g.name == gear.name ? _withImageUrl(g, newUrl) : g)
        .toList(growable: false);
    await store.write<Gear>(updated, (g) => g.toJson());

    final dbBytes = await store.readBytes();
    if (dbBytes != null) {
      final currentDb = await _repo.getContents(_gearDbPath);
      await _repo.putFile(
        path: _gearDbPath,
        bytes: dbBytes,
        commitMessage: 'Set image for ${gear.name}',
        expectedSha: currentDb?.sha,
      );
    }

    return newUrl;
  }

  Future<String> uploadFromUrl({
    required Gear gear,
    required String url,
  }) async {
    final bytes = await _fetchUrlBytes(url);
    return upload(gear: gear, bytes: bytes);
  }

  void close() => _client.close();
}

Gear _withImageUrl(Gear g, String imageUrl) {
  final json = g.toJson();
  json['imageUrl'] = imageUrl;
  return Gear.fromJson(json);
}
