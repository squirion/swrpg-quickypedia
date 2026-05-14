import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swrpg_quickypedia/models/armor.dart';
import 'package:swrpg_quickypedia/models/armor_sort.dart';
import 'package:swrpg_quickypedia/models/beast.dart';
import 'package:swrpg_quickypedia/models/beast_sort.dart';
import 'package:swrpg_quickypedia/models/campaign.dart';
import 'package:swrpg_quickypedia/models/character.dart';
import 'package:swrpg_quickypedia/models/gear.dart';
import 'package:swrpg_quickypedia/models/gear_sort.dart';
import 'package:swrpg_quickypedia/models/item_quality.dart';
import 'package:swrpg_quickypedia/models/recently_viewed_entry.dart';
import 'package:swrpg_quickypedia/models/starship.dart';
import 'package:swrpg_quickypedia/models/starship_sort.dart';
import 'package:swrpg_quickypedia/models/vehicle.dart';
import 'package:swrpg_quickypedia/models/vehicle_sort.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/models/weapon_sort.dart';
import 'package:swrpg_quickypedia/services/armor_image_upload.dart';
import 'package:swrpg_quickypedia/services/armor_sort.dart';
import 'package:swrpg_quickypedia/services/auth_service.dart';
import 'package:swrpg_quickypedia/services/api_client.dart';
import 'package:swrpg_quickypedia/services/beast_image_upload.dart';
import 'package:swrpg_quickypedia/services/beast_sort.dart';
import 'package:swrpg_quickypedia/services/gear_image_upload.dart';
import 'package:swrpg_quickypedia/services/gear_sort.dart';
import 'package:swrpg_quickypedia/services/github_data_repo.dart';
import 'package:swrpg_quickypedia/services/parsers/armor_parser.dart';
import 'package:swrpg_quickypedia/services/parsers/beast_parser.dart';
import 'package:swrpg_quickypedia/services/parsers/gear_parser.dart';
import 'package:swrpg_quickypedia/services/parsers/item_qualities_parser.dart';
import 'package:swrpg_quickypedia/services/parsers/starship_parser.dart';
import 'package:swrpg_quickypedia/services/parsers/vehicle_parser.dart';
import 'package:swrpg_quickypedia/services/parsers/weapon_parser.dart';
import 'package:swrpg_quickypedia/services/recently_viewed_store.dart';
import 'package:swrpg_quickypedia/services/starship_image_upload.dart';
import 'package:swrpg_quickypedia/services/starship_sort.dart';
import 'package:swrpg_quickypedia/services/vehicle_image_upload.dart';
import 'package:swrpg_quickypedia/services/vehicle_sort.dart';
import 'package:swrpg_quickypedia/services/system_data_store.dart';
import 'package:swrpg_quickypedia/services/weapon_image_upload.dart';
import 'package:swrpg_quickypedia/services/weapon_sort.dart';
import 'package:swrpg_quickypedia/services/wiki_index_walker.dart';
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

/// Uploads an armor image to the data repo and patches the cached
/// `armors.json` with the new URL.
final armorImageUploaderProvider = Provider<ArmorImageUploader>((ref) {
  final uploader = ArmorImageUploader(ref.watch(githubDataRepoProvider));
  ref.onDispose(uploader.close);
  return uploader;
});

/// Uploads a gear image to the data repo and patches the cached
/// `gear.json` with the new URL.
final gearImageUploaderProvider = Provider<GearImageUploader>((ref) {
  final uploader = GearImageUploader(ref.watch(githubDataRepoProvider));
  ref.onDispose(uploader.close);
  return uploader;
});

/// Uploads a vehicle image to the data repo and patches the cached
/// `vehicles.json` with the new URL.
final vehicleImageUploaderProvider = Provider<VehicleImageUploader>((ref) {
  final uploader = VehicleImageUploader(ref.watch(githubDataRepoProvider));
  ref.onDispose(uploader.close);
  return uploader;
});

/// Uploads a starship image to the data repo and patches the cached
/// `starships.json` with the new URL.
final starshipImageUploaderProvider = Provider<StarshipImageUploader>((ref) {
  final uploader = StarshipImageUploader(ref.watch(githubDataRepoProvider));
  ref.onDispose(uploader.close);
  return uploader;
});

