import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class GithubDataException implements Exception {
  final int statusCode;
  final String message;
  GithubDataException(this.statusCode, this.message);

  @override
  String toString() => 'GithubDataException($statusCode): $message';
}

/// File-level read/write for the shared `swrpg-quickypedia-data` private
/// repo on GitHub. We keep weapon images + the scraped JSON databases
/// there so the whole campaign group shares one source of truth.
///
/// Writes go through the [Contents API](https://docs.github.com/en/rest/repos/contents)
/// (PUT with optimistic concurrency on `sha`); reads can take the fast
/// `raw.githubusercontent.com` path when we don't need the SHA.
class GithubDataRepo {
  final String owner;
  final String repo;
  final String branch;
  final String _pat;
  final http.Client _client;

  GithubDataRepo({
    required this.owner,
    required this.repo,
    required this.branch,
    required String pat,
    http.Client? client,
  })  : _pat = pat,
        _client = client ?? http.Client();

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_pat',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Map<String, String> get rawAuthHeaders => {
        'Authorization': 'Bearer $_pat',
      };

  Uri get _repoRoot =>
      Uri.parse('https://api.github.com/repos/$owner/$repo');

  Uri _contentsUri(String path) => Uri.parse(
        'https://api.github.com/repos/$owner/$repo/contents/$path'
        '?ref=$branch',
      );

  Uri rawUri(String path) => Uri.parse(
        'https://raw.githubusercontent.com/$owner/$repo/$branch/$path',
      );

  /// Cheap reachability + auth check. Returns a one-line status string
  /// suitable for the smoke-test dialog ("OK", "401 Bad credentials", …).
  Future<({bool ok, String detail})> healthCheck() async {
    try {
      final resp = await _client.get(_repoRoot, headers: _authHeaders);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final fullName = body['full_name'] ?? '$owner/$repo';
        final private = body['private'] == true ? 'private' : 'public';
        return (ok: true, detail: 'OK · $fullName ($private)');
      }
      return (
        ok: false,
        detail: 'HTTP ${resp.statusCode}: ${_apiError(resp)}',
      );
    } catch (e) {
      return (ok: false, detail: 'Request failed: $e');
    }
  }

  /// Fetch a file's bytes. On native we hit `raw.githubusercontent.com`
  /// with the PAT in the `Authorization` header. On web that path is
  /// blocked because the browser's CORS preflight fails (raw GitHub
  /// doesn't accept the `Authorization` header on an OPTIONS request),
  /// so we route through the Contents API, which supports CORS. For
  /// files ≤1 MB the API returns the content inline (base64); for
  /// larger files it returns a `download_url` whose embedded token
  /// lets us fetch the raw bytes without any custom headers (no
  /// preflight). Returns `null` for 404.
  Future<Uint8List?> readRaw(String path) async {
    if (kIsWeb) return _readViaContentsApi(path);
    final resp = await _client.get(rawUri(path), headers: rawAuthHeaders);
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw GithubDataException(resp.statusCode, _apiError(resp));
    }
    return resp.bodyBytes;
  }

  Future<Uint8List?> _readViaContentsApi(String path) async {
    final resp = await _client.get(_contentsUri(path), headers: _authHeaders);
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw GithubDataException(resp.statusCode, _apiError(resp));
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = body['content'] as String?;
    final encoding = body['encoding'] as String?;
    if (encoding == 'base64' && content != null && content.isNotEmpty) {
      return Uint8List.fromList(base64.decode(content.replaceAll('\n', '')));
    }
    // >1 MB: Contents API returns empty content + a tokenised
    // download_url. That URL is a simple GET (no auth header → no
    // CORS preflight) so the browser will fetch it cleanly.
    final downloadUrl = body['download_url'] as String?;
    if (downloadUrl == null) {
      throw GithubDataException(
        500,
        'Contents API returned no content and no download_url for $path',
      );
    }
    final raw = await _client.get(Uri.parse(downloadUrl));
    if (raw.statusCode != 200) {
      throw GithubDataException(raw.statusCode, raw.reasonPhrase ?? '');
    }
    return raw.bodyBytes;
  }

  /// Returns the file's current SHA + decoded bytes via the Contents
  /// API. `sha` is what you must pass to [putFile] to update this
  /// file safely. Returns `null` for 404.
  Future<({Uint8List bytes, String sha})?> getContents(String path) async {
    final resp = await _client.get(_contentsUri(path), headers: _authHeaders);
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw GithubDataException(resp.statusCode, _apiError(resp));
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = body['content'] as String?;
    final sha = body['sha'] as String?;
    if (content == null || sha == null) {
      throw GithubDataException(500, 'malformed contents response');
    }
    final decoded = base64.decode(content.replaceAll('\n', ''));
    return (bytes: Uint8List.fromList(decoded), sha: sha);
  }

  /// Create or overwrite a file. On a 409 conflict (someone else wrote
  /// the same file mid-request) we re-fetch the current SHA and retry
  /// once. Throws [GithubDataException] on any other failure.
  ///
  /// Returns the new commit SHA so callers can chain updates.
  Future<String> putFile({
    required String path,
    required Uint8List bytes,
    required String commitMessage,
    String? expectedSha,
  }) async {
    final body = <String, dynamic>{
      'message': commitMessage,
      'content': base64.encode(bytes),
      'branch': branch,
      'sha': ?expectedSha,
    };
    var resp = await _client.put(
      _contentsUri(path),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode == 409 || resp.statusCode == 422) {
      // Stale sha — refetch and retry once.
      final current = await getContents(path);
      body['sha'] = current?.sha;
      resp = await _client.put(
        _contentsUri(path),
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    }

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw GithubDataException(resp.statusCode, _apiError(resp));
    }
    final out = jsonDecode(resp.body) as Map<String, dynamic>;
    return (out['content'] as Map<String, dynamic>?)?['sha'] as String? ?? '';
  }

  String _apiError(http.Response resp) {
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return (body['message'] as String?) ?? resp.reasonPhrase ?? '';
    } catch (_) {
      return resp.reasonPhrase ?? '';
    }
  }

  void close() => _client.close();
}
