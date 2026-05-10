import 'package:http/http.dart' as http;
import 'package:oauth1/oauth1.dart' as oauth1;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthService {
  static const _accessTokenKey = 'op_access_token';
  static const _accessSecretKey = 'op_access_secret';

  final FlutterSecureStorage _storage;
  late final oauth1.Platform _platform;
  late final oauth1.ClientCredentials _clientCredentials;
  oauth1.Credentials? _accessCredentials;
  oauth1.Authorization? _auth;
  oauth1.Credentials? _tempCredentials;

  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    final consumerKey = dotenv.env['OP_CONSUMER_KEY'] ?? '';
    final consumerSecret = dotenv.env['OP_CONSUMER_SECRET'] ?? '';

    _clientCredentials = oauth1.ClientCredentials(consumerKey, consumerSecret);

    _platform = oauth1.Platform(
      'https://www.obsidianportal.com/oauth/request_token',
      'https://www.obsidianportal.com/oauth/authorize',
      'https://www.obsidianportal.com/oauth/access_token',
      oauth1.SignatureMethods.hmacSha1,
    );

    _auth = oauth1.Authorization(_clientCredentials, _platform);
  }

  bool get isAuthenticated => _accessCredentials != null;

  oauth1.ClientCredentials get clientCredentials => _clientCredentials;
  oauth1.Credentials? get accessCredentials => _accessCredentials;

  /// Check if we have stored tokens and load them.
  Future<bool> tryLoadStoredTokens() async {
    final token = await _storage.read(key: _accessTokenKey);
    final secret = await _storage.read(key: _accessSecretKey);

    if (token != null && secret != null) {
      _accessCredentials = oauth1.Credentials(token, secret);
      return true;
    }
    return false;
  }

  /// Step 1: Get a request token and return the authorization URL.
  Future<String> getAuthorizationUrl() async {
    final res = await _auth!.requestTemporaryCredentials('oob');
    _tempCredentials = res.credentials;
    return _auth!.getResourceOwnerAuthorizationURI(_tempCredentials!.token);
  }

  /// Step 2: Exchange the verifier PIN for access tokens.
  Future<void> exchangeVerifier(String verifier) async {
    if (_tempCredentials == null) {
      throw StateError('Must call getAuthorizationUrl() first');
    }

    final res = await _auth!.requestTokenCredentials(
      _tempCredentials!,
      verifier,
    );
    _accessCredentials = res.credentials;

    await _storage.write(
      key: _accessTokenKey,
      value: _accessCredentials!.token,
    );
    await _storage.write(
      key: _accessSecretKey,
      value: _accessCredentials!.tokenSecret,
    );
  }

  /// Open the authorization URL in an external browser.
  Future<void> launchAuthorizationUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch $url');
    }
  }

  /// Create an authenticated HTTP client.
  http.BaseClient createAuthenticatedClient() {
    if (_accessCredentials == null) {
      throw StateError('Not authenticated');
    }
    return oauth1.Client(
      _platform.signatureMethod,
      _clientCredentials,
      _accessCredentials!,
    );
  }

  /// Sign out: clear stored tokens.
  Future<void> signOut() async {
    _accessCredentials = null;
    _tempCredentials = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _accessSecretKey);
  }
}
