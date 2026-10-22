import 'package:ams_travel/app.dart';
import 'package:ams_travel/core/l10n/app_strings.dart';
import 'package:ams_travel/data/api/ams_api.dart';
import 'package:ams_travel/features/welcome/welcome_screen.dart';
import 'package:ams_travel/state/auth_provider.dart';
import 'package:ams_travel/state/collections_provider.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/state/notifications_provider.dart';
import 'package:ams_travel/state/settings_provider.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// The app as `main` builds it, over the fixtures, Keycloak never opened.
Future<(Widget, AuthProvider)> _app(SharedPreferences prefs, {bool signedIn = false}) async {
  final api = fakeAmsApi();
  final auth = await fakeAuth(prefs, signedIn: signedIn);
  final app = MultiProvider(
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
    child: AmsTravelApp(showWelcome: !(prefs.getBool(WelcomeScreen.seenKey) ?? false)),
  );
  return (app, auth);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await S.load();
    GoogleFonts.config.allowRuntimeFetching = false;
    AppImage.useDiskCache = false;
  });
  setUp(rootBundle.clear);

  testWidgets('first launch shows the welcome slides; Explore as Guest opens Home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget((await _app(prefs)).$1);
    await _settle(tester);

    expect(find.text('KINGDOM OF WONDER'), findsOneWidget);
    expect(find.text('Discover the'), findsOneWidget);
    expect(find.text('Start Your Journey'), findsOneWidget);

    // The second slide is reachable by swiping.
    await tester.drag(find.text('KINGDOM OF WONDER'), const Offset(-260, 0));
    await _settle(tester);
    expect(find.text('NINE TOURISM REGIONS'), findsOneWidget);

    await tester.tap(find.text('Explore as Guest'));
    await _settle(tester);
    expect(find.text('Explore by Tourism Region'), findsOneWidget, reason: 'home screen');
    expect(prefs.getBool(WelcomeScreen.seenKey), isTrue);
  });

  testWidgets('later launches go straight to Home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({WelcomeScreen.seenKey: true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget((await _app(prefs)).$1);
    await _settle(tester);

    expect(find.text('KINGDOM OF WONDER'), findsNothing);
    expect(find.text('Explore by Tourism Region'), findsOneWidget);
  });

  testWidgets('Start Your Journey opens Keycloak registration and lands on Home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (app, auth) = await _app(prefs);
    await tester.pumpWidget(app);
    await _settle(tester);

    await tester.tap(find.text('Start Your Journey').first);
    await _settle(tester);
    // Keycloak's page is the fake here: it comes back signed in at once.
    expect(auth.isSignedIn, isTrue, reason: 'registered through Keycloak');
    expect(find.text('Explore by Tourism Region'), findsOneWidget, reason: 'home screen');
    expect(prefs.getBool(WelcomeScreen.seenKey), isTrue, reason: 'the slides are done');
  });

  testWidgets('logging out returns to the welcome slides', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({WelcomeScreen.seenKey: true});
    final prefs = await SharedPreferences.getInstance();
    final (app, auth) = await _app(prefs, signedIn: true);
    await tester.pumpWidget(app);
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.person_outline_rounded).last);
    await _settle(tester);
    expect(find.text('Dara Chan'), findsOneWidget, reason: 'profile screen, from GET /users/me');

    // Sign out sits at the bottom of the profile page.
    await tester.dragUntilVisible(
      find.text('Log out'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await _settle(tester);
    await tester.tap(find.text('Log out').last);
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await _settle(tester);

    expect(find.text('KINGDOM OF WONDER'), findsOneWidget, reason: 'back on welcome');
    expect(auth.isSignedIn, isFalse);
    expect(prefs.getString('ams-travel:profile'), isNull, reason: 'the account is forgotten on the phone');
    expect(prefs.getBool(WelcomeScreen.seenKey), isNull, reason: 'welcome plays again next launch');
    expect(find.text('Start Your Journey'), findsWidgets, reason: 'the slides play again');
  });
}