/// Uploads a beast image to the data repo and patches the cached
/// `beasts.json` with the new URL.
final beastImageUploaderProvider = Provider<BeastImageUploader>((ref) {
  final uploader = BeastImageUploader(ref.watch(githubDataRepoProvider));
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
  'armors': 'databases/armors.json',
  'gear': 'databases/gear.json',
  'vehicles': 'databases/vehicles.json',
  'starships': 'databases/starships.json',
  'beasts': 'databases/beasts.json',
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
      ref.invalidate(armorsProvider);
      ref.invalidate(gearProvider);
      ref.invalidate(vehiclesProvider);
      ref.invalidate(starshipsProvider);
      ref.invalidate(beastsProvider);
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

// --- Global UI state: search query + home system sort ---
//
// Both providers are shared across home, type, and grid tiers so that
// state persists as the user navigates deeper. The search query is a
// simple Notifier<String>; the home system sort is a Notifier whose
// `select(attr)` method writes the equivalent attr to every per-
// category sort provider so e.g. picking "Alphabetical" on home
// re-sorts every system row immediately.

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
  void clear() => state = '';
}

/// Constrained sort menu exposed at the home System group. Maps to the
/// shared attrs every per-category sort enum carries.
enum HomeSystemSortAttr { rarity, price, alphabetical }

extension HomeSystemSortAttrLabel on HomeSystemSortAttr {
  String get label => switch (this) {
        HomeSystemSortAttr.rarity => 'Rarity',
        HomeSystemSortAttr.price => 'Price',
        HomeSystemSortAttr.alphabetical => 'Alphabetical',
      };
}

class HomeSystemSort {
  final HomeSystemSortAttr attr;
  final bool ascending;
  const HomeSystemSort({required this.attr, required this.ascending});

  static const HomeSystemSort defaultSort =
      HomeSystemSort(attr: HomeSystemSortAttr.rarity, ascending: true);

  HomeSystemSort copyWith({HomeSystemSortAttr? attr, bool? ascending}) =>
      HomeSystemSort(
        attr: attr ?? this.attr,
        ascending: ascending ?? this.ascending,
      );
}

final homeSystemSortProvider =
    NotifierProvider<HomeSystemSortNotifier, HomeSystemSort>(
  HomeSystemSortNotifier.new,
);

class HomeSystemSortNotifier extends Notifier<HomeSystemSort> {
  @override
  HomeSystemSort build() => HomeSystemSort.defaultSort;

  /// Selecting the active attr toggles direction; selecting a different
  /// attr keeps direction. Each change cascades into the 6 per-category
  /// sort providers so the new value takes effect immediately at every
  /// tier.
  void select(HomeSystemSortAttr attr) {
    state = state.attr == attr
        ? state.copyWith(ascending: !state.ascending)
        : state.copyWith(attr: attr);
    _propagate();
  }

  void _propagate() {
    final dir = state.ascending;
    final weaponAttr = switch (state.attr) {
      HomeSystemSortAttr.rarity => WeaponSortAttr.rarity,
      HomeSystemSortAttr.price => WeaponSortAttr.price,
      HomeSystemSortAttr.alphabetical => WeaponSortAttr.alphabetical,
    };
    final armorAttr = switch (state.attr) {
      HomeSystemSortAttr.rarity => ArmorSortAttr.rarity,
      HomeSystemSortAttr.price => ArmorSortAttr.price,
      HomeSystemSortAttr.alphabetical => ArmorSortAttr.alphabetical,
    };
    final gearAttr = switch (state.attr) {
      HomeSystemSortAttr.rarity => GearSortAttr.rarity,
      HomeSystemSortAttr.price => GearSortAttr.price,
      HomeSystemSortAttr.alphabetical => GearSortAttr.alphabetical,
    };
    final vehicleAttr = switch (state.attr) {
      HomeSystemSortAttr.rarity => VehicleSortAttr.rarity,
      HomeSystemSortAttr.price => VehicleSortAttr.price,
      HomeSystemSortAttr.alphabetical => VehicleSortAttr.alphabetical,
    };
    final starshipAttr = switch (state.attr) {
      HomeSystemSortAttr.rarity => StarshipSortAttr.rarity,
      HomeSystemSortAttr.price => StarshipSortAttr.price,
      HomeSystemSortAttr.alphabetical => StarshipSortAttr.alphabetical,
    };
    final beastAttr = switch (state.attr) {
      HomeSystemSortAttr.rarity => BeastSortAttr.rarity,
      HomeSystemSortAttr.price => BeastSortAttr.price,
      HomeSystemSortAttr.alphabetical => BeastSortAttr.alphabetical,
    };
    ref.read(weaponSortProvider.notifier).state =
        WeaponSort(attr: weaponAttr, ascending: dir);
    ref.read(armorSortProvider.notifier).state =
        ArmorSort(attr: armorAttr, ascending: dir);
    ref.read(gearSortProvider.notifier).state =
        GearSort(attr: gearAttr, ascending: dir);
    ref.read(vehicleSortProvider.notifier).state =
        VehicleSort(attr: vehicleAttr, ascending: dir);
    ref.read(starshipSortProvider.notifier).state =
        StarshipSort(attr: starshipAttr, ascending: dir);
    ref.read(beastSortProvider.notifier).state =
        BeastSort(attr: beastAttr, ascending: dir);
  }
}

// --- Recently viewed ---
//
// A 10-deep dedup'd FIFO queue of items the user has opened from a
// tile. Persisted to SharedPreferences so the queue survives restarts.
// Tap sites outside the Recently Viewed row call
// `recentlyViewedProvider.notifier.record(kind, id)` immediately before
// pushing the detail screen; the row itself does NOT call `record`, so
// reopening from the row preserves the queue's order.

final recentlyViewedStoreProvider =
    Provider<RecentlyViewedStore>((_) => RecentlyViewedStore());

final recentlyViewedProvider = AsyncNotifierProvider<RecentlyViewedNotifier,
    List<RecentlyViewedEntry>>(RecentlyViewedNotifier.new);

class RecentlyViewedNotifier
    extends AsyncNotifier<List<RecentlyViewedEntry>> {
  static const _max = 10;

  @override
  Future<List<RecentlyViewedEntry>> build() =>
      ref.read(recentlyViewedStoreProvider).load();

  Future<void> record(String kind, String id) async {
    final current = state.value ?? const <RecentlyViewedEntry>[];
    final next = <RecentlyViewedEntry>[
      RecentlyViewedEntry(kind: kind, id: id),
      ...current.where((e) => !(e.kind == kind && e.id == id)),
    ].take(_max).toList(growable: false);
    state = AsyncData(next);
    await ref.read(recentlyViewedStoreProvider).save(next);
  }
}

/// Join the persisted queue against the in-memory per-category lists,
/// returning the resolved (kind, item) pairs in queue order. Entries
/// whose underlying item is missing (e.g. dropped by a re-scrape) are
/// silently skipped — the persisted entry stays in storage in case the
/// item returns in a later scrape.
final recentlyViewedResolvedProvider =
    Provider<List<({String kind, Object item})>>((ref) {
  final entries = ref.watch(recentlyViewedProvider).value ?? const [];
  final weapons = ref.watch(weaponsProvider).value ?? const <Weapon>[];
  final armors = ref.watch(armorsProvider).value ?? const <Armor>[];
  final gears = ref.watch(gearProvider).value ?? const <Gear>[];
  final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
  final starships = ref.watch(starshipsProvider).value ?? const <Starship>[];
  final beasts = ref.watch(beastsProvider).value ?? const <Beast>[];
  final chars = ref.watch(charactersProvider).value ?? const <Character>[];

  final out = <({String kind, Object item})>[];
  for (final e in entries) {
    Object? match;
    switch (e.kind) {
      case 'weapon':
        match = _firstWhereOrNull<Weapon>(weapons, (w) => w.name == e.id);
      case 'armor':
        match = _firstWhereOrNull<Armor>(armors, (a) => a.name == e.id);
      case 'gear':
        match = _firstWhereOrNull<Gear>(gears, (g) => g.name == e.id);
      case 'vehicle':
        match = _firstWhereOrNull<Vehicle>(vehicles, (v) => v.name == e.id);
      case 'starship':
        match = _firstWhereOrNull<Starship>(starships, (s) => s.name == e.id);
      case 'beast':
        match = _firstWhereOrNull<Beast>(beasts, (b) => b.name == e.id);
      case 'character':
        match = _firstWhereOrNull<Character>(chars, (c) => c.id == e.id);
    }
    if (match != null) out.add((kind: e.kind, item: match));
  }
  return out;
});

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

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

// --- System data: armors ---
//
// Mirrors the weapons block above. The 3-tier rows on the type screen
// come from the `category` field on each armor (one of the canonical
// Fandom subcategory labels: "Attire & Other Clothes", "Worn Equipment",
// "Armor (Light)", "Armor (Heavy)", "Beast Armor & Equipment",
// "Legendary"). The scrape notifier itself lands with commit 2.

final armorsStoreProvider = Provider<SystemDataStore>((_) {
  return const SystemDataStore('armors');
});

/// Current sort preference, applied to every armor list in the app.
/// Defaults to rarity ascending (most common first), with name as the
/// implicit secondary sort handled by [compareArmors].
final armorSortProvider =
    NotifierProvider<ArmorSortNotifier, ArmorSort>(ArmorSortNotifier.new);

class ArmorSortNotifier extends Notifier<ArmorSort> {
  @override
  ArmorSort build() => ArmorSort.defaultSort;

  /// Selecting the currently-active attribute toggles direction;
  /// selecting a different attribute keeps the current direction so
  /// the user doesn't have to re-flip every time they change axis.
  void select(ArmorSortAttr attr) {
    state = state.attr == attr
        ? state.copyWith(ascending: !state.ascending)
        : state.copyWith(attr: attr);
  }
}

final armorsProvider = FutureProvider<List<Armor>>((ref) async {
  final store = ref.watch(armorsStoreProvider);
  final sort = ref.watch(armorSortProvider);
  final list = await store.read<Armor>(Armor.fromJson);
  list.sort((a, b) => compareArmors(a, b, sort));
  return list;
});

/// Canonical 3-tier groupings for armor. Iteration order doubles as the
/// row order on the type screen AND the first-match-wins priority when
/// the same armor is listed under multiple Fandom subcategories. Tweak
/// here if you want a specific bucket (e.g. Legendary) to win.
const String kArmorCategoryOther = 'Other';
const List<String> kArmorCategoryOrder = [
  'Attire & Other Clothes',
  'Worn Equipment',
  'Armor (Light)',
  'Armor (Heavy)',
  'Beast Armor & Equipment',
  'Legendary',
  kArmorCategoryOther,
];

/// Single index page for the armor catalogue. The wiki's
/// `Category:Armor` page contains a hand-written body where armors are
/// listed under H2/H3 section headers (`ATTIRE_&_OTHER_CLOTHES`,
/// `WORN_EQUIPMENT`, `LIGHT`, `HEAVY`, `BEAST_ARMOR_&_EQUIPMENT`,
/// `LEGENDARY`). The scraper walks that body to discover both the
/// armor URLs AND their bucket — no separate subcategory pages exist.
const String _kArmorIndexUrl =
    'https://star-wars-rpg-ffg.fandom.com/wiki/Category:Armor';

/// Maps the section IDs found in the wiki article body to the canonical
/// bucket labels used by the rest of the app. The `.26` is Fandom's
/// URL-encoded `&` (`%26` → `.26` in MediaWiki anchor IDs).
const Map<String, String> _kArmorSectionToCategory = {
  'ATTIRE_.26_OTHER_CLOTHES': 'Attire & Other Clothes',
  'WORN_EQUIPMENT': 'Worn Equipment',
  'LIGHT': 'Armor (Light)',
  'HEAVY': 'Armor (Heavy)',
  'BEAST_ARMOR_.26_EQUIPMENT': 'Beast Armor & Equipment',
  'LEGENDARY': 'Legendary',
};

final armorsScrapeProvider =
    NotifierProvider<ArmorsScrapeNotifier, ScrapeState>(
  ArmorsScrapeNotifier.new,
);

/// Outcome of an armors scrape — includes the chained item-qualities
/// refresh so the UI can report both counts (and any qualities error)
/// in a single feedback message.
class ArmorsScrapeResult {
  final int armors;
  final int qualities;
  final String? armorsError;
  final String? qualitiesError;

  const ArmorsScrapeResult({
    required this.armors,
    required this.qualities,
    this.armorsError,
    this.qualitiesError,
  });
}

class ArmorsScrapeNotifier extends Notifier<ScrapeState> {
  @override
  ScrapeState build() => const ScrapeIdle();

  /// Discover armors from the hand-written `Category:Armor` index, then
  /// fetch + parse each one. Bucketing comes from the H2/H3 section
  /// header the link appears under in the article body, mapped through
  /// [_kArmorSectionToCategory]. The item-qualities refresh runs
  /// afterward; failures there are surfaced via
  /// [ArmorsScrapeResult.qualitiesError] without failing the scrape.
  Future<ArmorsScrapeResult> refresh() async {
    if (state is ScrapeRunning) {
      return const ArmorsScrapeResult(armors: -1, qualities: -1);
    }
    state = const ScrapeRunning(0, 0);
    final scraper = WikiScraper();
    int armorsCount = -1;
    String? armorsError;
    try {
      // Step 1: build the URL → bucket index from the wiki article.
      final index = await _discoverArmorIndex(scraper);
      if (index.isEmpty) {
        throw StateError(
            'No armor links found under any of the 6 section headers '
            'on Category:Armor. Has the wiki been restructured?');
      }
      final urls = index.keys.toList(growable: false);
      state = ScrapeRunning(0, urls.length);

      // Step 2: fetch + parse each unique armor page.
      final all = <Armor>[];
      for (var i = 0; i < urls.length; i++) {
        final url = urls[i];
        final bucket = index[url]!;
        try {
          final doc = await scraper.fetchDocument(url);
          final parsed = parseArmorPage(doc, url);
          if (parsed != null) {
            all.add(_withCategory(parsed, bucket));
          }
        } catch (_) {
          // Skip pages that fail to fetch/parse — same convention as
          // the weapons scraper.
        }
        state = ScrapeRunning(i + 1, urls.length);
      }

      await ref.read(armorsStoreProvider).write<Armor>(
            all,
            (a) => a.toJson(),
          );
      ref.invalidate(armorsProvider);
      armorsCount = all.length;
    } catch (e) {
      armorsError = e.toString();
      state = ScrapeError(armorsError);
    } finally {
      scraper.close();
    }

    int qualitiesCount = 0;
    String? qualitiesError;
    if (armorsError == null) {
      try {
        qualitiesCount = await ref
            .read(itemQualitiesScrapeProvider.notifier)
            .refresh();
        if (qualitiesCount < 0) {
          final s = ref.read(itemQualitiesScrapeProvider);
          qualitiesError = s is ScrapeError ? s.message : 'unknown';
        }
      } catch (e) {
        qualitiesError = e.toString();
      }
    }

    if (armorsError == null) state = const ScrapeIdle();
    return ArmorsScrapeResult(
      armors: armorsCount,
      qualities: qualitiesCount,
      armorsError: armorsError,
      qualitiesError: qualitiesError,
    );
  }
}

Future<Map<String, String>> _discoverArmorIndex(WikiScraper scraper) =>
    discoverByArticleHeaders(
      scraper: scraper,
      indexUrl: _kArmorIndexUrl,
      sectionToBucket: _kArmorSectionToCategory,
    );

/// Build a copy of [a] with [category] replaced. Armor is immutable and
/// doesn't carry a copyWith, so rebuild via JSON.
Armor _withCategory(Armor a, String category) {
  final json = a.toJson();
  json['category'] = category;
  return Armor.fromJson(json);
}

// --- System data: gear ---
//
// Mirrors the armor block. Sections come from the hand-written
// `Category:Gear` article body; the discovery helper walks H2/H3
// anchor IDs and the parser fetches each linked page.

final gearStoreProvider = Provider<SystemDataStore>((_) {
  return const SystemDataStore('gear');
});

final gearSortProvider =
    NotifierProvider<GearSortNotifier, GearSort>(GearSortNotifier.new);

class GearSortNotifier extends Notifier<GearSort> {
  @override
  GearSort build() => GearSort.defaultSort;

  void select(GearSortAttr attr) {
    state = state.attr == attr
        ? state.copyWith(ascending: !state.ascending)
        : state.copyWith(attr: attr);
  }
}

final gearProvider = FutureProvider<List<Gear>>((ref) async {
  final store = ref.watch(gearStoreProvider);
  final sort = ref.watch(gearSortProvider);
  final list = await store.read<Gear>(Gear.fromJson);
  list.sort((a, b) => compareGear(a, b, sort));
  return list;
});

/// Canonical row order for the gear type screen, mirroring the wiki's
/// article-body section order (top to bottom). Items whose `category`
/// is null or doesn't match one of these labels land in "Other".
const String kGearCategoryOther = 'Other';
const List<String> kGearCategoryOrder = [
  'Communication Technology',
  'Carrying & Load-Bearing Gear',
  'Drugs',
  'Poisons',
  'Other Consumables & Food',
  'Cybernetics',
  'Detection Technology',
  'Field Equipment',
  'Infiltration',
  'Medical',
  'Relics',
  'Security',
  'Survival',
  'Accessories',
  'Electronics',
  'Recreation',
  'Tools',
  'Legendary',
  kGearCategoryOther,
];

const String _kGearIndexUrl =
    'https://star-wars-rpg-ffg.fandom.com/wiki/Category:Gear';

/// Section anchor ID → canonical bucket label. Keys come from a one-shot
/// discovery pass on the wiki article body; values are the user-facing
/// labels in [kGearCategoryOrder].
const Map<String, String> _kGearSectionToCategory = {
  'COMMUNICATION_TECHNOLOGY': 'Communication Technology',
  'CARRYING_.26_LOAD-BEARING_GEAR': 'Carrying & Load-Bearing Gear',
  'DRUGS': 'Drugs',
  'POISONS': 'Poisons',
  'OTHER_CONSUMABLES_AND_FOOD': 'Other Consumables & Food',
  'CYBERNETICS': 'Cybernetics',
  'DETECTION_TECHNOLOGY': 'Detection Technology',
  'FIELD_EQUIPMENT': 'Field Equipment',
  'INFILTRATION': 'Infiltration',
  'MEDICAL': 'Medical',
  'RELICS': 'Relics',
  'SECURITY': 'Security',
  'SURVIVAL': 'Survival',
  'ACCESSORIES': 'Accessories',
  'ELECTRONICS': 'Electronics',
  'RECREATION': 'Recreation',
  'TOOLS': 'Tools',
  'LEGENDARY': 'Legendary',
};

final gearScrapeProvider =
    NotifierProvider<GearScrapeNotifier, ScrapeState>(
  GearScrapeNotifier.new,
);

class GearScrapeResult {
  final int gear;
  final int qualities;
  final int failedPages;
  final String? gearError;
  final String? qualitiesError;
  const GearScrapeResult({
    required this.gear,
    required this.qualities,
    this.failedPages = 0,
    this.gearError,
    this.qualitiesError,
  });
}

class GearScrapeNotifier extends Notifier<ScrapeState> {
  @override
  ScrapeState build() => const ScrapeIdle();

  Future<GearScrapeResult> refresh() async {
    if (state is ScrapeRunning) {
      return const GearScrapeResult(gear: -1, qualities: -1);
    }
    state = const ScrapeRunning(0, 0);
    final scraper = WikiScraper();
    int gearCount = -1;
    int failedCount = 0;
    String? gearError;
    try {
      final index = await discoverByArticleHeaders(
        scraper: scraper,
        indexUrl: _kGearIndexUrl,
        sectionToBucket: _kGearSectionToCategory,
      );
      if (index.isEmpty) {
        throw StateError(
            'No gear links found under any of the ${_kGearSectionToCategory.length} '
            'tracked sections on Category:Gear. Wiki restructured?');
      }
      final urls = index.keys.toList(growable: false);
      state = ScrapeRunning(0, urls.length);

      final all = <Gear>[];
      var consecutiveFailures = 0;
      var failedPages = 0;
      for (var i = 0; i < urls.length; i++) {
        final url = urls[i];
        final bucket = index[url]!;
        Gear? parsed;
        Object? lastError;
        // 3 attempts with 1s / 3s backoff. Soaks up transient mobile-
        // network blips without masking real parse failures (the
        // parser itself raises no exceptions — it returns null).
        for (var attempt = 0; attempt < 3 && parsed == null; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(
                Duration(seconds: attempt == 1 ? 1 : 3));
          }
          try {
            final doc = await scraper.fetchDocument(url);
            parsed = parseGearPage(doc, url);
            lastError = null;
            break;
          } catch (e) {
            lastError = e;
          }
        }
        if (parsed != null) {
          all.add(_withGearCategory(parsed, bucket));
          consecutiveFailures = 0;
        } else {
          if (lastError != null) failedPages++;
          consecutiveFailures++;
          // 30 consecutive failures = network is definitively down;
          // bail out so the user gets a clear error instead of a long
          // silent wait through hundreds of timeouts.
          if (consecutiveFailures >= 30) {
            throw StateError(
                'Network appears to be down — aborted after 30 '
                'consecutive failures (${i + 1} / ${urls.length} pages).');
          }
        }
        state = ScrapeRunning(i + 1, urls.length);
      }

      await ref.read(gearStoreProvider).write<Gear>(
            all,
            (g) => g.toJson(),
          );
      ref.invalidate(gearProvider);
      gearCount = all.length;
      failedCount = failedPages;
    } catch (e) {
      gearError = e.toString();
      state = ScrapeError(gearError);
    } finally {
      scraper.close();
    }

    int qualitiesCount = 0;
    String? qualitiesError;
    if (gearError == null) {
      try {
        qualitiesCount = await ref
            .read(itemQualitiesScrapeProvider.notifier)
            .refresh();
        if (qualitiesCount < 0) {
          final s = ref.read(itemQualitiesScrapeProvider);
          qualitiesError = s is ScrapeError ? s.message : 'unknown';
        }
      } catch (e) {
        qualitiesError = e.toString();
      }
    }

    if (gearError == null) state = const ScrapeIdle();
    return GearScrapeResult(
      gear: gearCount,
      qualities: qualitiesCount,
      failedPages: failedCount,
      gearError: gearError,
      qualitiesError: qualitiesError,
    );
  }
}

