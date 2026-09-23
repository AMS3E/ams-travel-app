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
import '../../widgets/destination_card.dart';

const _violet = Color(0xFF5B2EE5);

/// Browse by interest: pick a category, see its places, and what travellers
/// recommend inside it.
class InterestExploreScreen extends StatelessWidget {
  const InterestExploreScreen({super.key});

  Future<(List<Interest>, List<Destination>)> _load(TravelRepository repo) async {
    final (interests, places) = await (repo.getInterests(), repo.getDestinations()).wait;

    places.sort((a, b) {
      final byFeatured = (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
      if (byFeatured != 0) return byFeatured;
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      return byRating != 0 ? byRating : (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
    });

    // Corridors are not places, so they have nothing to fill this page with.
    return (interests.where((i) => i.categories.isNotEmpty).toList(), places);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<(List<Interest>, List<Destination>)>(
          load: () => _load(repo),
          builder: (context, data, _) {
            final (interests, places) = data;
            return _Body(interests: interests, places: places);
          },
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.interests, required this.places});
  final List<Interest> interests;

  /// Every place, the best known first.
  final List<Destination> places;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  int _index = 0;

  List<Destination> get _inInterest {
    if (widget.interests.isEmpty) return const [];
    final categories = widget.interests[_index].categories.toSet();
    return widget.places.where((d) => categories.contains(d.category)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final places = _inInterest;
    final recommended = places.where((d) => d.featured).take(5).toList();

    return Column(
      children: [
        const _SearchRow(),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.interests.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _CategoryChip(
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
                            Expanded(child: _PlaceTile(destination: places[i])),
                            const SizedBox(width: 12),
                            Expanded(
                              child: i + 1 < places.length
                                  ? _PlaceTile(destination: places[i + 1])
                                  : const SizedBox(),
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
                      for (final d in recommended) _RecommendRow(destination: d),
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

/// Back arrow and a search field; tapping it opens the suggestions page.
class _SearchRow extends StatelessWidget {
  const _SearchRow();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 30, color: AppColors.sand900),
          ),
          Expanded(
            child: Material(
              color: AppColors.sand100,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push(Routes.popularSearch),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 5, 5, 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.exploreInterest,
                          style: AppText.sans(14.5, color: AppColors.sand400),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Material(
                        color: _violet,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.push(Routes.popularSearch),
                          child: const Padding(
                            padding: EdgeInsets.all(9),
                            child: Icon(Icons.search_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One interest category along the top.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.interest, required this.selected, required this.onTap});
  final Interest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _violet : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? _violet : AppColors.sand200),
        ),
        child: Text(
          bilingual(context, interest.name, interest.nameKh).$1,
          style: AppText.sans(
            13.5,
            weight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.sand800,
          ),
        ),
      ),
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

/// Photo, name and what the place is — two to a row.
class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return InkWell(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
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
                  title,
                  style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  d.category,
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
  const _RecommendRow({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return InkWell(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
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
                    title,
                    style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.category}, ${d.province}',
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
              decoration: BoxDecoration(color: _violet.withValues(alpha: 0.10), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, size: 15, color: _violet),
            ),
          ],
        ),
      ),
    );
  }
}
