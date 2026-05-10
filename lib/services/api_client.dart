import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:swrpg_quickypedia/models/campaign.dart';
import 'package:swrpg_quickypedia/models/character.dart';
import 'package:swrpg_quickypedia/services/auth_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static const _baseUrl = 'https://api.obsidianportal.com/v1';

  final AuthService _authService;
  http.BaseClient? _client;

  ApiClient(this._authService);

  http.BaseClient get _httpClient {
    _client ??= _authService.createAuthenticatedClient();
    return _client!;
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _httpClient.get(Uri.parse('$_baseUrl$path'));
    return _handleResponse(response) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getJsonList(String path) async {
    final response = await _httpClient.get(Uri.parse('$_baseUrl$path'));
    return _handleResponse(response) as List<dynamic>;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 503) {
      throw ApiException(503, 'Obsidian Portal is temporarily down for maintenance. Please try again later.');
    }
    if (response.statusCode >= 400) {
      String message = 'Request failed';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final errors = body['errors'] as List<dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          message = errors.map((e) => e['message']).join('; ');
        }
      } catch (_) {
        message = 'HTTP ${response.statusCode}';
      }
      throw ApiException(response.statusCode, message);
    }
    return jsonDecode(response.body);
  }

  /// Fetch the campaigns the authenticated user is a member of.
  /// Calls GET /v1/users/me and extracts the embedded campaigns array.
  Future<List<Campaign>> getCampaigns() async {
    final json = await _getJson('/users/me');
    final campaigns = json['campaigns'] as List<dynamic>? ?? [];
    return campaigns
        .map((e) => Campaign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch all characters for a campaign.
  Future<List<Character>> getCharacters(String campaignId) async {
    final jsonList = await _getJsonList('/campaigns/$campaignId/characters');
    return jsonList
        .map((e) => Character.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single character.
  Future<Character> getCharacter(String campaignId, String characterId) async {
    final json = await _getJson(
      '/campaigns/$campaignId/characters/$characterId',
    );
    return Character.fromJson(json);
  }

  /// Reset the HTTP client (e.g. after re-authentication).
  void resetClient() {
    _client = null;
  }
}