Gear _withGearCategory(Gear g, String category) {
  final json = g.toJson();
  json['category'] = category;
  return Gear.fromJson(json);
}

// --- System data: vehicles ---
//
// Same article-body-walker pattern as armor + gear. Vehicles carry the
// 4-defense-zone alt format and a plain-text transport-stats paragraph
// below the stat image; both are extracted by the vehicle parser.

final vehiclesStoreProvider = Provider<SystemDataStore>((_) {
  return const SystemDataStore('vehicles');
});

final vehicleSortProvider =
    NotifierProvider<VehicleSortNotifier, VehicleSort>(
  VehicleSortNotifier.new,
);

class VehicleSortNotifier extends Notifier<VehicleSort> {
  @override
  VehicleSort build() => VehicleSort.defaultSort;

  void select(VehicleSortAttr attr) {
    state = state.attr == attr
        ? state.copyWith(ascending: !state.ascending)
        : state.copyWith(attr: attr);
  }
}

final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final store = ref.watch(vehiclesStoreProvider);
  final sort = ref.watch(vehicleSortProvider);
  final list = await store.read<Vehicle>(Vehicle.fromJson);
  list.sort((a, b) => compareVehicles(a, b, sort));
  return list;
});

const String kVehicleCategoryOther = 'Other';
const List<String> kVehicleCategoryOrder = [
  'Walkers',
  'Wheeled',
  'Tracked',
  'Submersibles',
  'Landspeeders',
  'Airspeeders',
  'Podracers',
  'Equipment as Vehicles',
  'Legendary',
  kVehicleCategoryOther,
];

