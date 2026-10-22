import 'package:ams_travel/core/l10n/app_strings.dart';
import 'package:ams_travel/core/network/api_client.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:ams_travel/features/home/popular_screen.dart';
import 'package:ams_travel/features/home/popular_search_screen.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

/// The fixtures, with `/popular` answering an empty list: nothing matches
/// the chips (the server fills the list otherwise).
class _NothingPopular extends FixtureAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    if (options.path == '/popular') {
      requests.add(options);
      return Future.value(
        ResponseBody.fromString(
          '{"days":30,"regionId":null,"type":"DESTINATION","items":[],"destinations":[]}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _pump(WidgetTester tester, FixtureAdapter adapter, Widget screen) async {
  await tester.binding.setSurfaceSize(const Size(400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),
        Provider<AmsApi>.value(value: AmsApi(ApiClient(adapter: adapter))),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await S.load();
    GoogleFonts.config.allowRuntimeFetching = false;
    AppImage.useDiskCache = false;
  });
  setUp(rootBundle.clear);

  testWidgets('Popular lists the ranked ids as cards; chips go to the server', (tester) async {
    final adapter = FixtureAdapter();
    await _pump(tester, adapter, const PopularScreen());

    expect(find.text('Angkor Wat'), findsOneWidget);
    expect(find.text('Battambang'), findsOneWidget, reason: 'a province chip from /provinces');
    expect(find.text('Attraction Sites'), findsOneWidget, reason: 'an interest group chip');

    await tester.tap(find.text('Battambang'));
    await _settle(tester);
    var popular = adapter.requests.where((r) => r.path == '/popular').last.queryParameters;
    expect(popular['provinceIds'], '8f0f4fed-2ccc-458d-9391-972f5870deca');
    expect(popular['type'], 'DESTINATION');
    expect(popular['limit'], 50);

    await tester.tap(find.text('Attraction Sites'));
    await _settle(tester);
    popular = adapter.requests.where((r) => r.path == '/popular').last.queryParameters;
    expect(popular['interestIds'], isNotEmpty, reason: 'the ids of the chosen group');

    // A kind group asks for that kind.
    await tester.tap(find.text('Stays'));
    await _settle(tester);
    popular = adapter.requests.where((r) => r.path == '/popular').last.queryParameters;
    expect(popular['type'], 'STAY');
  });

  testWidgets('Popular with nothing matching shows its empty state', (tester) async {
    await _pump(tester, _NothingPopular(), const PopularScreen());

    expect(find.text('Nothing matches'), findsOneWidget);
    expect(find.text('Angkor Wat'), findsNothing);
  });

  testWidgets('Popular search shows the first results and the suggestions while typing', (tester) async {
    final adapter = FixtureAdapter();
    await _pump(tester, adapter, const PopularSearchScreen());
    expect(find.text('Type a place, province or region'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ang');
    await _settle(tester);

    expect(adapter.requests.where((r) => r.path == '/search').last.queryParameters['q'], 'ang');
    expect(adapter.requests.where((r) => r.path == '/search/suggest').last.queryParameters['q'], 'ang');
    expect(find.text('Bayon Temple'), findsOneWidget, reason: 'a result card');
    expect(find.text('Kampong Chhnang'), findsOneWidget, reason: 'a suggestion');
  });
}
