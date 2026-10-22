import 'package:ams_travel/core/network/api_client.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:ams_travel/data/auth/keycloak.dart';
import 'package:ams_travel/state/auth_provider.dart';
import 'package:ams_travel/state/collections_provider.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/state/notifications_provider.dart';
import 'package:ams_travel/state/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// One screen of the account area over the fixtures, signed in or not, with
/// the adapter at hand to check what was sent.
class AccountHarness {
  AccountHarness._(this.prefs, this.adapter, this.api, this.auth);

  final SharedPreferences prefs;
  final FixtureAdapter adapter;
  final AmsApi api;
  final AuthProvider auth;

  static Future<AccountHarness> start({bool signedIn = true, Map<String, Object> stored = const {}}) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    final adapter = FixtureAdapter();
    final client = ApiClient(adapter: adapter);
    final api = AmsApi(client);
    final auth = AuthProvider(
      keycloak: FakeKeycloak(),
      store: MemoryTokenStore(signedIn ? FakeKeycloak.tokens : null),
      api: api,
      prefs: prefs,
    );
    client.tokens = auth;
    await auth.restore();
    return AccountHarness._(prefs, adapter, api, auth);
  }

  /// Every request as "METHOD /path", oldest first.
  List<String> get calls => [for (final r in adapter.requests) '${r.method.toUpperCase()} ${r.path}'];

  /// Requests sent with [method] to [path].
  Iterable<dynamic> sent(String method, String path) =>
      adapter.requests.where((r) => r.method.toUpperCase() == method && r.path == path).map((r) => r.data);

  Widget wrap(Widget screen) => MultiProvider(
    providers: [
      Provider<SharedPreferences>.value(value: prefs),
      Provider<AmsApi>.value(value: api),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
      ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
      ChangeNotifierProvider(create: (_) => SavedProvider(api, auth)),
      ChangeNotifierProvider(create: (_) => NotificationsProvider(api, auth)),
      ChangeNotifierProvider(create: (_) => FoldersProvider(prefs)),
    ],
    child: MaterialApp(home: screen),
  );
}

/// Lets the fixture answers (real file reads) and the frames both finish.
Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}
