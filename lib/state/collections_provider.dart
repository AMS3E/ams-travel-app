import 'dart:collection';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api/ams_api.dart';
import 'auth_provider.dart';

/// What can be saved: the five kinds of card, and regions and provinces.
enum SavedKind {
  destination(FavoriteType.destination),
  stay(FavoriteType.stay),
  food(FavoriteType.food),
  activity(FavoriteType.activity),
  corridor(FavoriteType.corridor),
  region(FavoriteType.region),
  province(FavoriteType.province);

  const SavedKind(this.type);

  /// The favourite's target type.
  final FavoriteType type;

  static SavedKind of(CardType type) => values.firstWhere((k) => k.type.cardType == type);
}

/// The signed-in traveller's favourites (`GET /favorites`), newest first.
/// A guest has none; the heart offers to sign in.
class SavedProvider extends ChangeNotifier {
  SavedProvider(this._api, this._auth) {
    _auth.addListener(_onAuth);
    _onAuth();
  }

  final AmsApi _api;
  final AuthProvider _auth;
  bool _signedIn = false;
  List<Favorite> _items = [];
  bool _loaded = false;

  static String _id(FavoriteType type, String id) => '${type.code}:$id';
  Set<String> _ids = {};

  /// The cards found while checking the favourites, by [FoldersProvider.keyOf]
  /// key, so the Saved tab need not fetch them again.
  Map<String, PlaceCard> _cards = {};
  PlaceCard? cardFor(String key) => _cards[key];

  /// Newest first.
  List<Favorite> get favorites => UnmodifiableListView(_items);
  bool get isLoaded => _loaded;
  int get count => _items.length;

  bool isSaved(SavedKind kind, String id) => _ids.contains(_id(kind.type, id));

  /// Ids saved of one kind, newest first.
  List<String> idsOf(SavedKind kind) => [
    for (final f in _items)
      if (f.targetType == kind.type) f.targetId,
  ];

  void _onAuth() {
    final signedIn = _auth.isSignedIn;
    if (signedIn == _signedIn) return;
    _signedIn = signedIn;
    if (signedIn) {
      load();
    } else {
      _set([]);
      _loaded = false;
    }
  }

  Future<void>? _loading;

  /// Reads `GET /favorites` again. A call while one is under way shares it.
  Future<void> load() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    if (!_auth.isSignedIn) return;
    try {
      final items = await _hideCardless(await _api.favorites());
      items.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      _loaded = true;
      _set(items);
    } catch (_) {
      // Keeps what it had; the Saved tab offers a retry.
    }
  }

  /// Leaves out favourites the Saved tab cannot show: a place with no card
  /// (unpublished or deleted), or a region or province missing from the
  /// tourism regions or the provinces it names them from. Neither its count
  /// nor the nav badge should include them. If any of that cannot be read,
  /// keeps everything.
  Future<List<Favorite>> _hideCardless(List<Favorite> items) async {
    final byType = <CardType, List<String>>{};
    for (final f in items) {
      if (f.targetType.cardType case final type?) byType.putIfAbsent(type, () => []).add(f.targetId);
    }
    final hasRegions = items.any((f) => f.targetType == FavoriteType.region);
    final hasProvinces = items.any((f) => f.targetType == FavoriteType.province);
    try {
      final found = <String>{};
      final cards = <String, PlaceCard>{};
      await Future.wait([
        if (hasRegions) _api.tourismRegions().then((rs) => found.addAll(rs.map((r) => _id(FavoriteType.region, r.id)))),
        if (hasProvinces) _api.provinces().then((ps) => found.addAll(ps.map((p) => _id(FavoriteType.province, p.id)))),
        for (final e in byType.entries)
          _api.cards(e.value, type: e.key).then((list) {
            for (final c in list) {
              found.add(_id(SavedKind.of(e.key).type, c.id));
              cards[FoldersProvider.keyOf(c.type, c.id)] = c;
            }
          }),
      ]);
      _cards = cards;
      return [
        for (final f in items)
          if (found.contains(_id(f.targetType, f.targetId))) f,
      ];
    } catch (_) {
      return items;
    }
  }

  /// Saves or unsaves at once, then tells the API; puts it back if the API
  /// refuses. Returns the new state (true = now saved).
  Future<bool> toggle(SavedKind kind, String id) async {
    final type = kind.type;
    final before = _items;
    final nowSaved = !isSaved(kind, id);
    _set(
      nowSaved
          ? [Favorite(targetType: type, targetId: id, createdAt: DateTime.now()), ...before]
          : [
              for (final f in before)
                if (!(f.targetType == type && f.targetId == id)) f,
            ],
    );
    try {
      nowSaved ? await _api.addFavorite(type, id) : await _api.removeFavorite(type, id);
      return nowSaved;
    } catch (_) {
      _set(before);
      rethrow;
    }
  }

  void _set(List<Favorite> items) {
    _items = items;
    _ids = {for (final f in items) _id(f.targetType, f.targetId)};
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    super.dispose();
  }
}

/// Saved places grouped into named folders ("Kep/Kampot", "Cuisines"…),
/// kept on this phone. Each item is a favourite from the API, keyed
/// `CardType.code:id` (see [keyOf]).
///
/// Folders stay on the phone: parked 2026-10-14 (R-008).
class FoldersProvider extends ChangeNotifier {
  FoldersProvider(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _folders = (jsonDecode(raw) as Map).map(
          (k, v) => MapEntry(k.toString(), (v as List).map((e) => e.toString()).toList()),
        );
      } catch (_) {}
    }
  }

  /// A new key: folders from before the API held mock place keys.
  static const _key = 'ams-travel:folders-v2';
  final SharedPreferences _prefs;
  Map<String, List<String>> _folders = {};

  /// The key of a favourite inside a folder.
  static String keyOf(CardType type, String id) => '${type.code}:$id';

  /// The kind and id back from a [keyOf] key; null for anything else.
  static (CardType, String)? parse(String key) {
    final i = key.indexOf(':');
    if (i <= 0) return null;
    final type = CardType.tryParse(key.substring(0, i));
    return type == null ? null : (type, key.substring(i + 1));
  }

  List<String> get names => _folders.keys.toList();

  List<String> items(String folder) => List.unmodifiable(_folders[folder] ?? const []);

  bool contains(String folder, String key) => _folders[folder]?.contains(key) ?? false;

  void create(String name) {
    final clean = name.trim();
    if (clean.isEmpty || _folders.containsKey(clean)) return;
    _folders[clean] = [];
    _persist();
  }

  void remove(String folder) {
    if (_folders.remove(folder) != null) _persist();
  }

  /// Returns true when the item is now in the folder.
  bool toggleItem(String folder, String key) {
    final list = _folders.putIfAbsent(folder, () => []);
    final added = !list.remove(key);
    if (added) list.add(key);
    _persist();
    return added;
  }

  void _persist() {
    _prefs.setString(_key, jsonEncode(_folders));
    notifyListeners();
  }
}
