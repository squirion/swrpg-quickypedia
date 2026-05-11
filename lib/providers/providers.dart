import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swrpg_quickypedia/models/campaign.dart';
import 'package:swrpg_quickypedia/models/character.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/services/auth_service.dart';
import 'package:swrpg_quickypedia/services/api_client.dart';
import 'package:swrpg_quickypedia/services/system_data_store.dart';

// --- Auth ---

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final String? error;
  final String? authorizationUrl;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.error,
    this.authorizationUrl,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? error,
    String? authorizationUrl,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      error: error,
      authorizationUrl: authorizationUrl ?? this.authorizationUrl,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthService get _authService => ref.read(authServiceProvider);

  Future<void> checkStoredAuth() async {
    state = state.copyWith(isLoading: true);
    final hasTokens = await _authService.tryLoadStoredTokens();
    state = AuthState(
      status: hasTokens ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
  }

  Future<void> startOAuthFlow() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = await _authService.getAuthorizationUrl();
      await _authService.launchAuthorizationUrl(url);
      state = state.copyWith(
        authorizationUrl: url,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to start login: $e',
        isLoading: false,
      );
    }
  }

  Future<void> submitVerifier(String verifier) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.exchangeVerifier(verifier.trim());
      state = const AuthState(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to verify: $e',
        isLoading: false,
      );
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// --- API Client ---

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(authServiceProvider));
});

// --- Campaign ---

final campaignIdProvider = NotifierProvider<CampaignIdNotifier, String?>(() {
  return CampaignIdNotifier();
});

class CampaignIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setCampaign(String? id) => state = id;
}

class CampaignStorage {
  static const _key = 'last_campaign_id';

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> save(String campaignId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, campaignId);
  }
}

// --- Campaigns list ---

final campaignsProvider = FutureProvider.autoDispose<List<Campaign>>((ref) {
  return ref.watch(apiClientProvider).getCampaigns();
});

// --- Characters ---
//
// Both providers cache for the lifetime of the session (no autoDispose),
// so revisiting the home / bio screens does NOT re-hit the API.
// Pull-to-refresh invalidates the provider to force a re-fetch.

final charactersProvider = FutureProvider<List<Character>>((ref) async {
  final campaignId = ref.watch(campaignIdProvider);
  if (campaignId == null || campaignId.isEmpty) {
    return [];
  }
  final apiClient = ref.watch(apiClientProvider);
  return apiClient.getCharacters(campaignId);
});

/// Full character detail (includes the bio `content`), cached per id.
final characterDetailProvider =
    FutureProvider.family<Character, String>((ref, characterId) async {
  final campaignId = ref.watch(campaignIdProvider);
  if (campaignId == null || campaignId.isEmpty) {
    throw StateError('No campaign selected');
  }
  final apiClient = ref.watch(apiClientProvider);
  return apiClient.getCharacter(campaignId, characterId);
});

// --- System data: weapons ---
//
// System-dependent categories (weapons, armor, gear, vehicles, …) are
// shared across all users of the same RPG system. The data is scraped
// from the public Fandom wiki, cached on-device as JSON, and re-fetched
// on user request. This is the read-side; the scrape pipeline lives
// in lib/services/wiki_scraper.dart and is wired up in a later commit.

final weaponsStoreProvider = Provider<SystemDataStore>((_) {
  return const SystemDataStore('weapons');
});

final weaponsProvider = FutureProvider<List<Weapon>>((ref) async {
  final store = ref.watch(weaponsStoreProvider);
  return store.read<Weapon>(Weapon.fromJson);
});
