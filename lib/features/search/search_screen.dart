import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/location.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/place_list_row.dart';
import '../../widgets/overview_card.dart';
import '../../widgets/corridor_row.dart';
import 'filter_sheet.dart';

/// Opens what a typing suggestion points at: a province's places, a tourism
/// region, or the page of a place, stay, food place, activity or corridor.
void openSuggestion(BuildContext context, Suggestion s) => context.push(switch (s.kind) {
  SuggestionKind.province => Routes.provincePlaces(s.id),
  SuggestionKind.region => Routes.region(s.id),
  SuggestionKind.destination => Routes.target(CardType.destination, s.id),
  SuggestionKind.stay => Routes.target(CardType.stay, s.id),
  SuggestionKind.food => Routes.target(CardType.food, s.id),
  SuggestionKind.activity => Routes.target(CardType.activity, s.id),
  SuggestionKind.corridor => Routes.target(CardType.corridor, s.id),
});

/// One typing suggestion from `GET /search/suggest`.
class SuggestionRow extends StatelessWidget {
  const SuggestionRow({super.key, required this.suggestion, required this.onTap});
  final Suggestion suggestion;
  final VoidCallback onTap;

  static IconData iconOf(SuggestionKind kind) => switch (kind) {
    SuggestionKind.destination => Icons.place_outlined,
    SuggestionKind.stay => Icons.hotel_outlined,
    SuggestionKind.food => Icons.restaurant_outlined,
    SuggestionKind.activity => Icons.kayaking_outlined,
    SuggestionKind.corridor => Icons.route_outlined,
    SuggestionKind.province => Icons.map_outlined,
    SuggestionKind.region => Icons.landscape_outlined,
  };

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(
        children: [
          Icon(iconOf(suggestion.kind), size: 19, color: AppColors.violet),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              suggestion.name,
              style: AppText.sans(15, color: AppColors.sand800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.north_west_rounded, size: 16, color: AppColors.sand400),
        ],
      ),
    ),
  );
}

