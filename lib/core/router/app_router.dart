import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/corridor/corridor_screen.dart';
import '../../features/destination/destination_screen.dart';
import '../../features/destination/review_screen.dart';
import '../../features/destination/room_screen.dart';
import '../../features/destination/rooms_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/interest/interest_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/profile/account_info_screen.dart';
import '../../features/profile/achievement_screen.dart';
import '../../features/profile/badges_screen.dart';
import '../../features/profile/my_reviews_screen.dart';
import '../../features/home/popular_screen.dart';
import '../../features/interest/interest_explore_screen.dart';
import '../../features/home/popular_search_screen.dart';
import '../../features/profile/help_support_screen.dart';
import '../../features/profile/preference_pages.dart';
import '../../features/profile/preferences_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/terms_screen.dart';
import '../../features/province/province_screen.dart';
import '../../features/province/provinces_explore_screen.dart';
import '../../features/region/region_screen.dart';
import '../../features/region/regions_explore_screen.dart';
import '../../features/saved/folders_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/search/filter_sheet.dart';
import '../../features/search/search_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/welcome/interests_step.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../features/story/story_screen.dart';
import '../../state/travel_preferences.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createRouter({bool showWelcome = false}) {
  GoRoute page(String path, Widget Function(GoRouterState s) build) =>
      GoRoute(path: path, parentNavigatorKey: _rootKey, builder: (_, s) => build(s));

  return GoRouter(
    navigatorKey: _rootKey,
    // Dev helper: `flutter run --dart-define=INITIAL_ROUTE=/regions/luxury`
    // opens straight on a screen. Otherwise first launch starts on the
    // welcome slides.
    initialLocation: const bool.hasEnvironment('INITIAL_ROUTE')
        ? const String.fromEnvironment('INITIAL_ROUTE')
        : (showWelcome ? Routes.welcome : Routes.home),
    routes: [
      // Five bottom-nav tabs, each keeping its own scroll/stack state.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, _) => HomeScreen(pickedCategories: context.watch<TravelPreferences>().categories),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.explore,
                builder: (_, s) => ExploreScreen(tab: s.uri.queryParameters['tab']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.map,
                builder: (_, s) => MapScreen(
                  focusKey: s.uri.queryParameters['place'],
                  corridorSlug: s.uri.queryParameters['corridor'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.saved, builder: (_, _) => const SavedScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),

      // Full-screen pages pushed above the tabs. Most specific paths first.
      page(
        '/regions/:region/stories/:story',
        (s) => StoryScreen(region: s.pathParameters['region']!, slug: s.pathParameters['story']!),
      ),
      page(
        '/regions/:region/:dest/review',
        (s) => ReviewScreen(region: s.pathParameters['region']!, slug: s.pathParameters['dest']!),
      ),
      page(
        '/regions/:region/:dest/rooms/:room',
        (s) => RoomScreen(
          region: s.pathParameters['region']!,
          slug: s.pathParameters['dest']!,
          roomId: s.pathParameters['room']!,
        ),
      ),
      page(
        '/regions/:region/:dest/rooms',
        (s) => RoomsScreen(region: s.pathParameters['region']!, slug: s.pathParameters['dest']!),
      ),
      page(Routes.exploreRegions, (_) => const RegionsExploreScreen()),
      page(
        '/regions/:region/:dest',
        (s) => DestinationScreen(region: s.pathParameters['region']!, slug: s.pathParameters['dest']!),
      ),
      page('/regions/:region', (s) => RegionScreen(slug: s.pathParameters['region']!)),
      page(Routes.exploreProvinces, (_) => const ProvincesExploreScreen()),
      page('/provinces/:province', (s) => ProvinceScreen(slug: s.pathParameters['province']!)),
      page(Routes.exploreInterests, (_) => const InterestExploreScreen()),
      page('/interests/:interest', (s) => InterestScreen(slug: s.pathParameters['interest']!)),
      page('/corridors/:corridor', (s) => CorridorScreen(slug: s.pathParameters['corridor']!)),
      page(
        Routes.search,
        (s) => SearchScreen(
          initialQuery: s.uri.queryParameters['q'],
          // Home hands over the filters already picked in its sheet.
          initialFilters: s.extra is SearchFilters ? s.extra as SearchFilters : null,
        ),
      ),
      page(Routes.welcome, (_) => const WelcomeScreen()),
      page(Routes.interests, (_) => const Scaffold(body: InterestsStep())),
      page(Routes.badges, (_) => const BadgesScreen()),
      page(Routes.account, (_) => const AccountInfoScreen()),
      page(Routes.popular, (_) => const PopularScreen()),
      page(Routes.popularSearch, (_) => const PopularSearchScreen()),
      page(Routes.help, (_) => const HelpSupportScreen()),
      page(Routes.terms, (_) => const TermsScreen()),
      page(Routes.preferences, (_) => const PreferencesScreen()),
      page(Routes.language, (_) => const LanguagePage()),
      page(Routes.currency, (_) => const CurrencyPage()),
      page(Routes.units, (_) => const UnitsPage()),
      page(Routes.notifications, (_) => const NotificationsPage()),
      page(Routes.myReviews, (_) => const MyReviewsScreen()),
      page(Routes.folders, (_) => const FoldersScreen()),
      page('/folders/:folder', (s) => FolderScreen(name: Uri.decodeComponent(s.pathParameters['folder']!))),
      page('/badges/:badge', (s) => AchievementScreen(badgeKey: s.pathParameters['badge']!)),
      page(Routes.login, (_) => const LoginScreen()),
      page(Routes.register, (_) => const RegisterScreen()),
      page(Routes.forgotPassword, (_) => const ForgotPasswordScreen()),
    ],
  );
}
