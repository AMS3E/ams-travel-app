import 'package:ams_travel/core/l10n/app_strings.dart';
import 'package:ams_travel/features/profile/account_info_screen.dart';
import 'package:ams_travel/features/profile/achievement_screen.dart';
import 'package:ams_travel/features/profile/badge_tiers_screen.dart';
import 'package:ams_travel/features/profile/badges_screen.dart';
import 'package:ams_travel/features/profile/my_reviews_screen.dart';
import 'package:ams_travel/features/profile/notifications_screen.dart';
import 'package:ams_travel/features/profile/past_seasons_screen.dart';
import 'package:ams_travel/features/profile/preference_pages.dart';
import 'package:ams_travel/features/profile/profile_screen.dart';
import 'package:ams_travel/features/profile/review_detail_screen.dart';
import 'package:ams_travel/state/locale_provider.dart';
import 'package:ams_travel/widgets/app_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support/account_harness.dart';

const _reviewId = '9a1b2c3d-4e5f-4a6b-8c7d-0e1f2a3b4c5d';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await S.load();
    GoogleFonts.config.allowRuntimeFetching = false;
    AppImage.useDiskCache = false;
  });
  setUp(rootBundle.clear);

  Future<void> big(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('Profile', () {
    testWidgets('a guest gets Log in and Register, and no account calls', (tester) async {
      await big(tester);
      final h = await AccountHarness.start(signedIn: false);
      await tester.pumpWidget(h.wrap(const ProfileScreen()));
      await settle(tester);

      expect(find.text('Keep the places you want to see in one list.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Register'), findsOneWidget);
      expect(h.adapter.requests.where((r) => r.path.endsWith('/me')), isEmpty);
    });

    testWidgets('signed in: the account, its counts, check-ins and points', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const ProfileScreen()));
      await settle(tester);

      expect(find.text('Dara Chan'), findsOneWidget);
      expect(find.text('dara.chan+test@gmail.com'), findsOneWidget);
      expect(find.text('Joined: 13 Oct 2026'), findsOneWidget);
      expect(find.text('Your badge'), findsOneWidget, reason: 'no badge earned on a badge track yet');
      expect(find.textContaining('Explorer'), findsNothing, reason: 'the points ladder is retired');
      expect(find.text('2'), findsWidgets, reason: 'reviews from page.totalElements, and two check-ins');
      expect(find.text('Saves'), findsNothing, reason: 'the Saved tab holds them');
      expect(find.text('36'), findsOneWidget, reason: "this season's points, from GET /seasons/me/progress");
      expect(h.calls, contains('GET /seasons/me/progress'));
      expect(find.text('Check-ins'), findsOneWidget);
      // Name, email and phone of five: no picture, no home province.
      expect(find.text('60% profile completed'), findsOneWidget);
      expect(h.adapter.requests.firstWhere((r) => r.path == '/reviews/me').queryParameters['size'].toString(), '1');
    });
  });

  group('Badges', () {
    testWidgets('the season, the current status and every track from the API', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const BadgesScreen()));
      await settle(tester);

      expect(find.text('Green season 2026 · until October 31, 2026'), findsOneWidget);
      for (final name in ['Browser badge', 'Reviewer badge', 'Adventure badge']) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      expect(find.text('Explorer badge'), findsNothing, reason: 'the points ladder is retired');
      expect(find.text('42 browse'), findsOneWidget);
    });

    testWidgets('a track lists its levels with their thresholds', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const BadgeTiersScreen(badgeKey: 'BROWSES')));
      await settle(tester);

      expect(find.text('Platinum'), findsOneWidget);
      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('Silver'), findsOneWidget);
      expect(find.text('300 browse required'), findsOneWidget, reason: 'Silver is open from the start');
      expect(find.text('Complete Silver first'), findsOneWidget, reason: 'Gold waits for Silver');
      expect(find.text('Complete Gold first'), findsOneWidget, reason: 'Platinum waits for Gold');
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing, reason: 'nothing earned this season');
    });

    testWidgets('an achievement shows when it was earned, and the history', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const AchievementScreen(badgeKey: 'BROWSES')));
      await settle(tester);

      expect(find.text('Badge earned!'), findsOneWidget);
      expect(find.text('Silver Browser badge'), findsOneWidget);
      expect(find.text('Earned on January 18, 2026 · High season 2025/26'), findsOneWidget);
      expect(find.text('Share badge'), findsOneWidget);

      await tester.tap(find.text('View badge history'));
      await settle(tester);
      expect(find.text('36 points · 2 reviews · 2 ratings'), findsOneWidget);
    });

    testWidgets('the badges page leads to past seasons', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const BadgesScreen()));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Past seasons'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Past seasons'), findsOneWidget);
    });

    testWidgets('past seasons list the completed ones with their totals and badges', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const PastSeasonsScreen()));
      await settle(tester);

      expect(find.text('High season 2025/26'), findsOneWidget);
      expect(find.text('Green season 2026'), findsNothing, reason: 'the active season is the live badges page');
      expect(find.text('1 Nov 2025 – 30 Apr 2026'), findsOneWidget, reason: 'dates from GET /seasons');
      expect(find.text('184'), findsOneWidget);
      expect(find.text('12 reviews · 31 ratings'), findsOneWidget);
      expect(find.text('11 places reviewed · 27 places rated'), findsOneWidget);
      expect(find.text('1 badge'), findsOneWidget, reason: 'the earned list counted for that season');
    });

    testWidgets("a past season shows its ladders as left, read-only", (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      const past = '5e1a2b3c-4d5e-4f60-8a7b-9c0d1e2f3a4b';
      await tester.pumpWidget(h.wrap(const SeasonBadgesScreen(seasonId: past)));
      await settle(tester);

      final asked = h.adapter.requests.firstWhere((r) => r.path == '/badges/me/progress');
      expect(asked.queryParameters['seasonId'], past);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Finished in the top 12% of active members'), findsOneWidget);
      expect(find.text('Silver Browser badge'), findsWidgets, reason: 'the level reached');
      expect(find.text('512 browse'), findsOneWidget);
      expect(find.text('Gold · 800 browse'), findsOneWidget, reason: 'the threshold');
      expect(find.text('512 / 800 · not finished'), findsOneWidget, reason: 'a row with no earnedAt');
      expect(find.text('12 / 50 · not finished'), findsOneWidget);
      expect(find.text('Explorer badge'), findsNothing, reason: 'the points ladder is retired');
      await tester.scrollUntilVisible(
        find.text('Earned on January 18, 2026'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Earned on January 18, 2026'), findsOneWidget);
    });

    testWidgets('a past earn opens on its own page, with its season and share', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(
        h.wrap(const AchievementScreen(badgeKey: 'BROWSER_SILVER', earnedId: 'd00dfeed-0000-4000-8000-000000000001')),
      );
      await settle(tester);

      expect(find.text('Badge earned!'), findsOneWidget);
      expect(find.text('Earned on January 18, 2026 · High season 2025/26'), findsOneWidget);
      expect(find.text('Share badge'), findsOneWidget);
      expect(find.textContaining('until October 31, 2026'), findsNothing, reason: 'not the current season');
    });

    testWidgets('the badge history groups badges by season', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const AchievementScreen(badgeKey: 'REVIEWS')));
      await settle(tester);
      await tester.tap(find.text('View badge history'));
      await settle(tester);

      final current = tester.getTopLeft(find.text('Green season 2026').first).dy;
      final past = tester.getTopLeft(find.text('High season 2025/26').first).dy;
      expect(current, lessThan(past), reason: 'newest season first');
      expect(find.text('Silver Adventure badge'), findsOneWidget, reason: 'earned this season');
      expect(find.text('Silver Browser badge'), findsOneWidget, reason: 'earned last season');
    });

    testWidgets('a guest is asked to sign in', (tester) async {
      final h = await AccountHarness.start(signedIn: false);
      await tester.pumpWidget(h.wrap(const BadgesScreen()));
      await settle(tester);
      expect(find.text('Log in to collect badges as you browse, review and check in.'), findsOneWidget);
    });
  });

  group('My reviews', () {
    testWidgets('the page from the API, its places in one call per kind, the average from the rows', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const MyReviewsScreen()));
      await settle(tester);

      expect(find.text('Angkor Wat'), findsOneWidget);
      expect(find.text('Khmer Civilization'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('Awaiting approval'), findsOneWidget);
      final mine = h.adapter.requests.firstWhere((r) => r.path == '/reviews/me');
      expect(mine.queryParameters['sort'], 'createdAt,desc');
      final cards = h.adapter.requests.where((r) => r.path == '/search/cards').toList();
      expect(cards, hasLength(2), reason: 'one DESTINATION call, one CORRIDOR call');
    });

    testWidgets('sorting asks the server again', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const MyReviewsScreen()));
      await settle(tester);

      await tester.tap(find.text('Sort by: Most recent'));
      await settle(tester, rounds: 3);
      await tester.tap(find.text('Highest rated').last);
      await settle(tester);
      expect(h.adapter.requests.where((r) => r.path == '/reviews/me').last.queryParameters['sort'], 'rating,desc');
    });

    testWidgets('a review in detail can be deleted', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const ReviewDetailScreen(id: _reviewId)));
      await settle(tester);

      expect(find.text('Sunrise worth the alarm'), findsOneWidget);
      expect(find.text('Couples'), findsOneWidget);
      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('Angkor Wat'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete review'));
      await settle(tester, rounds: 3);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(h.sent('DELETE', '/reviews/$_reviewId'), hasLength(1));
    });

    testWidgets('editing sends PUT /reviews/{id} and keeps what was not touched', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const ReviewDetailScreen(id: _reviewId)));
      await settle(tester);

      await tester.tap(find.byTooltip('Edit your review'));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.star_outline_rounded).first);
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      final body = h.sent('PUT', '/reviews/$_reviewId').single as Map;
      expect(body['rating'], 5);
      expect(body['visitType'], 'COUPLES');
      expect(body['visitedOn'], '2026-08');
      expect(body['title'], 'Sunrise worth the alarm');
      expect(find.text('Edited title'), findsOneWidget, reason: 'the page shows what the API answered');
    });
  });

  group('Notifications', () {
    testWidgets('All and Unread, and mark all read', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const NotificationsScreen()));
      await settle(tester);

      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Unread (1)'), findsOneWidget);
      expect(find.text('You earned Silver Explorer'), findsOneWidget);

      await tester.tap(find.byTooltip('Mark all as read'));
      await settle(tester);
      expect(find.text('Unread (0)'), findsOneWidget);
      expect(h.sent('PUT', '/notifications/read-all'), hasLength(1));
    });

    testWidgets('a guest is asked to sign in', (tester) async {
      final h = await AccountHarness.start(signedIn: false);
      await tester.pumpWidget(h.wrap(const NotificationsScreen()));
      await settle(tester);
      expect(find.text('Log in to see your notifications.'), findsOneWidget);
    });
  });

  group('Preferences and account', () {
    testWidgets('signed in, the language is saved to the account', (tester) async {
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const LanguagePage()));
      await settle(tester);

      await tester.tap(find.text('Khmer (ភាសាខ្មែរ)'));
      await settle(tester);
      final body = h.sent('PUT', '/preferences/me').single as Map;
      expect(body['preferredLanguage'], 'km');
      expect(body['preferredCurrency'], 'USD', reason: 'the rest of the account choice is kept');
    });

    testWidgets('a guest keeps the language on the phone', (tester) async {
      final h = await AccountHarness.start(signedIn: false);
      await tester.pumpWidget(h.wrap(const LanguagePage()));
      await settle(tester);

      await tester.tap(find.text('Khmer (ភាសាខ្មែរ)'));
      await settle(tester);
      expect(h.sent('PUT', '/preferences/me'), isEmpty);
      final context = tester.element(find.byType(LanguagePage));
      expect(context.read<LocaleProvider>().isKhmer, isTrue);
    });

    testWidgets('the currency page says prices come in their own currency', (tester) async {
      final h = await AccountHarness.start(signedIn: false);
      await tester.pumpWidget(h.wrap(const CurrencyPage()));
      await settle(tester);
      expect(find.text('Prices are shown in the currency each place sets.'), findsOneWidget);
      expect(find.textContaining('4100'), findsNothing, reason: 'no fixed exchange rate');
    });

    testWidgets('account info saves the name and phone with PUT /users/me', (tester) async {
      await big(tester);
      final h = await AccountHarness.start();
      await tester.pumpWidget(h.wrap(const AccountInfoScreen()));
      await settle(tester);

      expect(find.text('dara.chan+test@gmail.com'), findsOneWidget);
      expect(find.text('Change email or password'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Dara Chan'), 'Dara Chan Sok');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      final body = h.sent('PUT', '/users/me').single as Map;
      expect(body['fullName'], 'Dara Chan Sok');
      expect(body['phone'], '+855 12 345 678');
      expect(h.auth.user?.fullName, 'Dara Chan Sok');
    });
  });
}