const String _kVehicleIndexUrl =
    'https://star-wars-rpg-ffg.fandom.com/wiki/Category:Vehicles';

const Map<String, String> _kVehicleSectionToCategory = {
  'WALKERS': 'Walkers',
  'WHEELED': 'Wheeled',
  'TRACKED': 'Tracked',
  'SUBMERSIBLES': 'Submersibles',
  'LANDSPEEDERS': 'Landspeeders',
  'AIRSPEEDERS': 'Airspeeders',
  'PODRACERS': 'Podracers',
  'EQUIPMENT_AS_VEHICLES': 'Equipment as Vehicles',
  'LEGENDARY': 'Legendary',
};

final vehiclesScrapeProvider =
    NotifierProvider<VehiclesScrapeNotifier, ScrapeState>(
  VehiclesScrapeNotifier.new,
);

class VehiclesScrapeResult {
  final int vehicles;
  final int qualities;
  final int failedPages;
  final String? vehiclesError;
  final String? qualitiesError;
  const VehiclesScrapeResult({
    required this.vehicles,
    required this.qualities,
    this.failedPages = 0,
    this.vehiclesError,
    this.qualitiesError,
  });
}

class VehiclesScrapeNotifier extends Notifier<ScrapeState> {
  @override
  ScrapeState build() => const ScrapeIdle();

