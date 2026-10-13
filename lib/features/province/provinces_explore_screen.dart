import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/async_view.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/interest_filter.dart';
import '../../widgets/corridor_row.dart';
import '../../widgets/place_group.dart';


/// Provinces and what to see in them, one interest at a time.
class ProvincesExploreScreen extends StatelessWidget {
  const ProvincesExploreScreen({super.key});

  Future<(List<Province>, List<Destination>, List<Interest>, List<Corridor>)> _load(
    TravelRepository repo,
  ) async {
    final (provinces, places, interests, corridors) = await (
      repo.getProvinces(),
      repo.getDestinations(),
      repo.getInterests(),
      repo.getCorridors(),
    ).wait;

    places.sort((a, b) {
      final byFeatured = (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
      if (byFeatured != 0) return byFeatured;
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      return byRating != 0 ? byRating : (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
    });

    return (provinces, places, interests, corridors);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<(List<Province>, List<Destination>, List<Interest>, List<Corridor>)>(
          load: () => _load(repo),
          builder: (context, data, _) {
            final (provinces, places, interests, corridors) = data;
            return _Body(
              provinces: provinces,
              places: places,
              interests: interests,
              corridors: corridors,
            );
          },
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({
    required this.provinces,
    required this.places,
    required this.interests,
    required this.corridors,
  });
  final List<Province> provinces;

  /// Every place, the best known first.
  final List<Destination> places;
  final List<Interest> interests;

  /// What the Tourism Corridors chip is made of.
  final List<Corridor> corridors;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// Which category is being looked at; null is "All".
  int? _index;

  /// A finer filter inside that category, once one is chosen.
  final _picked = <String>{};

  /// Every province, or only the ones with a few places worth seeing.
  bool _all = false;

  /// The groups of the chosen interest — AMS Travel's own names. Tourism
  /// Corridors is made of the corridors themselves.
  List<String> get _subCategories {
    if (_index == null) return const [];
    final interest = widget.interests[_index!];
    if (interest.isCorridors) return [for (final c in widget.corridors) c.name];
    return interest.groups.keys.toList();
  }

  /// The categories behind the groups that are picked.
  Set<String> get _pickedCategories => {
    for (final g in _picked) ...?widget.interests[_index!].groups[g],
  };

  /// A place is on a corridor when it sits near one of its stops.
  bool _onCorridor(Destination d) {
    final chosen = _picked.isEmpty
        ? widget.corridors
        : widget.corridors.where((c) => _picked.contains(c.name));
    for (final c in chosen) {
      if (nearAny([for (final st in c.stops) (st.lat, st.lng)], d.lat, d.lng)) return true;
    }
    return false;
  }

  List<(Province, List<Destination>)> get _groups {
    final interest = _index == null ? null : widget.interests[_index!];
    final onCorridors = interest?.isCorridors ?? false;
    final categories = interest == null || onCorridors
        ? null
        : (_picked.isEmpty ? interest.categories.toSet() : _pickedCategories);

    final byProvince = <String, List<Destination>>{};
    for (final d in widget.places) {
      if (onCorridors && !_onCorridor(d)) continue;
      if (categories != null && !categories.contains(d.category)) continue;
      (byProvince[d.province] ??= []).add(d);
    }
    final groups = <(Province, List<Destination>)>[
      for (final p in widget.provinces)
        if (_all || (byProvince[p.name] ?? const []).isNotEmpty) (p, byProvince[p.name] ?? const []),
    ];
    // All 25 stay in their own order; otherwise the fullest come first.
    if (_all) return groups;
    return groups..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final onCorridors = _index != null && widget.interests[_index!].isCorridors;
    final shownCorridors = _picked.isEmpty
        ? widget.corridors
        : widget.corridors.where((c) => _picked.contains(c.name)).toList();
    final groups = onCorridors ? const <(Province, List<Destination>)>[] : _groups;

    return Column(
      children: [
        BrowseSearchBar(hint: s.searchProvince),
        const SizedBox(height: 12),
        InterestFilter(
          interests: widget.interests,
          index: _index,
          onIndex: (i) => setState(() {
            _index = i;
            _picked.clear();
          }),
          groups: _subCategories,
          picked: _picked,
          onPicked: (g) => setState(() {
            _picked.contains(g) ? _picked.remove(g) : _picked.add(g);
          }),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: onCorridors
              // The corridors are not places in a province; they are the list.
              ? ListView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.sand200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.tourismCorridors,
                            style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                          ),
                          const SizedBox(height: 6),
                          for (final c in shownCorridors) CorridorRow(corridor: c),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView(
            padding: EdgeInsets.only(bottom: 20 + MediaQuery.paddingOf(context).bottom),
            children: [
              for (final (province, places) in groups)
                PlaceGroup(
                  title: bilingual(context, province.name, province.nameKh).$1,
                  route: Routes.provincePlaces(province.slug),
                  places: places,
                  showHeart: true,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: OutlinedButton(
                  onPressed: () => setState(() => _all = !_all),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: AppColors.violet),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _all
                        ? s.showLess
                        : s.showAllProvinces.replaceFirst('{n}', '${widget.provinces.length}'),
                    style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.violet),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
