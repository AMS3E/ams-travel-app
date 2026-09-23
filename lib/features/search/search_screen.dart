import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';
import 'filter_sheet.dart';


enum _Scope { all, interests, regions, provinces, corridors }

/// Search, with suggestions before anything is typed: nearby, a few places,
/// recent searches and the corridors.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.initialFilters});
  final String? initialQuery;

  /// Filters chosen before the screen opened — Home's filter button passes
  /// what was picked in its sheet, so results show straight away.
  final SearchFilters? initialFilters;

  /// Recent searches, newest first.
  static const recentKey = 'ams-travel:recent-searches';

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  _Scope _scope = _Scope.all;
  String _query = '';
  Future<SearchResults>? _results;
  late SearchFilters _filters = widget.initialFilters ?? const SearchFilters();

  static const _popular = ['royal palace', 'wat phnom', 'kampot', 'kep', 'pub street', 'old market', 'angkor'];

  /// Suggestions for each chip, so a scope always has something to tap.
  static const _interestTerms = [
    'Attraction Sites',
    'Stays',
    'Food',
    'Water',
    'Activities & Experiences',
    'Tourism Corridors',
  ];
  static const _regionTerms = [
    'Ancient Capitals & Khmer Civilization Region',
    'Northeastern Civilization',
    'Mekong & Tonle Sap Civilization',
    'Mountain & Waterfall Region',
    'Coastal & Island Region',
    'Urban Lifestyle & Nightlife',
    'Khmer Culinary Region',
    'Eco-Community Tourism',
    'Luxury Tourism',
  ];
  static const _provinceTerms = [
    'Banteay Meanchey',
    'Battambang',
    'Kampong Cham',
    'Kampong Chhnang',
    'Kampong Speu',
    'Kampong Thom',
    'Kampot',
    'Kandal',
    'Kep',
    'Koh Kong',
    'Kratié',
    'Mondulkiri',
    'Oddar Meanchey',
    'Pailin',
    'Phnom Penh',
    'Preah Sihanouk',
    'Preah Vihear',
    'Prey Veng',
    'Pursat',
    'Ratanakiri',
    'Siem Reap',
    'Stung Treng',
    'Svay Rieng',
    'Takéo',
    'Tbong Khmum',
  ];
  static const _corridorTerms = [
    'Khmer Civilization',
    'Mekong Civilization',
    'Coastal Discovery',
    'Mountain Adventure',
    'Khmer Culinary',
  ];

  List<String>? get _scopeTerms => switch (_scope) {
    _Scope.all => null,
    _Scope.interests => _interestTerms,
    _Scope.regions => _regionTerms,
    _Scope.provinces => _provinceTerms,
    _Scope.corridors => _corridorTerms,
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery?.isNotEmpty ?? false) _run(widget.initialQuery!);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(v));
  }

  void _run(String v) {
    final q = v.trim();
    setState(() {
      _query = q;
      _results = q.isEmpty ? null : context.read<TravelRepository>().search(q);
    });
    if (q.isNotEmpty) _remember(q);
  }

  void _remember(String q) {
    final prefs = context.read<SharedPreferences>();
    final recent = [q, ...(prefs.getStringList(SearchScreen.recentKey) ?? const []).where((e) => e != q)];
    prefs.setStringList(SearchScreen.recentKey, recent.take(8).toList());
  }

  void _search(String term) {
    _controller.text = term;
    _run(term);
  }

  Future<void> _openFilters() async {
    final result = await showFilterSheet(context, _filters);
    if (result == null || !mounted) return;
    setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(
              controller: _controller,
              onChanged: _onChanged,
              onSubmitted: _run,
              onFilters: _openFilters,
              filterCount: _filters.count,
              onClear: _query.isEmpty
                  ? null
                  : () {
                      _controller.clear();
                      _run('');
                    },
            ),
            _ScopeChips(scope: _scope, onChanged: (v) => setState(() => _scope = v)),
            Expanded(
              child: _results == null
                  ? (_filters.isEmpty
                        ? _Suggestions(onSearch: _search, popular: _popular, scopeTerms: _scopeTerms)
                        : _FilteredPlaces(filters: _filters))
                  : FutureBuilder<SearchResults>(
                      future: _results,
                      builder: (context, snap) {
                        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => _run(_query));
                        if (!snap.hasData) return const LoadingView();
                        return _ResultsList(results: snap.data!, scope: _scope, query: _query, onSearch: _search);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back arrow, rounded field and the violet filter button.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onFilters,
    required this.filterCount,
    this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilters;
  final int filterCount;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.fromLTRB(16, 5, 5, 5),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.sand500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: controller.text.isEmpty,
                      textInputAction: TextInputAction.search,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      style: AppText.sans(15, color: AppColors.sand900),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: s.searchEverythingHint,
                        hintStyle: AppText.sans(15, color: AppColors.sand400),
                      ),
                    ),
                  ),
                  if (onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.cancel_rounded, size: 19, color: AppColors.sand400),
                      ),
                    ),
                  GestureDetector(
                    onTap: onFilters,
                    child: Badge(
                      isLabelVisible: filterCount > 0,
                      backgroundColor: AppColors.sunset500,
                      label: Text('$filterCount'),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.violet, borderRadius: BorderRadius.circular(22)),
                        child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeChips extends StatelessWidget {
  const _ScopeChips({required this.scope, required this.onChanged});
  final _Scope scope;
  final ValueChanged<_Scope> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labels = {
      _Scope.all: s.searchScopeAll,
      _Scope.interests: s.tabInterests,
      _Scope.regions: s.tabRegions,
      _Scope.provinces: s.tabProvinces,
      _Scope.corridors: s.tabCorridors,
    };
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          for (final entry in labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: scope == entry.key,
                showCheckmark: false,
                onSelected: (_) => onChanged(entry.key),
                selectedColor: AppColors.violet,
                labelStyle: AppText.sans(
                  13,
                  weight: FontWeight.w600,
                  color: scope == entry.key ? Colors.white : AppColors.sand700,
                ),
                side: BorderSide(color: scope == entry.key ? AppColors.violet : AppColors.sand200),
              ),
            ),
        ],
      ),
    );
  }
}