  Future<VehiclesScrapeResult> refresh() async {
    if (state is ScrapeRunning) {
      return const VehiclesScrapeResult(vehicles: -1, qualities: -1);
    }
    state = const ScrapeRunning(0, 0);
    final scraper = WikiScraper();
    int vehiclesCount = -1;
    int failedCount = 0;
    String? vehiclesError;
    try {
      final index = await discoverByArticleHeaders(
        scraper: scraper,
        indexUrl: _kVehicleIndexUrl,
        sectionToBucket: _kVehicleSectionToCategory,
      );
      if (index.isEmpty) {
        throw StateError(
            'No vehicle links found under any of the '
            '${_kVehicleSectionToCategory.length} tracked sections on '
            'Category:Vehicles. Wiki restructured?');
      }
      final urls = index.keys.toList(growable: false);
      state = ScrapeRunning(0, urls.length);

      final all = <Vehicle>[];
      var consecutiveFailures = 0;
      var failedPages = 0;
      for (var i = 0; i < urls.length; i++) {
        final url = urls[i];
        final bucket = index[url]!;
        Vehicle? parsed;
        Object? lastError;
        for (var attempt = 0; attempt < 3 && parsed == null; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(
                Duration(seconds: attempt == 1 ? 1 : 3));
          }
          try {
            final doc = await scraper.fetchDocument(url);
            parsed = parseVehiclePage(doc, url);
            lastError = null;
            break;
          } catch (e) {
            lastError = e;
          }
        }
        if (parsed != null) {
          all.add(_withVehicleCategory(parsed, bucket));
          consecutiveFailures = 0;
        } else {
          if (lastError != null) failedPages++;
          consecutiveFailures++;
          if (consecutiveFailures >= 30) {
            throw StateError(
                'Network appears to be down — aborted after 30 '
                'consecutive failures (${i + 1} / ${urls.length} pages).');
          }
        }
        state = ScrapeRunning(i + 1, urls.length);
      }

      await ref.read(vehiclesStoreProvider).write<Vehicle>(
            all,
            (v) => v.toJson(),
          );
      ref.invalidate(vehiclesProvider);
      vehiclesCount = all.length;
      failedCount = failedPages;
    } catch (e) {
      vehiclesError = e.toString();
      state = ScrapeError(vehiclesError);
    } finally {
      scraper.close();
    }

