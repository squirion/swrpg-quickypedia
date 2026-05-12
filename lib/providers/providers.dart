import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swrpg_quickypedia/models/campaign.dart';
import 'package:swrpg_quickypedia/models/character.dart';
import 'package:swrpg_quickypedia/models/item_quality.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/models/weapon_sort.dart';
import 'package:swrpg_quickypedia/services/auth_service.dart';
import 'package:swrpg_quickypedia/services/api_client.dart';
import 'package:swrpg_quickypedia/services/github_data_repo.dart';
import 'package:swrpg_quickypedia/services/parsers/item_qualities_parser.dart';
import 'package:swrpg_quickypedia/services/parsers/weapon_parser.dart';
import 'package:swrpg_quickypedia/services/system_data_store.dart';
import 'package:swrpg_quickypedia/services/weapon_image_upload.dart';
import 'package:swrpg_quickypedia/services/weapon_sort.dart';
import 'package:swrpg_quickypedia/services/wiki_scraper.dart';

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

// --- GitHub data repo (shared image + JSON storage) ---

/// Configured from `.env`. The PAT is fine-grained and scoped to
/// just the swrpg-quickypedia-data repo with Contents: Read and write.
final githubDataRepoProvider = Provider<GithubDataRepo>((ref) {
  final repo = GithubDataRepo(
    owner: dotenv.env['GH_DATA_OWNER'] ?? '',
    repo: dotenv.env['GH_DATA_REPO'] ?? '',
    branch: dotenv.env['GH_DATA_BRANCH'] ?? 'main',
    pat: dotenv.env['GH_DATA_PAT'] ?? '',
  );
  ref.onDispose(repo.close);
  return repo;
});

/// Uploads a weapon image to the data repo and patches the cached
/// `weapons.json` with the new URL.
final weaponImageUploaderProvider = Provider<WeaponImageUploader>((ref) {
  final uploader = WeaponImageUploader(ref.watch(githubDataRepoProvider));
  ref.onDispose(uploader.close);
  return uploader;
});

/// HTTP headers to attach when fetching an image from the private data
/// repo. Returns null for non-github-raw URLs so we don't leak the PAT
/// to arbitrary origins.
Map<String, String>? githubAuthHeadersFor(String url, WidgetRef ref) {
  if (!url.startsWith('https://raw.githubusercontent.com/')) return null;
  return ref.read(githubDataRepoProvider).rawAuthHeaders;
}

/// Where each on-device JSON cache lives in the shared GitHub repo.
/// Keep this list in sync with the [SystemDataStore] keys used for
/// scraped data — anything added here is pulled/pushed by the cloud-
/// sync flow.
const Map<String, String> _kCloudDatabases = {
  'weapons': 'databases/weapons.json',
  'item_qualities': 'databases/item_qualities.json',
};

/// Lifecycle state for a cloud-sync action. `direction` is `'pull'`
/// or `'push'` while running; null when idle/error/done.
sealed class CloudSyncState {
  const CloudSyncState();
}

class CloudSyncIdle extends CloudSyncState {
  const CloudSyncIdle();
}

class CloudSyncRunning extends CloudSyncState {
  final String direction;
  const CloudSyncRunning(this.direction);
}

class CloudSyncError extends CloudSyncState {
  final String direction;
  final String message;
  const CloudSyncError(this.direction, this.message);
}

class CloudSyncResult {
  final String direction;
  final int succeeded;
  final int skipped;
  final List<String> errors;
  const CloudSyncResult({
    required this.direction,
    required this.succeeded,
    required this.skipped,
    required this.errors,
  });
}

final cloudSyncProvider =
    NotifierProvider<CloudSyncNotifier, CloudSyncState>(CloudSyncNotifier.new);

class CloudSyncNotifier extends Notifier<CloudSyncState> {
  @override
  CloudSyncState build() => const CloudSyncIdle();

