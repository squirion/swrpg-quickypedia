import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:swrpg_quickypedia/models/starship.dart';
import 'package:swrpg_quickypedia/services/github_data_repo.dart';
import 'package:swrpg_quickypedia/services/image_resize.dart';
import 'package:swrpg_quickypedia/services/system_data_store.dart';

class StarshipImageUploader {
  static const int _maxEdgePx = 1024;
  static const String _imagesDir = 'images/starships';
  static const String _starshipsDbPath = 'databases/starships.json';

  final GithubDataRepo _repo;
  final http.Client _client;

  StarshipImageUploader(this._repo, {http.Client? client})
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
    required Starship starship,
    required Uint8List bytes,
  }) async {
    final png = await resizeToPng(bytes, _maxEdgePx);
    final slug = slugFor(starship.name);
    final path = '$_imagesDir/$slug.png';

    final currentImage = await _repo.getContents(path);
    final newSha = await _repo.putFile(
      path: path,
      bytes: png,
      commitMessage: 'Add image for ${starship.name}',
      expectedSha: currentImage?.sha,
    );

    final version = newSha.length >= 8
        ? newSha.substring(0, 8)
        : DateTime.now().millisecondsSinceEpoch.toString();
    final newUrl = '${_repo.rawUri(path)}?v=$version';

    final store = const SystemDataStore('starships');
    final cached = await store.read<Starship>(Starship.fromJson);
    final updated = cached
        .map((s) => s.name == starship.name ? _withImageUrl(s, newUrl) : s)
        .toList(growable: false);
    await store.write<Starship>(updated, (s) => s.toJson());

    final dbBytes = await store.readBytes();
    if (dbBytes != null) {
      final currentDb = await _repo.getContents(_starshipsDbPath);
      await _repo.putFile(
        path: _starshipsDbPath,
        bytes: dbBytes,
        commitMessage: 'Set image for ${starship.name}',
        expectedSha: currentDb?.sha,
      );
    }

    return newUrl;
  }

  Future<String> uploadFromUrl({
    required Starship starship,
    required String url,
  }) async {
    final bytes = await _fetchUrlBytes(url);
    return upload(starship: starship, bytes: bytes);
  }

  void close() => _client.close();
}

Starship _withImageUrl(Starship s, String imageUrl) {
  final json = s.toJson();
  json['imageUrl'] = imageUrl;
  return Starship.fromJson(json);
}