/// Search: keyword, kind chips and the Filters sheet, all answered by
/// `GET /search`; suggestions while typing from `GET /search/suggest`.
/// Before anything is asked: Explore by Nearby, recent keywords and the
/// recommended corridors.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.initialFilters});
  final String? initialQuery;

  /// Filters chosen before the screen opened: Explore's filter button passes
  /// what was picked in its sheet, so results show straight away.
  final SearchFilters? initialFilters;

  /// Recent keywords, newest first, kept on the device.
  static const recentKey = 'ams-travel:recent-searches';

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  late String _query = widget.initialQuery?.trim() ?? '';
  late SearchFilters _filters = widget.initialFilters ?? const SearchFilters();

  List<Suggestion> _suggestions = const [];
  int _suggestAsk = 0;

  /// The pages of results loaded so far.
  final _items = <PlaceCard>[];
  PageOf<PlaceCard>? _last;
  bool _loading = false;
  Object? _error;

  /// Bumped on every new search, so a late page of an old one is dropped.
  int _generation = 0;

  bool get _browsing => _query.isEmpty && _filters.isEmpty;

  @override
  void initState() {
    super.initState();
    _reload();
    _suggest(_query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _setQuery(v));
  }

  void _setQuery(String v) {
    final q = v.trim();
    if (q == _query) return;
    setState(() => _query = q);
    _reload();
    _suggest(q);
  }

  void _submit(String v) {
    _debounce?.cancel();
    _setQuery(v);
    if (_query.isNotEmpty) _remember(_query);
  }

  /// Puts [term] in the field and searches for it.
  void _searchTerm(String term) {
    _controller.text = term;
    _submit(term);
  }

  void _remember(String q) {
    final prefs = context.read<SharedPreferences>();
    final recent = [q, ...(prefs.getStringList(SearchScreen.recentKey) ?? const []).where((e) => e != q)];
    prefs.setStringList(SearchScreen.recentKey, recent.take(8).toList());
  }

  Future<void> _suggest(String q) async {
    final ask = ++_suggestAsk;
    if (q.isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    try {
      final found = await context.read<AmsApi>().suggest(q);
      if (mounted && ask == _suggestAsk) setState(() => _suggestions = found);
    } catch (_) {
      // Suggestions are a help, not the answer: the results still show.
      if (mounted && ask == _suggestAsk) setState(() => _suggestions = const []);
    }
  }

  /// Starts the results over for the current keyword and filters.
  void _reload() {
    _generation++;
    setState(() {
      _items.clear();
      _last = null;
      _error = null;
      _loading = false;
    });
    if (!_browsing) _loadMore();
  }

  /// The next page of `GET /search`.
  Future<void> _loadMore() async {
    if (_loading || (_last?.isLast ?? false)) return;
    final generation = _generation;
    final page = _last == null ? 0 : _last!.number + 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _filters.search(context.read<AmsApi>(), q: _query, page: page);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(result.content);
        _last = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _setFilters(SearchFilters next) {
    if (next == _filters) return;
    setState(() => _filters = next);
    _reload();
  }

  Future<void> _openFilters() async {
    final result = await showFilterSheet(context, _filters);
    if (result == null || !mounted) return;
    _setFilters(result);
  }

  void _openSuggestion(Suggestion s) {
    _remember(_query);
    openSuggestion(context, s);
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
              onSubmitted: _submit,
              onFilters: _openFilters,
              filterCount: _filters.count,
              onClear: _query.isEmpty && _controller.text.isEmpty
                  ? null
                  : () {
                      _controller.clear();
                      _debounce?.cancel();
                      _setQuery('');
                    },
            ),
            // After Apply Filters: only what was picked, each with a way to
            // drop it.
            if (_filters.count > 0) _AppliedFilters(filters: _filters, onChanged: _setFilters),
            Expanded(child: _browsing ? _Browse(onSearch: _searchTerm) : _results(context)),
          ],
        ),
      ),
    );
  }

  Widget _results(BuildContext context) {
    final s = S.of(context);
    final last = _last;
    final suggestions = _query.isEmpty ? const <Suggestion>[] : _suggestions;

    if (_items.isEmpty && _error != null) {
      return ErrorView(error: _error!, onRetry: _loadMore);
    }

    final header = <Widget>[
      for (final sug in suggestions) SuggestionRow(suggestion: sug, onTap: () => _openSuggestion(sug)),
      if (suggestions.isNotEmpty) const Divider(height: 18, indent: 20, endIndent: 20, color: AppColors.sand200),
      // TODO R-077: with no kind picked the server answers attractions only,
      // so a stay or food place can be suggested above yet missing here.
      if (last != null && _items.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            s.fill(s.searchFoundCount, {'n': last.totalElements}),
            style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
          ),
        ),
    ];

    Widget footer() {
      if (_loading) return const LoadingView(padding: EdgeInsets.all(24));
      if (_error != null) {
        return Center(
          child: TextButton.icon(onPressed: _loadMore, icon: const Icon(Icons.refresh_rounded), label: Text(s.retry)),
        );
      }
      if (last != null && _items.isEmpty) {
        return EmptyState(icon: Icons.search_off_rounded, title: s.searchNoMatches, body: s.searchNoMatchesBody);
      }
      return const SizedBox.shrink();
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: header.length + _items.length + 1,
      itemBuilder: (context, i) {
        if (i < header.length) return header[i];
        final at = i - header.length;
        if (at == _items.length) return footer();
        // Near the end of what is loaded: ask for the next page.
        if (at >= _items.length - 3 && !(last?.isLast ?? true) && !_loading && _error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadMore();
          });
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PlaceListRow(card: _items[at]),
        );
      },
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
                  const Icon(Icons.search_rounded, color: AppColors.violet),
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

/// What the traveller picked in the Filters sheet, as chips with a cross;
/// a tap drops that pick.
class _AppliedFilters extends StatefulWidget {
  const _AppliedFilters({required this.filters, required this.onChanged});
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  State<_AppliedFilters> createState() => _AppliedFiltersState();
}

