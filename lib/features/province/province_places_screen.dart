import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/interest_filter.dart';
import '../../widgets/corridor_row.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/place_list_row.dart';

/// Everything in one province, a category at a time.
class ProvincePlacesScreen extends StatelessWidget {
  const ProvincePlacesScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<(Province, List<Destination>, List<Interest>, List<Corridor>)>(
          load: () async {
            final (province, places, interests, corridors) = await (
              repo.getProvince(slug),
              repo.getDestinations(province: slug),
              repo.getInterests(),
              repo.getCorridors(),
            ).wait;
            places.sort((a, b) {
              final byFeatured = (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
              if (byFeatured != 0) return byFeatured;
              return (b.rating ?? 0).compareTo(a.rating ?? 0);
            });
            return (province, places, interests, corridors);
          },
          builder: (context, data, _) {
            final (province, places, interests, corridors) = data;
            return _Body(
              province: province,
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
    required this.province,
    required this.places,
    required this.interests,
    required this.corridors,
  });

  final Province province;
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

  /// The groups of the chosen interest — AMS Travel's own names. Tourism
  /// Corridors is made of the corridors themselves.
  List<String> get _subCategories {
    if (_index == null) return const [];
    final interest = widget.interests[_index!];
    if (interest.isCorridors) return [for (final c in widget.corridors) c.name];
    return interest.groups.keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = bilingual(context, widget.province.name, widget.province.nameKh).$1;
    final interest = _index == null ? null : widget.interests[_index!];
    final onCorridors = interest?.isCorridors ?? false;
    final categories = interest == null || onCorridors
        ? null
        : (_picked.isEmpty
              ? interest.categories.toSet()
              : {for (final g in _picked) ...?interest.groups[g]});
    // Every corridor shows, as the taxonomy lists them.
    final shownCorridors = _picked.isEmpty
        ? widget.corridors
        : widget.corridors.where((c) => _picked.contains(c.name)).toList();

    final places = onCorridors
        ? const <Destination>[]
        : categories == null
        ? widget.places
        : widget.places.where((d) => categories.contains(d.category)).toList();

    return Column(
      children: [
        BrowseSearchBar(hint: '${s.exploreMoreIn} $name'),
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
              // The corridors are not places; they are the list.
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
              : places.isEmpty
              ? Center(child: Text(s.noResults, style: AppText.sans(14.5, color: AppColors.sand500)))
              : ListView(
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
                            name,
                            style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                          ),
                          const SizedBox(height: 6),
                          for (final d in places) PlaceListRow(destination: d),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