/// What the screen shows before anything is typed.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onSearch, required this.popular, this.scopeTerms});
  final ValueChanged<String> onSearch;
  final List<String> popular;

  /// Set when a chip other than "All" is selected: that list's own terms.
  final List<String>? scopeTerms;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final terms0 = scopeTerms;
    if (terms0 != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(s.tryThese, style: AppText.eyebrow(color: AppColors.sand500)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in terms0)
                GestureDetector(
                  onTap: () => onSearch(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(99)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.north_west_rounded, size: 15, color: AppColors.violet),
                        const SizedBox(width: 6),
                        Text(t, style: AppText.sans(13.5, color: AppColors.sand800)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }
    final repo = context.read<TravelRepository>();
    final recent = context.read<SharedPreferences>().getStringList(SearchScreen.recentKey) ?? const [];
    final terms = [...recent, ...popular.where((p) => !recent.contains(p))].take(10).toList();

    return AsyncView<(List<Destination>, List<Corridor>)>(
      load: () async {
        final (places, corridors) = await (repo.getDestinations(), repo.getCorridors()).wait;
        final featured = places.where((d) => d.featured).toList()
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        return (featured.take(5).toList(), corridors);
      },
      builder: (context, data, _) {
        final (places, corridors) = data;
        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _NearbyRow(onTap: () => showToast(context, s.locationSoon)),
            const SizedBox(height: 22),
            _SectionTitle(s.tourismRegion),
            for (final d in places) _PlaceRow(destination: d),
            const SizedBox(height: 18),
            _SectionTitle(s.recentAndPopular),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final t in terms)
                    GestureDetector(
                      onTap: () => onSearch(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(99)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place_outlined, size: 16, color: AppColors.violet),
                            const SizedBox(width: 6),
                            Text(t, style: AppText.sans(13.5, color: AppColors.sand800)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SectionTitle(s.recommendCorridors),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: corridors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _CorridorTile(corridor: corridors[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Places matching the Filters sheet, with no search text.
class _FilteredPlaces extends StatelessWidget {
  const _FilteredPlaces({required this.filters});
  final SearchFilters filters;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = context.read<TravelRepository>();
    return AsyncView<(List<Destination>, List<Interest>, List<Corridor>)>(
      key: ValueKey(filters.count),
      load: () => (repo.getDestinations(), repo.getInterests(), repo.getCorridors()).wait,
      builder: (context, data, _) {
        final (places, interests, corridors) = data;
        final matches = filters.apply(places, interests: interests, corridors: corridors);
        if (matches.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(icon: Icons.filter_alt_off_outlined, title: s.noResults, body: s.noResultsBody),
          );
        }
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                '${matches.length} ${s.places.toLowerCase()} ${s.found}',
                style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
              ),
            ),
            for (final d in matches) _PlaceRow(destination: d),
          ],
        );
      },
    );
  }
}

/// Matching places, then search suggestions built from the top match.
class _PlaceResults extends StatelessWidget {
  const _PlaceResults({required this.query, required this.onSearch});
  final String query;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = context.read<TravelRepository>();
    return AsyncView<List<Destination>>(
      key: ValueKey(query),
      load: () => repo.getDestinations(query: query),
      loading: const SizedBox.shrink(),
      builder: (context, places, _) {
        if (places.isEmpty) return const SizedBox.shrink();
        final top = places.first;
        // "Angkor Wat Sunrise", "Angkor Wat Temples"… from the top match.
        final terms = <String>{
          for (final tag in top.tags.take(3)) '${top.name} $tag',
          '${top.name} ${top.category}',
          '${top.name} ${top.province}',
        }.where((t) => t.toLowerCase() != query.toLowerCase()).take(5).toList();
        // The other matches, to explore next.
        final nearby = places.where((d) => d.key != top.key).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in places.take(3)) _PlaceRow(destination: d),
            const SizedBox(height: 6),
            for (final t in terms)
              InkWell(
                onTap: () => onSearch(t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 19, color: AppColors.sand500),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          t,
                          style: AppText.sans(15, color: AppColors.sand800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (nearby.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  s.recommendExplore,
                  style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final d in nearby.take(5))
                      GestureDetector(
                        onTap: () => onSearch(d.name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(99)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place_outlined, size: 15, color: AppColors.violet),
                              const SizedBox(width: 6),
                              Text(d.name, style: AppText.sans(13, color: AppColors.sand800)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Text(
      text,
      style: AppText.sans(18, weight: FontWeight.w700, color: AppColors.sand900),
    ),
  );
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.violet.withValues(alpha: 0.4)),
                color: AppColors.violet.withValues(alpha: 0.08),
              ),
              child: const Icon(Icons.pin_drop_outlined, color: AppColors.violet, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.exploreNearby,
                    style: AppText.sans(16.5, weight: FontWeight.w700, color: AppColors.sand900),
                  ),
                  const SizedBox(height: 3),
                  Text(s.allowLocationAccess, style: AppText.sans(13.5, color: AppColors.sand500)),
                ],
              ),
            ),
            const _GoButton(),
          ],
        ),
      ),
    );
  }
}