  /// Pull each cached database from the GitHub data repo and overwrite
  /// the local copy. Missing files in the cloud are silently skipped
  /// (counted in [CloudSyncResult.skipped]).
  Future<CloudSyncResult> pullDatabases() async {
    return _run('pull', (gh) async {
      final errors = <String>[];
      var succeeded = 0;
      var skipped = 0;
      for (final entry in _kCloudDatabases.entries) {
        try {
          final bytes = await gh.readRaw(entry.value);
          if (bytes == null) {
            skipped++;
            continue;
          }
          await SystemDataStore(entry.key).writeBytes(bytes);
          succeeded++;
        } catch (e) {
          errors.add('${entry.key}: $e');
        }
      }
      ref.invalidate(weaponsProvider);
      ref.invalidate(itemQualitiesProvider);
      return CloudSyncResult(
        direction: 'pull',
        succeeded: succeeded,
        skipped: skipped,
        errors: errors,
      );
    });
  }

  /// Push each on-device cached database to the GitHub data repo.
  /// Locally-missing files are skipped (nothing to push). On a SHA
  /// conflict the underlying client refetches and retries once.
  Future<CloudSyncResult> pushDatabases() async {
    return _run('push', (gh) async {
      final errors = <String>[];
      var succeeded = 0;
      var skipped = 0;
      for (final entry in _kCloudDatabases.entries) {
        try {
          final bytes = await SystemDataStore(entry.key).readBytes();
          if (bytes == null) {
            skipped++;
            continue;
          }
          final current = await gh.getContents(entry.value);
          await gh.putFile(
            path: entry.value,
            bytes: bytes,
            commitMessage: 'Update ${entry.key} database',
            expectedSha: current?.sha,
          );
          succeeded++;
        } catch (e) {
          errors.add('${entry.key}: $e');
        }
      }
      return CloudSyncResult(
        direction: 'push',
        succeeded: succeeded,
        skipped: skipped,
        errors: errors,
      );
    });
  }

  Future<CloudSyncResult> _run(
    String direction,
    Future<CloudSyncResult> Function(GithubDataRepo) body,
  ) async {
    if (state is CloudSyncRunning) {
      return CloudSyncResult(
        direction: direction,
        succeeded: 0,
        skipped: 0,
        errors: const ['already running'],
      );
    }
    state = CloudSyncRunning(direction);
    try {
      final result = await body(ref.read(githubDataRepoProvider));
      state = const CloudSyncIdle();
      return result;
    } catch (e) {
      state = CloudSyncError(direction, e.toString());
      return CloudSyncResult(
        direction: direction,
        succeeded: 0,
        skipped: 0,
        errors: [e.toString()],
      );
    }
  }
}

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

/// Current sort preference, applied to every weapon list in the app.
/// Defaults to rarity ascending (most common first), with name as the
/// implicit secondary sort handled by [compareWeapons].
final weaponSortProvider =
    NotifierProvider<WeaponSortNotifier, WeaponSort>(WeaponSortNotifier.new);

class WeaponSortNotifier extends Notifier<WeaponSort> {
  @override
  WeaponSort build() => WeaponSort.defaultSort;

  /// Selecting the currently-active attribute toggles direction;
  /// selecting a different attribute keeps the current direction so
  /// the user doesn't have to re-flip every time they change axis.
  void select(WeaponSortAttr attr) {
    state = state.attr == attr
        ? state.copyWith(ascending: !state.ascending)
        : state.copyWith(attr: attr);
  }
}

final weaponsProvider = FutureProvider<List<Weapon>>((ref) async {
  final store = ref.watch(weaponsStoreProvider);
  final sort = ref.watch(weaponSortProvider);
  final list = await store.read<Weapon>(Weapon.fromJson);
  list.sort((a, b) => compareWeapons(a, b, sort));
  return list;
});

/// Lifecycle state for a category scrape (idle / running / error).
sealed class ScrapeState {
  const ScrapeState();
}

class ScrapeIdle extends ScrapeState {
  const ScrapeIdle();
}

class ScrapeRunning extends ScrapeState {
  /// `total == 0` until the index walk finishes — render as
  /// indeterminate when that's the case.
  final int done;
  final int total;
  const ScrapeRunning(this.done, this.total);
}

class ScrapeError extends ScrapeState {
  final String message;
  const ScrapeError(this.message);
}

const String _weaponsCategoryUrl =
    'https://star-wars-rpg-ffg.fandom.com/wiki/Category:Weapon';

final weaponsScrapeProvider =
    NotifierProvider<WeaponsScrapeNotifier, ScrapeState>(
  WeaponsScrapeNotifier.new,
);

