import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:swrpg_quickypedia/models/vehicle.dart';
import 'package:swrpg_quickypedia/services/github_data_repo.dart';
import 'package:swrpg_quickypedia/services/image_resize.dart';
import 'package:swrpg_quickypedia/services/system_data_store.dart';

class VehicleImageUploader {
  static const int _maxEdgePx = 1024;
  static const String _imagesDir = 'images/vehicles';
  static const String _vehiclesDbPath = 'databases/vehicles.json';

  final GithubDataRepo _repo;
  final http.Client _client;

  VehicleImageUploader(this._repo, {http.Client? client})
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
    required Vehicle vehicle,
    required Uint8List bytes,
  }) async {
    final png = await resizeToPng(bytes, _maxEdgePx);
    final slug = slugFor(vehicle.name);
    final path = '$_imagesDir/$slug.png';

    final currentImage = await _repo.getContents(path);
    final newSha = await _repo.putFile(
      path: path,
      bytes: png,
      commitMessage: 'Add image for ${vehicle.name}',
      expectedSha: currentImage?.sha,
    );

    final version = newSha.length >= 8
        ? newSha.substring(0, 8)
        : DateTime.now().millisecondsSinceEpoch.toString();
    final newUrl = '${_repo.rawUri(path)}?v=$version';

    final store = const SystemDataStore('vehicles');
    final cached = await store.read<Vehicle>(Vehicle.fromJson);
    final updated = cached
        .map((v) => v.name == vehicle.name ? _withImageUrl(v, newUrl) : v)
        .toList(growable: false);
    await store.write<Vehicle>(updated, (v) => v.toJson());

    final dbBytes = await store.readBytes();
    if (dbBytes != null) {
      final currentDb = await _repo.getContents(_vehiclesDbPath);
      await _repo.putFile(
        path: _vehiclesDbPath,
        bytes: dbBytes,
        commitMessage: 'Set image for ${vehicle.name}',
        expectedSha: currentDb?.sha,
      );
    }

    return newUrl;
  }

  Future<String> uploadFromUrl({
    required Vehicle vehicle,
    required String url,
  }) async {
    final bytes = await _fetchUrlBytes(url);
    return upload(vehicle: vehicle, bytes: bytes);
  }

  void close() => _client.close();
}

Vehicle _withImageUrl(Vehicle v, String imageUrl) {
  final json = v.toJson();
  json['imageUrl'] = imageUrl;
  return Vehicle.fromJson(json);
}
