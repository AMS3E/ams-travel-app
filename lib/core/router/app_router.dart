import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/api/ams_api.dart';
import '../../features/corridor/corridor_screen.dart';
import '../../features/corridor/corridors_explore_screen.dart';
import '../../features/destination/activity_screen.dart';
import '../../features/destination/check_in_screen.dart';
import '../../features/destination/destination_screen.dart';
import '../../features/destination/food_screen.dart';
import '../../features/destination/stay_screen.dart';
import '../../features/destination/review_screen.dart';
import '../../features/destination/reviews_screen.dart';
import '../../features/destination/room_screen.dart';
import '../../features/destination/rooms_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/interest/interest_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/profile/account_info_screen.dart';
import '../../features/profile/achievement_screen.dart';
import '../../features/profile/badge_tiers_screen.dart';
import '../../features/profile/badges_screen.dart';
import '../../features/profile/past_seasons_screen.dart';
import '../../features/profile/my_reviews_screen.dart';
import '../../features/profile/review_detail_screen.dart';
import '../../features/home/popular_screen.dart';
import '../../features/interest/interest_explore_screen.dart';
import '../../features/home/popular_search_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/help_support_screen.dart';
import '../../features/profile/notifications_screen.dart';
import '../../features/profile/preference_pages.dart';
import '../../features/profile/preferences_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/terms_screen.dart';
import '../../features/province/province_screen.dart';
import '../../features/province/province_places_screen.dart';
import '../../features/province/provinces_explore_screen.dart';
import '../../features/region/region_places_screen.dart';
import '../../features/region/regions_explore_screen.dart';
import '../../features/saved/folders_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/search/filter_sheet.dart';
import '../../features/search/search_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../state/locale_provider.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Builds the page afresh when the app's language changes, so it reads its
/// content again: cards come in that language from the server, and the
/// Khmer of a detail is read in place of the English.
class _InLanguage extends StatelessWidget {
  const _InLanguage(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(context.select<LocaleProvider, bool>((l) => l.isKhmer)), child: child);
}