    int qualitiesCount = 0;
    String? qualitiesError;
    if (vehiclesError == null) {
      try {
        qualitiesCount = await ref
            .read(itemQualitiesScrapeProvider.notifier)
            .refresh();
        if (qualitiesCount < 0) {
          final s = ref.read(itemQualitiesScrapeProvider);
          qualitiesError = s is ScrapeError ? s.message : 'unknown';
        }
      } catch (e) {
        qualitiesError = e.toString();
      }
    }

    if (vehiclesError == null) state = const ScrapeIdle();
    return VehiclesScrapeResult(
      vehicles: vehiclesCount,
      qualities: qualitiesCount,
      failedPages: failedCount,
      vehiclesError: vehiclesError,
      qualitiesError: qualitiesError,
    );
  }
}

Vehicle _withVehicleCategory(Vehicle v, String category) {
  final json = v.toJson();
  json['category'] = category;
  return Vehicle.fromJson(json);
}

// --- System data: starships ---
//
// Starships share the vehicle pipeline shape (same article-body section
// walker, same retry-with-backoff). The detail screen adds rows for
// Hyperdrive / Navicomputer / Hull Type/Class / Manufacturer / Ship's
// Complement, which the starship parser pulls from the post-stat text
// paragraph.

final starshipsStoreProvider = Provider<SystemDataStore>((_) {
  return const SystemDataStore('starships');
});

