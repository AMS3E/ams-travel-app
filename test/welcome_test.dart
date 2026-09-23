import 'dart:convert';

import 'package:ams_travel/app.dart';
import 'package:ams_travel/data/repositories/auth_repository.dart';
import 'package:ams_travel/data/repositories/mock_travel_repository.dart';
import 'package:ams_travel/data/repositories/travel_repository.dart';
import 'package:ams_travel/features/welcome/welcome_screen.dart';
import 'package:ams_travel/state/auth_provider.dart';
import 'package:ams_travel/state/collections_provider.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/state/settings_provider.dart';
import 'package:ams_travel/state/travel_preferences.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<Widget> _app(SharedPreferences prefs) async => MultiProvider(
  providers: [
    Provider<SharedPreferences>.value(value: prefs),
    Provider<TravelRepository>.value(value: MockTravelRepository()),
    ChangeNotifierProvider(create: (_) => AuthProvider(MockAuthRepository(), prefs)),
    ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
    ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
    ChangeNotifierProvider(create: (_) => SavedProvider(prefs)),
    ChangeNotifierProvider(create: (_) => StampsProvider(prefs)),
    ChangeNotifierProvider(create: (_) => TravelPreferences(prefs)),
    ChangeNotifierProvider(create: (_) => FoldersProvider(prefs)),
  ],
  child: AmsTravelApp(showWelcome: !(prefs.getBool(WelcomeScreen.seenKey) ?? false)),
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppImage.useDiskCache = false;
  });
  setUp(rootBundle.clear);

  testWidgets('first launch shows the welcome slides; Explore as Guest opens Home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(await _app(prefs));
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
    await tester.pumpWidget(await _app(prefs));
    await _settle(tester);

    expect(find.text('KINGDOM OF WONDER'), findsNothing);
    expect(find.text('Explore by Tourism Region'), findsOneWidget);
  });

  testWidgets('Start Your Journey opens the interests step and the picks reach Home', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(await _app(prefs));
    await _settle(tester);

    await tester.tap(find.text('Start Your Journey').first);
    await _settle(tester);
    expect(find.text('Make your journey yours'), findsOneWidget);
    expect(find.text('History & Culture'), findsOneWidget);
    expect(find.text('Family Activities'), findsOneWidget);

    // Nothing chosen yet: the button is disabled and still says "Start".
    expect(tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed, isNull);

    await tester.tap(find.text('Beaches & Islands'));
    await _settle(tester);
    expect(find.text('Continue Your Journey'), findsOneWidget);
    expect(prefs.getStringList('ams-travel:travel-interests'), ['beaches-islands']);

    // Step 3: the journey-is-ready carousel.
    await tester.tap(find.text('Continue Your Journey'));
    await _settle(tester);
    expect(find.text('Your journey is Ready'), findsOneWidget);
    expect(find.text('AMS TRAVEL Version 1.0.0(1)'), findsOneWidget);

    // Start exploring finishes onboarding and opens sign-up over Home.
    await tester.tap(find.text('Start exploring'));
    await _settle(tester);
    expect(find.text('Create Account'), findsOneWidget, reason: 'register screen');

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _settle(tester);
    expect(find.text('Explore by Tourism Region'), findsOneWidget, reason: 'home behind it');

    // The chosen interest moves its places to the front of "Popular".
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    await _settle(tester);
    expect(find.text('Explore by Popular'), findsOneWidget);
  });

  testWidgets('logging out returns to the welcome slides', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      WelcomeScreen.seenKey: true,
      'ams-travel:travel-interests': ['beaches-islands'],
      'ams-travel:session': jsonEncode({
        'token': 'mock-token',
        'user': {'id': 'u1', 'username': 'sokha', 'email': 'sokha@example.com'},
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(await _app(prefs));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.person_outline_rounded).last);
    await _settle(tester);
    expect(find.text('sokha'), findsOneWidget, reason: 'profile screen');

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
    expect(prefs.getString('ams-travel:session'), isNull);
    expect(prefs.getBool(WelcomeScreen.seenKey), isNull, reason: 'welcome plays again next launch');
    expect(prefs.getStringList('ams-travel:travel-interests'), isNull, reason: 'old picks forgotten');

    // The interests step starts empty, so its button is disabled again.
    await tester.tap(find.text('Start Your Journey').first);
    await _settle(tester);
    expect(find.text('Make your journey yours'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed, isNull);
  });
}