GoRouter createRouter({bool showWelcome = false}) {
  /// A page above the tabs, with the bottom bar over it unless [bar] is
  /// false (the scanner, the review form).
  GoRoute page(String path, Widget Function(GoRouterState s) build, {bool bar = true}) => GoRoute(
    path: path,
    parentNavigatorKey: _rootKey,
    builder: (_, s) => bar ? WithNavBar(child: _InLanguage(build(s))) : _InLanguage(build(s)),
  );

  /// Slides in from [from] and back out the same way, so a push and the matching
  /// back arrow mirror each other on every platform.
  GoRoute slidePage(String path, Offset from, Widget Function(GoRouterState s) build) => GoRoute(
    path: path,
    parentNavigatorKey: _rootKey,
    pageBuilder: (_, s) => CustomTransitionPage(
      child: _InLanguage(build(s)),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(
          begin: from,
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    ),
  );

  return GoRouter(
    navigatorKey: _rootKey,
    // Dev helper: `flutter run --dart-define=INITIAL_ROUTE=/regions/luxury`
    // opens straight on a screen. Otherwise first launch starts on the
    // welcome slides.
    initialLocation: const bool.hasEnvironment('INITIAL_ROUTE')
        ? const String.fromEnvironment('INITIAL_ROUTE')
        : (showWelcome ? Routes.welcome : Routes.home),
    routes: [
      // Four bottom-nav tabs, each keeping its own scroll/stack state.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (context, _) => const _InLanguage(HomeScreen()))],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.map,
                builder: (_, s) => _InLanguage(
                  MapScreen(focusId: s.uri.queryParameters['place'], corridorId: s.uri.queryParameters['corridor']),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.saved, builder: (_, _) => const _InLanguage(SavedScreen()))],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, _) => const _InLanguage(ProfileScreen()))],
          ),
        ],
      ),

      // Full-screen pages pushed above the tabs. Most specific paths first.
      page(
        '/reviews/:type/:id/new',
        (s) => ReviewScreen(type: CardType.values.byName(s.pathParameters['type']!), id: s.pathParameters['id']!),
        bar: false,
      ),
      page(
        '/reviews/:type/:id',
        (s) => ReviewsScreen(type: CardType.values.byName(s.pathParameters['type']!), id: s.pathParameters['id']!),
      ),
      page(
        '/stays/:stay/rooms/:room',
        (s) => RoomScreen(stayId: s.pathParameters['stay']!, roomId: s.pathParameters['room']!),
      ),
      page('/stays/:stay/rooms', (s) => RoomsScreen(stayId: s.pathParameters['stay']!)),
      page('/stays/:stay', (s) => StayScreen(id: s.pathParameters['stay']!)),
      page('/foods/:food', (s) => FoodScreen(id: s.pathParameters['food']!)),
      page('/activities/:activity', (s) => ActivityScreen(id: s.pathParameters['activity']!)),
      page(Routes.checkIn, (_) => const CheckInScreen(), bar: false),
      page('/places/:place', (s) => DestinationScreen(id: s.pathParameters['place']!)),
      page(Routes.exploreRegions, (_) => const RegionsExploreScreen()),
      page('/regions/:region', (s) => RegionPlacesScreen(id: s.pathParameters['region']!)),
      page(Routes.exploreProvinces, (_) => const ProvincesExploreScreen()),
      page('/provinces/:province/places', (s) => ProvincePlacesScreen(id: s.pathParameters['province']!)),
      page('/provinces/:province', (s) => ProvinceScreen(id: s.pathParameters['province']!)),
      page(Routes.exploreInterests, (_) => const InterestExploreScreen()),
      page('/interests/:interest', (s) => InterestScreen(group: s.pathParameters['interest']!)),
      page(Routes.exploreCorridors, (_) => const CorridorsExploreScreen()),
      page('/corridors/:corridor', (s) => CorridorScreen(id: s.pathParameters['corridor']!)),
      page(
        Routes.search,
        (s) => SearchScreen(
          initialQuery: s.uri.queryParameters['q'],
          // Home hands over the filters already picked in its sheet.
          initialFilters: s.extra is SearchFilters ? s.extra as SearchFilters : null,
        ),
      ),
      // Reached after signing out, so it animates like a pop: in from the left.
      slidePage(Routes.welcome, const Offset(-1, 0), (_) => const WelcomeScreen()),
      page(Routes.badges, (_) => const BadgesScreen()),
      page(Routes.account, (s) => AccountInfoScreen(field: s.uri.queryParameters['field'])),
      page(Routes.notificationsPage, (_) => const NotificationsScreen()),
      page(Routes.editProfile, (s) => EditProfileScreen(pickPhoto: s.uri.queryParameters['pick'] == 'photo')),
      page(Routes.popular, (_) => const PopularScreen()),
      page(Routes.popularSearch, (_) => const PopularSearchScreen()),
      page(Routes.help, (_) => const HelpSupportScreen()),
      page(Routes.terms, (_) => const TermsScreen()),
      page(Routes.preferences, (_) => const PreferencesScreen()),
      page(Routes.language, (_) => const LanguagePage()),
      page(Routes.currency, (_) => const CurrencyPage()),
      page(Routes.units, (_) => const UnitsPage()),
      page(Routes.notifications, (_) => const NotificationsPage()),
      page(
        '/my-reviews/:id',
        (s) => ReviewDetailScreen(
          id: s.pathParameters['id']!,
          review: s.extra is TravelReview ? s.extra as TravelReview : null,
        ),
      ),
      page(Routes.myReviews, (_) => const MyReviewsScreen()),
      page('/folders/:folder', (s) => FolderScreen(name: Uri.decodeComponent(s.pathParameters['folder']!))),
      // Before '/badges/:badge', which would take "seasons" for a track.
      page(Routes.pastSeasons, (_) => const PastSeasonsScreen()),
      page('/badges/seasons/:season', (s) => SeasonBadgesScreen(seasonId: s.pathParameters['season']!)),
      page(
        '/badges/:badge/achievement',
        (s) => AchievementScreen(badgeKey: s.pathParameters['badge']!, earnedId: s.uri.queryParameters['earned']),
      ),
      page('/badges/:badge', (s) => BadgeTiersScreen(badgeKey: s.pathParameters['badge']!)),
    ],
  );
}