final starshipSortProvider =
    NotifierProvider<StarshipSortNotifier, StarshipSort>(
  StarshipSortNotifier.new,
);

class StarshipSortNotifier extends Notifier<StarshipSort> {
  @override
  StarshipSort build() => StarshipSort.defaultSort;

  void select(StarshipSortAttr attr) {
    state = state.attr == attr
        ? state.copyWith(ascending: !state.ascending)
        : state.copyWith(attr: attr);
  }
}

final starshipsProvider = FutureProvider<List<Starship>>((ref) async {
  final store = ref.watch(starshipsStoreProvider);
  final sort = ref.watch(starshipSortProvider);
  final list = await store.read<Starship>(Starship.fromJson);
  list.sort((a, b) => compareStarships(a, b, sort));
  return list;
});

const String kStarshipCategoryOther = 'Other';
const List<String> kStarshipCategoryOrder = [
  'Starfighters',
  'Shuttles',
  'Patrol Boats',
  'Freighters',
  'Other Transports',
  'Capital Ships',
  'Stations',
  'Legendary',
  kStarshipCategoryOther,
];

const String _kStarshipIndexUrl =
    'https://star-wars-rpg-ffg.fandom.com/wiki/Category:Starships';

const Map<String, String> _kStarshipSectionToCategory = {
  'STARFIGHTERS': 'Starfighters',
  'SHUTTLES': 'Shuttles',
  'PATROL_BOATS': 'Patrol Boats',
  'FREIGHTERS': 'Freighters',
  'OTHER_TRANSPORTS': 'Other Transports',
  'CAPITAL_SHIPS': 'Capital Ships',
  'STATIONS': 'Stations',
  'LEGENDARY': 'Legendary',
};

final starshipsScrapeProvider =
    NotifierProvider<StarshipsScrapeNotifier, ScrapeState>(
  StarshipsScrapeNotifier.new,
);

class StarshipsScrapeResult {
  final int starships;
  final int qualities;
  final int failedPages;
  final String? starshipsError;
  final String? qualitiesError;
  const StarshipsScrapeResult({
    required this.starships,
    required this.qualities,
    this.failedPages = 0,
    this.starshipsError,
    this.qualitiesError,
  });
}

class StarshipsScrapeNotifier extends Notifier<ScrapeState> {
  @override
  ScrapeState build() => const ScrapeIdle();

  Future<StarshipsScrapeResult> refresh() async {
    if (state is ScrapeRunning) {
      return const StarshipsScrapeResult(starships: -1, qualities: -1);
    }
    state = const ScrapeRunning(0, 0);
    final scraper = WikiScraper();
    int starshipsCount = -1;
    int failedCount = 0;
    String? starshipsError;
    try {
      final index = await discoverByArticleHeaders(
        scraper: scraper,
        indexUrl: _kStarshipIndexUrl,
        sectionToBucket: _kStarshipSectionToCategory,
      );
      if (index.isEmpty) {
        throw StateError(
            'No starship links found under any of the '
            '${_kStarshipSectionToCategory.length} tracked sections on '
            'Category:Starships. Wiki restructured?');
      }
      final urls = index.keys.toList(growable: false);
      state = ScrapeRunning(0, urls.length);

      final all = <Starship>[];
      var consecutiveFailures = 0;
      var failedPages = 0;
      for (var i = 0; i < urls.length; i++) {
        final url = urls[i];
        final bucket = index[url]!;
        Starship? parsed;
        Object? lastError;
        for (var attempt = 0; attempt < 3 && parsed == null; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(
                Duration(seconds: attempt == 1 ? 1 : 3));
          }
          try {
            final doc = await scraper.fetchDocument(url);
            parsed = parseStarshipPage(doc, url);
            lastError = null;
            break;
          } catch (e) {
            lastError = e;
          }
        }
        if (parsed != null) {
          all.add(_withStarshipCategory(parsed, bucket));
          consecutiveFailures = 0;
        } else {
          if (lastError != null) failedPages++;
          consecutiveFailures++;
          if (consecutiveFailures >= 30) {
            throw StateError(
                'Network appears to be down — aborted after 30 '
                'consecutive failures (${i + 1} / ${urls.length} pages).');
          }
        }
        state = ScrapeRunning(i + 1, urls.length);
      }

      await ref.read(starshipsStoreProvider).write<Starship>(
            all,
            (s) => s.toJson(),
          );
      ref.invalidate(starshipsProvider);
      starshipsCount = all.length;
      failedCount = failedPages;
    } catch (e) {
      starshipsError = e.toString();
      state = ScrapeError(starshipsError);
    } finally {
      scraper.close();
    }

    int qualitiesCount = 0;
    String? qualitiesError;
    if (starshipsError == null) {
      try {
        qualitiesCount = await ref
            .read(itemQualitiesScrapeProvider.notifier)
            .refresh();
        if (qualitiesCount < 0) {
          final s = ref.read(itemQualitiesScrapeProvider);
          qualitiesError = s is ScrapeError ? s.message : 'unknown';
        }
      } catch (e) {
        qualitiesError = e.toString();
      }
    }

