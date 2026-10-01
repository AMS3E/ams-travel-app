import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One thing the app has to tell the traveller.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.minutesAgo,
  });

  final String id;

  /// place, profile, info, review or badge — it picks the symbol.
  final String kind;
  final String title;
  final String body;

  /// How long ago it arrived, in minutes.
  final int minutesAgo;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'].toString(),
    kind: j['kind']?.toString() ?? 'info',
    title: j['title']?.toString() ?? '',
    body: j['body']?.toString() ?? '',
    minutesAgo: (j['minutesAgo'] as num?)?.toInt() ?? 0,
  );
}

/// The notifications and which of them have been read.
///
/// TODO(api): swap the seed for `GET /me/notifications` and send reads back.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._prefs) {
    _read = (_prefs.getStringList(_key) ?? const []).toSet();
  }

  static const _key = 'ams-travel:notifications-read';
  final SharedPreferences _prefs;

  List<AppNotification> _items = [];
  Set<String> _read = {};
  bool _loaded = false;

  List<AppNotification> get all => List.unmodifiable(_items);
  List<AppNotification> get unread => _items.where((n) => !_read.contains(n.id)).toList();
  bool isRead(String id) => _read.contains(id);
  int get unreadCount => unread.length;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/mock/notifications.json')) as List;
      _items = [for (final e in raw) AppNotification.fromJson(Map<String, dynamic>.from(e as Map))];
    } catch (_) {
      _items = [];
    }
    notifyListeners();
  }

  void markRead(String id) {
    if (!_read.add(id)) return;
    _prefs.setStringList(_key, _read.toList());
    notifyListeners();
  }

  void markAllRead() {
    _read = {for (final n in _items) n.id};
    _prefs.setStringList(_key, _read.toList());
    notifyListeners();
  }
}
