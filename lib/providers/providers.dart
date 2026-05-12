import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swrpg_quickypedia/models/armor.dart';
import 'package:swrpg_quickypedia/models/armor_sort.dart';
import 'package:swrpg_quickypedia/models/campaign.dart';
import 'package:swrpg_quickypedia/models/character.dart';
import 'package:swrpg_quickypedia/models/item_quality.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/models/weapon_sort.dart';
import 'package:swrpg_quickypedia/services/armor_image_upload.dart';
import 'package:swrpg_quickypedia/services/armor_sort.dart';
import 'package:swrpg_quickypedia/services/auth_service.dart';
import 'package:swrpg_quickypedia/services/api_client.dart';
import 'package:swrpg_quickypedia/services/github_data_repo.dart';
import 'package:swrpg_quickypedia/services/parsers/armor_parser.dart';
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

/// Uploads an armor image to the data repo and patches the cached
/// `armors.json` with the new URL.
final armorImageUploaderProvider = Provider<ArmorImageUploader>((ref) {
  final uploader = ArmorImageUploader(ref.watch(githubDataRepoProvider));
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

/// Walk the `Category:Armor` article body and build a map of
/// `armor_page_url → bucket_label`. The wiki groups armors under H2/H3
/// headers with anchor IDs from [_kArmorSectionToCategory]; everything
/// outside those sections is ignored. Duplicate links (a few sections
/// repeat the same armor) keep the FIRST bucket they appear in.
Future<Map<String, String>> _discoverArmorIndex(WikiScraper scraper) async {
  final doc = await scraper.fetchDocument(_kArmorIndexUrl);
  final article = doc.querySelector('.mw-parser-output');
  if (article == null) return const {};

  final out = <String, String>{};
  String? currentBucket;
  final origin = Uri.parse(_kArmorIndexUrl).origin;

  void visit(dynamic node) {
    final tag = node.localName as String?;
    if (tag == 'h1' || tag == 'h2' || tag == 'h3' || tag == 'h4') {
      // Anchor ID lives on the heading itself or on its `.mw-headline`
      // child (MediaWiki convention varies by theme).
      final id = (node.attributes['id'] as String?) ??
          node.querySelector('[id]')?.attributes['id'];
      currentBucket = id == null ? null : _kArmorSectionToCategory[id];
      return;
    }
    if (tag == 'a') {
      final href = node.attributes['href'] as String?;
      if (href != null &&
          href.startsWith('/wiki/') &&
          !href.contains(':') &&
          currentBucket != null) {
        final url = '$origin$href';
        out.putIfAbsent(url, () => currentBucket!);
      }
      return;
    }
    for (final c in node.children) {
      visit(c);
    }
  }

  for (final c in article.children) {
    visit(c);
  }
  return out;
}

/// Build a copy of [a] with [category] replaced. Armor is immutable and
/// doesn't carry a copyWith, so rebuild via JSON.
Armor _withCategory(Armor a, String category) {
  final json = a.toJson();
  json['category'] = category;
  return Armor.fromJson(json);
}