    if (starshipsError == null) state = const ScrapeIdle();
    return StarshipsScrapeResult(
      starships: starshipsCount,
      qualities: qualitiesCount,
      failedPages: failedCount,
      starshipsError: starshipsError,
      qualitiesError: qualitiesError,
    );
  }
}

Starship _withStarshipCategory(Starship s, String category) {
  final json = s.toJson();
  json['category'] = category;
  return Starship.fromJson(json);
}

// --- System data: beasts ---
//
// Beasts are creatures rather than items — same article-body walker
// for discovery, same retry-with-backoff, but the parser pulls two
// separate stat-image alts (commerce + creature) and the detail
// screen has a bespoke characteristic-grid layout.

final beastsStoreProvider = Provider<SystemDataStore>((_) {
  return const SystemDataStore('beasts');
});

final beastSortProvider =
    NotifierProvider<BeastSortNotifier, BeastSort>(BeastSortNotifier.new);

class BeastSortNotifier extends Notifier<BeastSort> {
  @override
  BeastSort build() => BeastSort.defaultSort;

  void select(BeastSortAttr attr) {
    state = state.attr == attr
        ? state.copyWith(ascending: !state.ascending)
        : state.copyWith(attr: attr);
  }
}

final beastsProvider = FutureProvider<List<Beast>>((ref) async {
  final store = ref.watch(beastsStoreProvider);
  final sort = ref.watch(beastSortProvider);
  final list = await store.read<Beast>(Beast.fromJson);
  list.sort((a, b) => compareBeasts(a, b, sort));
  return list;
});

const String kBeastCategoryOther = 'Other';
const List<String> kBeastCategoryOrder = [
  'Riding Beasts',
  'Small Pets (Silh 0)',
  'Companions (Silh 1)',
  kBeastCategoryOther,
];

const String _kBeastIndexUrl =
    'https://star-wars-rpg-ffg.fandom.com/wiki/Category:Beast';

const Map<String, String> _kBeastSectionToCategory = {
  'RIDING_BEASTS': 'Riding Beasts',
  'SMALL_PETS_.28SILH0.29': 'Small Pets (Silh 0)',
  'COMPANIONS_.28SILH1.29': 'Companions (Silh 1)',
};

final beastsScrapeProvider =
    NotifierProvider<BeastsScrapeNotifier, ScrapeState>(
  BeastsScrapeNotifier.new,
);

class BeastsScrapeResult {
  final int beasts;
  final int failedPages;
  final String? beastsError;
  const BeastsScrapeResult({
    required this.beasts,
    this.failedPages = 0,
    this.beastsError,
  });
}

class BeastsScrapeNotifier extends Notifier<ScrapeState> {
  @override
  ScrapeState build() => const ScrapeIdle();

  Future<BeastsScrapeResult> refresh() async {
    if (state is ScrapeRunning) {
      return const BeastsScrapeResult(beasts: -1);
    }
    state = const ScrapeRunning(0, 0);
    final scraper = WikiScraper();
    int beastsCount = -1;
    int failedCount = 0;
    String? beastsError;
    try {
      final index = await discoverByArticleHeaders(
        scraper: scraper,
        indexUrl: _kBeastIndexUrl,
        sectionToBucket: _kBeastSectionToCategory,
      );
      if (index.isEmpty) {
        throw StateError(
            'No beast links found under any of the '
            '${_kBeastSectionToCategory.length} tracked sections on '
            'Category:Beast. Wiki restructured?');
      }
      final urls = index.keys.toList(growable: false);
      state = ScrapeRunning(0, urls.length);

      final all = <Beast>[];
      var consecutiveFailures = 0;
      var failedPages = 0;
      for (var i = 0; i < urls.length; i++) {
        final url = urls[i];
        final bucket = index[url]!;
        Beast? parsed;
        Object? lastError;
        for (var attempt = 0; attempt < 3 && parsed == null; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(
                Duration(seconds: attempt == 1 ? 1 : 3));
          }
          try {
            final doc = await scraper.fetchDocument(url);
            parsed = parseBeastPage(doc, url);
            lastError = null;
            break;
          } catch (e) {
            lastError = e;
          }
        }
        if (parsed != null) {
          all.add(_withBeastCategory(parsed, bucket));
          consecutiveFailures = 0;
        } else {
          if (lastError != null) failedPages++;
          consecutiveFailures++;
          if (consecutiveFailures >= 30) {
            throw StateError(
                'Network appears to be down — aborted after 30 '
                'consecutive failures (${i + 1} / ${urls.length} pages).');
          }
        }
        state = ScrapeRunning(i + 1, urls.length);
      }

      await ref.read(beastsStoreProvider).write<Beast>(
            all,
            (b) => b.toJson(),
          );
      ref.invalidate(beastsProvider);
      beastsCount = all.length;
      failedCount = failedPages;
    } catch (e) {
      beastsError = e.toString();
      state = ScrapeError(beastsError);
    } finally {
      scraper.close();
    }

    // No chained qualities scrape — beast special qualities (e.g.
    // "Sure-footed", "Pack Instincts") live inside the abilities text
    // verbatim and aren't part of the shared Item Qualities glossary.
    if (beastsError == null) state = const ScrapeIdle();
    return BeastsScrapeResult(
      beasts: beastsCount,
      failedPages: failedCount,
      beastsError: beastsError,
    );
  }
}

Beast _withBeastCategory(Beast b, String category) {
  final json = b.toJson();
  json['category'] = category;
  return Beast.fromJson(json);
}