class _AppliedFiltersState extends State<_AppliedFilters> {
  late Future<List<(String, SearchFilters)>> _chips = _load();

  Future<List<(String, SearchFilters)>> _load() =>
      appliedFilterChips(context.read<AmsApi>(), widget.filters).or(const []);

  @override
  void didUpdateWidget(_AppliedFilters old) {
    super.didUpdateWidget(old);
    if (old.filters != widget.filters) _chips = _load();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FutureBuilder<List<(String, SearchFilters)>>(
        future: _chips,
        builder: (context, snap) {
          final chips = snap.data ?? const [];
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              for (final (label, without) in chips)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InputChip(
                    label: Text(label),
                    labelStyle: AppText.sans(13, weight: FontWeight.w600, color: Colors.white),
                    backgroundColor: AppColors.violet,
                    side: const BorderSide(color: AppColors.violet),
                    shape: const StadiumBorder(),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                    onDeleted: () => widget.onChanged(without),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// What the screen shows before anything is asked.
class _Browse extends StatefulWidget {
  const _Browse({required this.onSearch});
  final ValueChanged<String> onSearch;

  @override
  State<_Browse> createState() => _BrowseState();
}

class _BrowseState extends State<_Browse> {
  late Future<PageOf<PlaceCard>> _corridors = context.read<AmsApi>().search(type: CardType.corridor);

  /// The five most browsed destinations across all the Tourism Regions
  /// (`GET /popular?regionIds=`). A failure leaves the section out.
  late final Future<List<PlaceCard>> _regionPlaces = () async {
    final api = context.read<AmsApi>();
    final regions = await api.tourismRegions();
    if (regions.isEmpty) return const <PlaceCard>[];
    return api.popular(regionIds: [for (final r in regions) r.id], limit: 5);
  }().or(const []);

  /// Five popular destinations anywhere (`GET /popular`), leaving out the
  /// ones already in the Tourism Regions list. A failure leaves it out.
  /// Asked for alongside the regions' list, not after it: ten is enough
  /// once the regions' five at most are left out.
  late final Future<List<PlaceCard>> _popular = () async {
    final (region, cards) = await (_regionPlaces, context.read<AmsApi>().popular(limit: 10)).wait;
    final shown = {for (final c in region) c.id};
    return cards.where((c) => !shown.contains(c.id)).take(5).toList();
  }().or(const []);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final prefs = context.read<SharedPreferences>();
    final recent = prefs.getStringList(SearchScreen.recentKey) ?? const [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const _Nearby(),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.recentSearches,
                    style: AppText.sans(18, weight: FontWeight.w700, color: AppColors.sand900),
                  ),
                ),
                TextButton(
                  // No extra tap-target height on the heading's line.
                  style: TextButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    await prefs.remove(SearchScreen.recentKey);
                    if (mounted) setState(() {});
                  },
                  child: Text(s.clearRecentSearches),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in recent)
                  GestureDetector(
                    onTap: () => widget.onSearch(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(99)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded, size: 16, color: AppColors.violet),
                          const SizedBox(width: 6),
                          Text(t, style: AppText.sans(13.5, color: AppColors.sand800)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        // Five destinations from across the Tourism Regions, then five
        // popular ones, as lists.
        _PlaceList(title: s.tourismRegions, places: _regionPlaces),
        _PlaceList(title: s.popularDestinations, places: _popular),
        const SizedBox(height: 22),
        _SectionTitle(s.recommendCorridors),
        FutureBuilder<PageOf<PlaceCard>>(
          future: _corridors,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _corridors = context.read<AmsApi>().search(type: CardType.corridor)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(s.retry),
                ),
              );
            }
            if (!snap.hasData) return const LoadingView(padding: EdgeInsets.all(24));
            // A list, like the places above it.
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [for (final c in snap.data!.content) CorridorRow(corridor: c)]),
            );
          },
        ),
      ],
    );
  }
}

