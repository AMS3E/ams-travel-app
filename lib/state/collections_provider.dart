import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/models.dart';

/// What can be bookmarked — the website saves places, regions and corridors.
enum SavedKind { destination, region, province, corridor }

/// Bookmarks, stored on the device (works without an account, like the
/// website). Newest first.
///
/// TODO(api): once `/me/saved` exists, sync this list after login.
class SavedProvider extends ChangeNotifier {
  SavedProvider(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _items = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      } catch (_) {}
    }
  }

  static const _key = 'ams-travel:saved';
  static const _seededKey = 'ams-travel:saved-seeded';
  final SharedPreferences _prefs;
  List<String> _items = [];

  /// Fills the list the first time, from `assets/mock/saved.json`, so the
  /// Saved tab has something in it.
  /// TODO(api): replace with `GET /me/saved` once the backend keeps them.
  Future<void> seedFromAssets() async {
    if (_prefs.getBool(_seededKey) ?? false) return;
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/mock/saved.json')) as List;
      _items = [
        for (final e in raw) _id(SavedKind.destination, e.toString()),
      ];
    } catch (_) {}
    await _prefs.setBool(_seededKey, true);
    _persist();
  }

  static String _id(SavedKind kind, String key) => '${kind.name}:$key';

  bool isSaved(SavedKind kind, String key) => _items.contains(_id(kind, key));

  /// Returns the new state (true = now saved).
  bool toggle(SavedKind kind, String key) {
    final id = _id(kind, key);
    final nowSaved = !_items.remove(id);
    if (nowSaved) _items.insert(0, id);
    _persist();
    return nowSaved;
  }

  void remove(SavedKind kind, String key) {
    if (_items.remove(_id(kind, key))) _persist();
  }

  List<String> keysOf(SavedKind kind) =>
      _items.where((i) => i.startsWith('${kind.name}:')).map((i) => i.substring(kind.name.length + 1)).toList();

  List<DestinationRef> get destinationRefs => keysOf(SavedKind.destination).map(DestinationRef.fromKey).toList();

  int get count => _items.length;

  void _persist() {
    _prefs.setString(_key, jsonEncode(_items));
    notifyListeners();
  }
}

/// "Collect stamp" — a travel passport of places visited. Needs an account on
/// the website, so the UI only offers it when signed in.
///
/// TODO(api): sync with `/me/stamps`.
class StampsProvider extends ChangeNotifier {
  StampsProvider(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _stamps = (jsonDecode(raw) as Map).map((k, v) => MapEntry(k.toString(), DateTime.parse(v.toString())));
      } catch (_) {}
    }
  }

  static const _key = 'ams-travel:stamps';
  final SharedPreferences _prefs;
  Map<String, DateTime> _stamps = {};

  bool has(String destinationKey) => _stamps.containsKey(destinationKey);
  DateTime? collectedAt(String destinationKey) => _stamps[destinationKey];
  int get count => _stamps.length;

  /// Newest first.
  List<MapEntry<String, DateTime>> get entries => _stamps.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  bool toggle(String destinationKey) {
    final nowStamped = _stamps.remove(destinationKey) == null;
    if (nowStamped) _stamps[destinationKey] = DateTime.now();
    _prefs.setString(_key, jsonEncode(_stamps.map((k, v) => MapEntry(k, v.toIso8601String()))));
    notifyListeners();
    return nowStamped;
  }
}

/// How many place pages the traveller has opened — what the Browser badge
/// counts. Kept on the device.
///
/// TODO(api): send this with the account so it follows the traveller.
class BrowseCounter extends ChangeNotifier {
  BrowseCounter(this._prefs) : _count = _prefs.getInt(_key) ?? 0;

  static const _key = 'ams-travel:browse-count';

  /// Reopening the same page soon after does not count again.
  static const window = Duration(minutes: 30);

  final SharedPreferences _prefs;
  int _count;
  final Map<String, DateTime> _recent = {};

  int get count => _count;

  /// Counts one browse of [pageKey], unless that page was counted within the
  /// last [window].
  void seen(String pageKey) {
    final now = DateTime.now();
    final last = _recent[pageKey];
    if (last != null && now.difference(last) < window) return;
    _recent[pageKey] = now;
    _count++;
    _prefs.setInt(_key, _count);
    notifyListeners();
  }
}

/// When each badge tier was first reached, so the achievement page can say
/// "Earned on …". Kept on the device.
///
/// TODO(api): move to the account once the backend tracks achievements.
class BadgeLog extends ChangeNotifier {
  BadgeLog(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _earned = (jsonDecode(raw) as Map).map((k, v) => MapEntry(k.toString(), DateTime.parse(v.toString())));
      } catch (_) {}
    }
  }

  static const _key = 'ams-travel:badge-log';
  final SharedPreferences _prefs;
  Map<String, DateTime> _earned = {};

  static String _id(String badge, String tier) => '$badge/$tier';

  DateTime? earnedOn(String badge, String tier) => _earned[_id(badge, tier)];

  /// Records today as the day [badge] reached [tier], the first time it does.
  void record(String badge, String tier) {
    final id = _id(badge, tier);
    if (_earned.containsKey(id)) return;
    _earned[id] = DateTime.now();
    _prefs.setString(_key, jsonEncode(_earned.map((k, v) => MapEntry(k, v.toIso8601String()))));
    notifyListeners();
  }
}

/// Saved places grouped into folders ("Kep/Kampot", "Cuisines"…), kept on the
/// device. Starts from `assets/mock/folders.json` so the page has something to
/// show.
///
/// TODO(api): move to `/me/folders` once the backend holds them.
class FoldersProvider extends ChangeNotifier {
  FoldersProvider(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _folders = (jsonDecode(raw) as Map).map(
          (k, v) => MapEntry(k.toString(), (v as List).map((e) => e.toString()).toList()),
        );
        _loaded = true;
      } catch (_) {}
    }
  }

  static const _key = 'ams-travel:folders';
  final SharedPreferences _prefs;
  Map<String, List<String>> _folders = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Map<String, List<String>> get folders => Map.unmodifiable(_folders);
  int get count => _folders.length;
  int get itemCount => _folders.values.expand((e) => e).toSet().length;

  List<String> items(String folder) => List.unmodifiable(_folders[folder] ?? const []);

  /// Fills the folders the first time, from `assets/mock/folders.json`.
  Future<void> seedFromAssets() async {
    if (_loaded) return;
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/mock/folders.json')) as Map;
      _folders = raw.map((k, v) => MapEntry(k.toString(), (v as List).map((e) => e.toString()).toList()));
    } catch (_) {
      _folders = {};
    }
    _loaded = true;
    _persist();
  }

  void create(String name) {
    final clean = name.trim();
    if (clean.isEmpty || _folders.containsKey(clean)) return;
    _folders[clean] = [];
    _persist();
  }

  void remove(String folder) {
    if (_folders.remove(folder) != null) _persist();
  }

  /// Returns true when the place is now in the folder.
  bool toggleItem(String folder, String destinationKey) {
    final list = _folders.putIfAbsent(folder, () => []);
    final added = !list.remove(destinationKey);
    if (added) list.add(destinationKey);
    _persist();
    return added;
  }

  /// Takes a place out of every folder it sits in.
  void removeEverywhere(String destinationKey) {
    var changed = false;
    for (final list in _folders.values) {
      if (list.remove(destinationKey)) changed = true;
    }
    if (changed) _persist();
  }

  void _persist() {
    _prefs.setString(_key, jsonEncode(_folders));
    notifyListeners();
  }
}