/// Outcome of a weapons scrape — includes the chained item-qualities
/// scrape so the UI can report both counts (and any qualities error)
/// in a single feedback message.
class WeaponsScrapeResult {
  final int weapons;
  final int qualities;
  final String? weaponsError;
  final String? qualitiesError;

  const WeaponsScrapeResult({
    required this.weapons,
    required this.qualities,
    this.weaponsError,
    this.qualitiesError,
  });
}

class WeaponsScrapeNotifier extends Notifier<ScrapeState> {
  @override
  ScrapeState build() => const ScrapeIdle();

  /// Scrapes weapons, then refreshes the item-qualities glossary. The
  /// qualities refresh is best-effort: a network or parser failure
  /// there is surfaced via [WeaponsScrapeResult.qualitiesError] but
  /// does not flip the weapons scrape into an error state.
  Future<WeaponsScrapeResult> refresh() async {
    if (state is ScrapeRunning) {
      return const WeaponsScrapeResult(weapons: -1, qualities: -1);
    }
    state = const ScrapeRunning(0, 0);
    final scraper = WikiScraper();
    int weaponsCount = -1;
    String? weaponsError;
    try {
      final weapons = await scraper.scrapeCategory<Weapon>(
        categoryUrl: _weaponsCategoryUrl,
        parser: parseWeaponPage,
        onProgress: (done, total) {
          state = ScrapeRunning(done, total);
        },
      );
      await ref.read(weaponsStoreProvider).write<Weapon>(
            weapons,
            (w) => w.toJson(),
          );
      ref.invalidate(weaponsProvider);
      weaponsCount = weapons.length;
    } catch (e) {
      weaponsError = e.toString();
      state = ScrapeError(weaponsError);
    } finally {
      scraper.close();
    }

    int qualitiesCount = 0;
    String? qualitiesError;
    if (weaponsError == null) {
      try {
        qualitiesCount = await ref
            .read(itemQualitiesScrapeProvider.notifier)
            .refresh();
        if (qualitiesCount < 0) {
          // The qualities notifier surfaced its own ScrapeError state;
          // pull the message out so the snackbar can show it.
          final s = ref.read(itemQualitiesScrapeProvider);
          qualitiesError = s is ScrapeError ? s.message : 'unknown';
        }
      } catch (e) {
        qualitiesError = e.toString();
      }
    }

    if (weaponsError == null) state = const ScrapeIdle();
    return WeaponsScrapeResult(
      weapons: weaponsCount,
      qualities: qualitiesCount,
      weaponsError: weaponsError,
      qualitiesError: qualitiesError,
    );
  }
}

// --- System data: item qualities glossary ---
//
// The Item_Qualities wiki page is a single document that we re-parse on
// demand. Cached on-device as `item_qualities.json` so the weapon view
// can look up Pierce/Sunder/Stun/etc descriptions without any network
// hit after the initial fetch.

final itemQualitiesStoreProvider = Provider<SystemDataStore>((_) {
  return const SystemDataStore('item_qualities');
});

final itemQualitiesProvider =
    FutureProvider<Map<String, ItemQuality>>((ref) async {
  final store = ref.watch(itemQualitiesStoreProvider);
  final list = await store.read<ItemQuality>(ItemQuality.fromJson);
  return {
    for (final q in list) ItemQuality.lookupKey(q.name): q,
  };
});

final itemQualitiesScrapeProvider =
    NotifierProvider<ItemQualitiesScrapeNotifier, ScrapeState>(
  ItemQualitiesScrapeNotifier.new,
);

class ItemQualitiesScrapeNotifier extends Notifier<ScrapeState> {
  @override
  ScrapeState build() => const ScrapeIdle();

  /// Returns the number of qualities saved, or -1 on error.
  Future<int> refresh() async {
    if (state is ScrapeRunning) return -1;
    state = const ScrapeRunning(0, 0);
    try {
      final qualities = await fetchItemQualities();
      await ref.read(itemQualitiesStoreProvider).write<ItemQuality>(
            qualities,
            (q) => q.toJson(),
          );
      ref.invalidate(itemQualitiesProvider);
      state = const ScrapeIdle();
      return qualities.length;
    } catch (e) {
      state = ScrapeError(e.toString());
      return -1;
    }
  }
}