class _GoButton extends StatelessWidget {
  const _GoButton();

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: const BoxDecoration(color: AppColors.sand100, shape: BoxShape.circle),
    child: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.violet),
  );
}

/// Suggestion row: thumbnail, name and what the place is known for.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    final tags = [d.category, ...d.tags].take(3).join(', ');
    return InkWell(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            AppImage(d.image, width: 62, height: 62, radius: BorderRadius.circular(16)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tags,
                    style: AppText.sans(13.5, color: AppColors.sand500, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const _GoButton(),
          ],
        ),
      ),
    );
  }
}

class _CorridorTile extends StatelessWidget {
  const _CorridorTile({required this.corridor});
  final Corridor corridor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(Routes.corridor(corridor.slug)),
      child: SizedBox(
        width: 150,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(corridor.image),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.4, 1],
                    colors: [Color(0x00000000), Color(0xD9000000)],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      corridor.name,
                      style: AppText.sans(13.5, weight: FontWeight.w700, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      corridor.duration,
                      style: AppText.sans(11.5, color: Colors.white.withValues(alpha: 0.8)),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results, required this.scope, required this.query, required this.onSearch});
  final SearchResults results;
  final _Scope scope;
  final String query;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    bool show(_Scope sc) => scope == _Scope.all || scope == sc;

    Widget header(String title, int count) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        '$title  ·  $count',
        style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
      ),
    );

    Widget row({required String image, required String title, required String subtitle, required VoidCallback onTap}) =>
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                AppImage(image, width: 56, height: 56, radius: BorderRadius.circular(14)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.sans(15.5, weight: FontWeight.w700, color: AppColors.sand900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(13, color: AppColors.sand500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const _GoButton(),
              ],
            ),
          ),
        );

    final children = <Widget>[
      if (show(_Scope.interests) && results.interests.isNotEmpty) ...[
        header(s.tabInterests, results.interests.length),
        for (final i in results.interests)
          row(
            image: i.image,
            title: i.name,
            subtitle: i.description,
            onTap: () => context.push(Routes.interest(i.slug)),
          ),
      ],
      if (show(_Scope.regions) && results.regions.isNotEmpty) ...[
        header(s.tabRegions, results.regions.length),
        for (final r in results.regions)
          row(image: r.image, title: r.name, subtitle: r.tagline, onTap: () => context.push(Routes.region(r.slug))),
      ],
      if (show(_Scope.provinces) && results.provinces.isNotEmpty) ...[
        header(s.tabProvinces, results.provinces.length),
        for (final p in results.provinces)
          row(image: p.image, title: p.name, subtitle: p.tagline, onTap: () => context.push(Routes.province(p.slug))),
      ],
      if (show(_Scope.corridors) && results.corridors.isNotEmpty) ...[
        header(s.tabCorridors, results.corridors.length),
        for (final c in results.corridors)
          row(image: c.image, title: c.name, subtitle: c.duration, onTap: () => context.push(Routes.corridor(c.slug))),
      ],
    ];

    if (children.isEmpty) {
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 32),
        children: [_PlaceResults(query: query, onSearch: onSearch)],
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _PlaceResults(query: query, onSearch: onSearch),
        ...children,
      ],
    );
  }
}