/// A titled list of places, one row each, straight on the page; nothing
/// while it is empty.
class _PlaceList extends StatelessWidget {
  const _PlaceList({required this.title, required this.places});
  final String title;
  final Future<List<PlaceCard>> places;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlaceCard>>(
      future: places,
      builder: (context, snap) {
        if (!snap.hasData) return const LoadingView(padding: EdgeInsets.all(24));
        final cards = snap.data!;
        if (cards.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [for (final c in cards) PlaceListRow(card: c)]),
              ),
            ],
          ),
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

/// Explore by Nearby: the device position, then `GET /destinations/nearby`
/// as cards. A switched-off or refused location gets a gentle prompt.
class _Nearby extends StatefulWidget {
  const _Nearby();

  @override
  State<_Nearby> createState() => _NearbyState();
}

class _NearbyState extends State<_Nearby> {
  bool _busy = false;
  LocationProblem? _problem;
  Object? _error;
  List<PlaceCard>? _cards;

  Future<void> _find() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _problem = null;
      _error = null;
    });
    final api = context.read<AmsApi>();
    final here = await currentLocation();
    if (!mounted) return;
    if (!here.ok) {
      setState(() {
        _busy = false;
        _problem = here.problem;
      });
      return;
    }
    try {
      final cards = await api.nearbyCards(latitude: here.latitude!, longitude: here.longitude!);
      if (mounted) {
        setState(() {
          _busy = false;
          _cards = cards;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cards = _cards;
    final problem = _problem;

    String? note;
    String? action;
    VoidCallback? onAction;
    if (problem != null) {
      switch (problem) {
        case LocationProblem.serviceOff:
          note = s.nearbyLocationOff;
          action = s.openSettingsAction;
          onAction = () => openLocationSettings(problem);
        case LocationProblem.denied:
          note = s.nearbyLocationDenied;
          action = s.allowLocationAccess;
          onAction = _find;
        case LocationProblem.deniedForever:
          note = s.nearbyLocationDenied;
          action = s.openSettingsAction;
          onAction = () => openLocationSettings(problem);
        case LocationProblem.unavailable:
          note = s.nearbyLocationUnavailable;
          action = s.retry;
          onAction = _find;
      }
    } else if (_error != null) {
      note = s.somethingWentWrong;
      action = s.retry;
      onAction = _find;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _find,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const _PinsTile(),
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
                      Text(
                        _busy ? s.nearbyLocating : s.allowLocationAccess,
                        style: AppText.sans(13.5, color: AppColors.sand500),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: AppColors.sand100, shape: BoxShape.circle),
                  child: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.violet),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.violet),
                ),
              ],
            ),
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
              decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note, style: AppText.sans(13.5, color: AppColors.sand700, height: 1.4)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: onAction, child: Text(action!)),
                  ),
                ],
              ),
            ),
          ),
        if (cards != null && problem == null && _error == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: cards.isEmpty
                ? Text(s.nearbyNothing, style: AppText.sans(13.5, color: AppColors.sand500))
                : Column(children: [for (final c in cards) PlaceListRow(card: c)]),
          ),
      ],
    );
  }
}

/// The nearby tile: map pins scattered on a soft grey square with the
/// orange-to-violet border.
class _PinsTile extends StatelessWidget {
  const _PinsTile();

  static const _pins = [
    (left: 8.0, top: 6.0, size: 22.0),
    (left: 36.0, top: 12.0, size: 16.0),
    (left: 14.0, top: 34.0, size: 16.0),
    (left: 32.0, top: 32.0, size: 24.0),
  ];

  @override
  Widget build(BuildContext context) {
    return GradientFrame(
      radius: 18,
      expand: false,
      padding: EdgeInsets.zero,
      child: SizedBox.square(
        dimension: 60,
        child: Stack(
          children: [
            for (final p in _pins)
              Positioned(
                left: p.left,
                top: p.top,
                child: Icon(Icons.location_on_outlined, size: p.size, color: AppColors.violet),
              ),
          ],
        ),
      ),
    );
  }
}
