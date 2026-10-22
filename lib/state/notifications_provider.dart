import 'package:material_ui/material_ui.dart';

import '../data/api/ams_api.dart';
import 'auth_provider.dart';

/// The signed-in traveller's notifications (`GET /notifications`). A guest
/// has none.
///
/// The design's own kinds ("New places added in Siem Reap",
/// "Complete your profile") have nothing producing them on the API yet:
/// parked in screens-to-api.md.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._api, this._auth) {
    _auth.addListener(_onAuth);
    _onAuth();
  }

  final AmsApi _api;
  final AuthProvider _auth;
  bool _signedIn = false;

  List<InboxNotification> _items = [];
  bool _loaded = false;
  Object? _error;

  List<InboxNotification> get all => List.unmodifiable(_items);
  List<InboxNotification> get unread => _items.where((n) => !n.isRead).toList();
  int get unreadCount => _items.where((n) => !n.isRead).length;
  bool get isLoaded => _loaded;

  /// Why the last load failed, if it did.
  Object? get error => _error;

  void _onAuth() {
    final signedIn = _auth.isSignedIn;
    if (signedIn == _signedIn) return;
    _signedIn = signedIn;
    if (signedIn) {
      load();
    } else {
      _items = [];
      _loaded = false;
      notifyListeners();
    }
  }

  /// Reads the list again.
  Future<void> load() async {
    if (!_auth.isSignedIn) return;
    try {
      _items = await _api.notifications(limit: 50);
      _error = null;
    } catch (e) {
      _error = e;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0 || _items[i].isRead) return;
    final before = _items;
    _items = [..._items]..[i] = _items[i].read();
    notifyListeners();
    try {
      await _api.markNotificationRead(id);
    } catch (_) {
      _items = before;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    final before = _items;
    _items = [for (final n in _items) n.read()];
    notifyListeners();
    try {
      await _api.markAllNotificationsRead();
    } catch (_) {
      _items = before;
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    final before = _items;
    _items = [
      for (final n in _items)
        if (n.id != id) n,
    ];
    notifyListeners();
    try {
      await _api.deleteNotification(id);
    } catch (_) {
      _items = before;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    super.dispose();
  }
}
