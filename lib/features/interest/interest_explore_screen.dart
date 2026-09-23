import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/destination_card.dart';


/// Browse by interest: pick a category, see its places, and what travellers
/// recommend inside it.
class InterestExploreScreen extends StatelessWidget {
  const InterestExploreScreen({super.key});

  Future<(List<Interest>, List<Destination>, List<Corridor>)> _load(TravelRepository repo) async {
    final (interests, places, corridors) = await (
      repo.getInterests(),
      repo.getDestinations(),
      repo.getCorridors(),
    ).wait;

    places.sort((a, b) {
      final byFeatured = (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
      if (byFeatured != 0) return byFeatured;
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      return byRating != 0 ? byRating : (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
    });

    return (interests, places, corridors);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<(List<Interest>, List<Destination>, List<Corridor>)>(
          load: () => _load(repo),
          builder: (context, data, _) {
            final (interests, places, corridors) = data;
            return _Body(interests: interests, places: places, corridors: corridors);
          },
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.interests, required this.places, required this.corridors});
  final List<Interest> interests;

  /// Every place, the best known first.
  final List<Destination> places;

  /// What the Tourism Corridors chip shows instead of places.
  final List<Corridor> corridors;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  int _index = 0;

  /// What the chosen chip holds: places, or the corridors themselves.
  (List<_Item>, List<_Item>) get _items {
    if (widget.interests.isEmpty) return (const [], const []);
    final interest = widget.interests[_index];

    if (interest.isCorridors) {
      final items = [
        for (final c in widget.corridors)
          _Item(
            image: c.image,
            title: c.name,
            subtitle: c.duration,
            detail: '${c.duration}, ${c.stops.length} ${S.read(context).stops.toLowerCase()}',
            route: Routes.corridor(c.slug),
          ),
      ];
      return (items, items.take(5).toList());
    }

    final categories = interest.categories.toSet();
    final places = widget.places.where((d) => categories.contains(d.category)).toList();
    _Item of(Destination d) => _Item(
      image: d.image,
      title: bilingual(context, d.name, d.nameKh).$1,
      subtitle: d.category,
      detail: '${d.category}, ${d.province}',
      route: Routes.destination(d.region, d.slug),
    );
    return (
      [for (final d in places) of(d)],
      [for (final d in places.where((d) => d.featured).take(5)) of(d)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (places, recommended) = _items;

    return Column(
      children: [
        BrowseSearchBar(hint: s.exploreInterest),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.interests.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => CategoryChip(
              interest: widget.interests[i],
              selected: i == _index,
              onTap: () => setState(() => _index = i),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(bottom: 20 + MediaQuery.paddingOf(context).bottom),
            children: [
              _Card(
                child: Column(
                  children: [
                    for (var i = 0; i < places.take(8).length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _PlaceTile(item: places[i])),
                            const SizedBox(width: 12),
                            Expanded(
                              child: i + 1 < places.length ? _PlaceTile(item: places[i + 1]) : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (recommended.isNotEmpty)
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.recommendTitle,
                        style: AppText.sans(17, weight: FontWeight.w700, color: AppColors.sand900),
                      ),
                      const SizedBox(height: 6),
                      for (final item in recommended) _RecommendRow(item: item),
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

/// The white rounded panel both halves of the page sit in.
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: child,
    );
  }
}

/// One thing this page can show: a place, or a corridor.
class _Item {
  const _Item({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.route,
  });

  final String image;
  final String title;

  /// The short line in the grid.
  final String subtitle;

  /// The longer line under a recommendation.
  final String detail;
  final String route;
}

/// Photo, name and what the place is — two to a row.
class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.item});
  final _Item item;

  @override
  Widget build(BuildContext context) {
    final d = item;
    return InkWell(
      onTap: () => context.push(d.route),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: AppImage(d.image, radius: BorderRadius.circular(12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.title,
                  style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  d.subtitle,
                  style: AppText.sans(11.5, color: AppColors.sand500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A place travellers recommend: photo, name, what it is, and a way in.
class _RecommendRow extends StatelessWidget {
  const _RecommendRow({required this.item});
  final _Item item;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = item;
    return InkWell(
      onTap: () => context.push(d.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: AppImage(d.image, radius: BorderRadius.circular(12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.title,
                    style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.detail,
                    style: AppText.sans(12, color: AppColors.sand500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF34D399)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          s.recommendByTraveler,
                          style: AppText.sans(11.5, color: AppColors.sand500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: 0.10), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.violet),
            ),
          ],
        ),
      ),
    );
  }
}
