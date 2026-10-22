import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/auth_provider.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/place_group.dart';
import '../auth/sign_in.dart' as auth;
import 'saved_tiles.dart';

/// Everything the traveller saved (`GET /favorites`, then the cards with
/// `GET /search/cards` per kind), grouped by tourism region, province and
/// interest. A guest is invited to sign in.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final signedIn = context.select<AuthProvider, bool>((a) => a.isSignedIn);
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(s.savedTitle, style: AppText.display(20)), centerTitle: true),
        body: const SavedSignIn(),
      );
    }
    return const _SignedInSaved();
  }
}

/// What a guest sees on Saved: why to sign in, and the two ways to.
class SavedSignIn extends StatelessWidget {
  const SavedSignIn({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          EmptyState(
            icon: Icons.favorite_border_rounded,
            title: s.savedSignInTitle,
            body: s.savedSignInBody,
            actionLabel: s.logIn,
            onAction: () => auth.signIn(context),
          ),
          TextButton(onPressed: () => auth.register(context), child: Text(s.registerCta)),
        ],
      ),
    );
  }
}

class _SignedInSaved extends StatefulWidget {
  const _SignedInSaved();

  @override
  State<_SignedInSaved> createState() => _SignedInSavedState();
}

/// The names the group tabs are titled with.
typedef _Names = (List<CatalogRegion>, List<CatalogProvince>, List<CatalogInterest>);

