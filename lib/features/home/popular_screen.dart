import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/corridor_row.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/place_list_row.dart';


/// Everything under "Explore by Popular", in one list.
class PopularScreen extends StatelessWidget {
  const PopularScreen({super.key});

  Future<(List<Destination>, List<Interest>, List<Corridor>)> _load(TravelRepository repo) async {
    final (places, interests, corridors) = await (
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

    return (places, interests, corridors);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<(List<Destination>, List<Interest>, List<Corridor>)>(
          load: () => _load(repo),
          builder: (context, data, _) =>
              _Body(places: data.$1, interests: data.$2, corridors: data.$3),
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.places, required this.interests, required this.corridors});

  /// Every place, the best known first.
  final List<Destination> places;
  final List<Interest> interests;

  /// What the Tourism Corridors chip is made of.
  final List<Corridor> corridors;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// The province being looked at; null is all of them.
  String? _province;

  /// The interest being looked at; null is all of them.
  int? _interest;

  /// A finer filter inside that interest.
  final _picked = <String>{};

  /// The groups of the chosen interest. Tourism Corridors is made of the
  /// corridors themselves.
  List<String> get _subCategories {
    if (_interest == null) return const [];
    final interest = widget.interests[_interest!];
    if (interest.isCorridors) return [for (final c in widget.corridors) c.name];
    return interest.groups.keys.toList();
  }

  bool get _onCorridors => _interest != null && widget.interests[_interest!].isCorridors;

  /// The best known places, narrowed by whatever is chosen.
  List<Destination> get _popular {
    final categories = _interest == null
        ? null
        : (_picked.isEmpty
              ? widget.interests[_interest!].categories.toSet()
              : {for (final g in _picked) ...?widget.interests[_interest!].groups[g]});
    return widget.places.where((d) {
      if (!d.featured && (d.rating ?? 0) < 4.6) return false;
      if (_province != null && d.province != _province) return false;
      if (categories != null && !categories.contains(d.category)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final places = _onCorridors ? const <Destination>[] : _popular;
    final shownCorridors = _picked.isEmpty
        ? widget.corridors
        : widget.corridors.where((c) => _picked.contains(c.name)).toList();
    // The provinces with something worth seeing, busiest first.
    final counts = <String, int>{};
    for (final d in widget.places) {
      if (!d.featured && (d.rating ?? 0) < 4.6) continue;
      counts[d.province] = (counts[d.province] ?? 0) + 1;
    }
    final provinces = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return Column(
      children: [
        BrowseSearchBar(hint: s.popularDestinations, onWhite: true),
        const SizedBox(height: 12),

        // Where to look…
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: provinces.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => i == 0
                ? _Chip(
                    label: s.all,
                    icon: Icons.public_rounded,
                    selected: _province == null,
                    onTap: () => setState(() => _province = null),
                  )
                : _Chip(
                    label: provinces[i - 1],
                    icon: Icons.place_outlined,
                    selected: _province == provinces[i - 1],
                    onTap: () => setState(
                      () => _province = _province == provinces[i - 1] ? null : provinces[i - 1],
                    ),
                  ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Divider(height: 1, color: AppColors.sand200),
        ),

        // …and what to look for.
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.interests.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => i == 0
                ? CategoryChip(
                    label: s.all,
                    selected: _interest == null,
                    onTap: () => setState(() => _interest = null),
                  )
                : CategoryChip(
                    label: bilingual(
                      context,
                      widget.interests[i - 1].name,
                      widget.interests[i - 1].nameKh,
                    ).$1,
                    selected: _interest == i - 1,
                    onTap: () => setState(() {
                      _interest = _interest == i - 1 ? null : i - 1;
                      _picked.clear();
                    }),
                  ),
          ),
        ),

        // What the chosen interest is made of, for a finer filter.
        if (_subCategories.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _subCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _subCategories[i];
                return CategoryChip(
                  label: c,
                  selected: _picked.contains(c),
                  onTap: () => setState(() {
                    _picked.contains(c) ? _picked.remove(c) : _picked.add(c);
                  }),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 14),

        Expanded(
          child: _onCorridors
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
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.sand200),
                      ),
                      child: Column(
                        children: [for (final d in places) PlaceListRow(destination: d)],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// A province chip, with its pin.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.violet : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? AppColors.violet : AppColors.violet.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : AppColors.violet),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.sans(
                13,
                weight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.violet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
