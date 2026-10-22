import 'package:ams_travel/core/l10n/app_strings.dart';
import 'package:ams_travel/core/network/api_client.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:ams_travel/state/auth_provider.dart';
import 'package:ams_travel/state/collections_provider.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:ams_travel/widgets/map_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// Setup shared by the browse-page tests (regions, provinces, interests,
/// corridors): strings loaded, no fonts, images or tiles from the network.
void setUpBrowseTests() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await S.load();
    GoogleFonts.config.allowRuntimeFetching = false;
    AppImage.useDiskCache = false;
    AppMap.useTileCache = false;
  });
  setUp(rootBundle.clear);
}

/// Lets the fixture answers arrive and the frames settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Pumps [screen] as a guest with the providers a browse page reads, the
/// API answering from the fixtures through [adapter].
Future<void> pumpBrowse(WidgetTester tester, Widget screen, {FixtureAdapter? adapter, Size size = const Size(400, 1400)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = AmsApi(ApiClient(adapter: adapter ?? FixtureAdapter()));
  final auth = await fakeAuth(prefs);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),
        Provider<AmsApi>.value(value: api),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => SavedProvider(api, auth)),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await settle(tester);
}

/// The query of the last request to [path].
Map<String, dynamic> lastQuery(FixtureAdapter adapter, String path) =>
    adapter.requests.where((r) => r.path == path).last.queryParameters;

/// Every request to [path].
List<RequestOptions> requestsTo(FixtureAdapter adapter, String path) =>
    adapter.requests.where((r) => r.path == path).toList();