class _SignedInSavedState extends State<_SignedInSaved> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 4, vsync: this);
  late final SavedCards _cards = SavedCards(context.read<AmsApi>(), known: context.read<SavedProvider>().cardFor);
  Future<void>? _favorites;
  Future<_Names>? _names;
  SavedView _view = SavedView.list;

  @override
  void initState() {
    super.initState();
    final saved = context.read<SavedProvider>();
    if (!saved.isLoaded) _favorites = saved.load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _cards.dispose();
    super.dispose();
  }

  Future<_Names> _loadNames() {
    final api = context.read<AmsApi>();
    return _names ??= (
      api.tourismRegions(),
      api.provinces(),
      api.interests(),
    ).wait.then((r) => ([...r.$1]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)), r.$2, r.$3));
  }

  Future<void> _refresh() async {
    await context.read<SavedProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final saved = context.watch<SavedProvider>();
    final keys = [for (final f in saved.favorites) ?favoriteKey(f)];
    if (saved.isLoaded && !_cards.covers(keys)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cards.ensure(keys);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.savedTitle, style: AppText.display(20)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: AppColors.violet,
          labelColor: AppColors.violet,
          tabs: [
            // Everything saved: places, and regions and provinces themselves.
            Tab(text: '${s.saves} (${saved.count})'),
            // The saved regions and provinces, then the saved places grouped
            // by their region and province.
            Tab(text: s.tabRegions),
            Tab(text: s.tabProvinces),
            Tab(text: s.tabInterests),
          ],
        ),
      ),
      body: FutureBuilder<void>(
        future: _favorites,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
          if (!saved.isLoaded) {
            return ErrorView(error: s.somethingWentWrong, onRetry: () => setState(() => _favorites = saved.load()));
          }
          return ListenableBuilder(
            listenable: _cards,
            builder: (context, _) {
              if (_cards.error != null) {
                return ErrorView(error: _cards.error!, onRetry: () => _cards.retry(keys));
              }
              final cards = _cards.cardsOf(keys);
              final waiting = !_cards.covers(keys);
              final savedRegions = saved.idsOf(SavedKind.region);
              final savedProvinces = saved.idsOf(SavedKind.province);
              return TabBarView(
                controller: _tabs,
                children: [
                  _SavesTab(
                    cards: cards,
                    savedRegions: savedRegions,
                    savedProvinces: savedProvinces,
                    loadNames: _loadNames,
                    waiting: waiting,
                    view: _view,
                    onView: (v) => setState(() => _view = v),
                    onRefresh: _refresh,
                  ),
                  for (final by in _GroupBy.values)
                    waiting
                        ? const LoadingView()
                        : AsyncView<_Names>(
                            load: _loadNames,
                            builder: (context, names, _) => _GroupTab(
                              by: by,
                              cards: cards,
                              names: names,
                              savedRegions: savedRegions,
                              savedProvinces: savedProvinces,
                            ),
                          ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Every saved item: the saved regions and provinces in a row on top, then
/// the places as a list or a grid.
class _SavesTab extends StatelessWidget {
  const _SavesTab({
    required this.cards,
    required this.savedRegions,
    required this.savedProvinces,
    required this.loadNames,
    required this.waiting,
    required this.view,
    required this.onView,
    required this.onRefresh,
  });
  final List<PlaceCard> cards;
  final List<String> savedRegions;
  final List<String> savedProvinces;
  final Future<_Names> Function() loadNames;
  final bool waiting;
  final SavedView view;
  final ValueChanged<SavedView> onView;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (savedRegions.isEmpty && savedProvinces.isEmpty) return _body(context, const []);
    return AsyncView<_Names>(
      load: loadNames,
      builder: (context, names, _) => _body(context, [
        ..._savedAreas(names, regions: savedRegions),
        ..._savedAreas(names, provinces: savedProvinces),
      ]),
    );
  }

  Widget _body(BuildContext context, List<_Area> areas) {
    final s = S.of(context);
    if (cards.isEmpty && waiting) return const LoadingView();
    if (cards.isEmpty && areas.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [EmptyState(icon: Icons.favorite_border_rounded, title: s.emptySaved, body: s.emptySavedBody)],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [ViewToggle(view: view, onChanged: onView)],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: SavedCardsView(
              cards: cards,
              view: view,
              header: areas.isEmpty ? null : _SavedAreas(areas: areas),
            ),
          ),
        ),
      ],
    );
  }
}

enum _GroupBy { region, province, interest }

/// The saved places grouped by one of their own fields: `tourismRegionIds`,
/// `provinceId` or `interestIds`, each group titled with its name.
class _GroupTab extends StatelessWidget {
  const _GroupTab({
    required this.by,
    required this.cards,
    required this.names,
    required this.savedRegions,
    required this.savedProvinces,
  });
  final _GroupBy by;
  final List<PlaceCard> cards;
  final _Names names;

  /// Regions and provinces saved themselves (`GET /favorites` REGION /
  /// PROVINCE), newest first.
  final List<String> savedRegions;
  final List<String> savedProvinces;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (regions, provinces, interests) = names;
    final groups = <(String, String, List<PlaceCard>)>[
      if (by == _GroupBy.region)
        for (final r in regions)
          (
            r.name,
            Routes.region(r.id),
            [
              for (final c in cards)
                if (c.tourismRegionIds.contains(r.id)) c,
            ],
          ),
      if (by == _GroupBy.province)
        for (final p in provinces)
          (
            p.name,
            Routes.province(p.id),
            [
              for (final c in cards)
                if (c.provinceId == p.id) c,
            ],
          ),
      if (by == _GroupBy.interest)
        for (final g in InterestGroup.of(interests))
          for (final i in g.interests)
            (
              i.name,
              Routes.interest(i.groupName),
              [
                for (final c in cards)
                  if (c.interestIds.contains(i.id)) c,
              ],
            ),
    ].where((g) => g.$3.isNotEmpty).toList();

    final areas = switch (by) {
      _GroupBy.region => _savedAreas(names, regions: savedRegions),
      _GroupBy.province => _savedAreas(names, provinces: savedProvinces),
      _GroupBy.interest => const <_Area>[],
    };

    if (groups.isEmpty && areas.isEmpty) {
      return SingleChildScrollView(
        child: EmptyState(icon: Icons.favorite_border_rounded, title: s.emptySaved, body: s.nothingToGroup),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(top: 14, bottom: 24 + MediaQuery.paddingOf(context).bottom),
      itemCount: groups.length + (areas.isEmpty ? 0 : 1),
      itemBuilder: (_, i) {
        if (areas.isNotEmpty) {
          if (i == 0) return _SavedAreas(areas: areas);
          i--;
        }
        return PlaceGroup(title: groups[i].$1, route: groups[i].$2, places: groups[i].$3, showHeart: true);
      },
    );
  }
}

/// The saved regions or provinces among [names], in the order saved.
List<_Area> _savedAreas(_Names names, {List<String> regions = const [], List<String> provinces = const []}) {
  final regionById = {for (final r in names.$1) r.id: r};
  final provinceById = {for (final p in names.$2) p.id: p};
  return [
    for (final id in regions)
      if (regionById[id] case final r?) _Area(r.id, r.name, r.coverUrl, Routes.region(r.id), SavedKind.region),
    for (final id in provinces)
      if (provinceById[id] case final p?)
        _Area(p.id, p.name, p.coverUrl, Routes.provincePlaces(p.id), SavedKind.province),
  ];
}

/// A saved region or province.
class _Area {
  const _Area(this.id, this.name, this.cover, this.route, this.kind);
  final String id;
  final String name;
  final String cover;
  final String route;
  final SavedKind kind;
}

/// The saved regions or provinces themselves, in a row above the places.
class _SavedAreas extends StatelessWidget {
  const _SavedAreas({required this.areas});
  final List<_Area> areas;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: areas.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final a = areas[i];
            return GestureDetector(
              onTap: () => context.push(a.route),
              child: SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppImage(a.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.35, 1],
                            colors: [Color(0x00000000), Color(0xCC000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: SaveButton(kind: a.kind, itemKey: a.id, size: 34),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 10,
                        child: Text(
                          a.name,
                          style: AppText.sans(14, weight: FontWeight.w700, color: Colors.white, height: 1.25),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
