import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/interest_card.dart';
import '../explore/explore_screen.dart';

/// One interest followed across every region and province, with the other
/// interests as tabs along the top. The `corridors` interest (Tourism
/// Corridors) lists corridors instead of places.
class InterestScreen extends StatelessWidget {
  const InterestScreen({super.key, this.slug});

  /// Which category opens first; without one the page starts on the first tab.
  final String? slug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    // Everything is loaded once so the tabs switch without another round trip.
    // TODO(api): if the places endpoint is slow, fetch per tab instead.
    return AsyncView<(List<Interest>, List<Region>, List<Destination>, List<Corridor>)>(
      load: () => (repo.getInterests(), repo.getRegions(), repo.getDestinations(), repo.getCorridors()).wait,
      loading: const Scaffold(body: LoadingView()),
      builder: (context, data, _) => _InterestView(
        slug: slug ?? data.$1.first.slug,
        interests: data.$1,
        regions: data.$2,
        destinations: data.$3,
        corridors: data.$4,
      ),
    );
  }
}

class _InterestView extends StatefulWidget {
  const _InterestView({
    required this.slug,
    required this.interests,
    required this.regions,
    required this.destinations,
    required this.corridors,
  });

  final String slug;
  final List<Interest> interests;
  final List<Region> regions;
  final List<Destination> destinations;
  final List<Corridor> corridors;

  @override
  State<_InterestView> createState() => _InterestViewState();
}

class _InterestViewState extends State<_InterestView> {
  late String _slug = widget.slug;

  Interest get _interest =>
      widget.interests.firstWhere((i) => i.slug == _slug, orElse: () => widget.interests.first);

  /// Every place in the open interest.
  List<Destination> get _places {
    final categories = _interest.categories.toSet();
    return widget.destinations.where((d) => categories.contains(d.category)).toList();
  }

  void _openInterest(String slug) => setState(() => _slug = slug);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final interest = _interest;
    final (title, _) = bilingual(context, interest.name, interest.nameKh);
    final (icon, color) = interestStyle(interest);

    final list = _places;

    return DetailScaffold(
      title: title,
      image: interest.image,
      expandedHeight: 320,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Text(s.tabInterests.toUpperCase(), style: AppText.eyebrow(color: AppColors.sunset200)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: AppText.display(32, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            interest.description,
            style: AppText.sans(14.5, color: Colors.white.withValues(alpha: 0.85), height: 1.45),
          ),
        ],
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _CategoryTabs(
            interests: widget.interests,
            selected: _slug,
            onSelect: _openInterest,
          ),
        ),
        if (interest.isCorridors) ..._corridorSlivers(s) else ..._destinationSlivers(s, list),
      ],
    );
  }

  List<Widget> _corridorSlivers(S s) => [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${widget.corridors.length} ', style: AppText.display(20)),
              TextSpan(
                text: s.corridors.toLowerCase(),
                style: AppText.sans(14, color: AppColors.sand500),
              ),
            ],
          ),
        ),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.separated(
        itemCount: widget.corridors.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, i) => CorridorListCard(corridor: widget.corridors[i]),
      ),
    ),
  ];

  List<Widget> _destinationSlivers(S s, List<Destination> list) => [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${list.length} ', style: AppText.display(20)),
              TextSpan(
                text: '${s.destinations.toLowerCase()} ${s.found}',
                style: AppText.sans(14, color: AppColors.sand500),
              ),
            ],
          ),
        ),
      ),
    ),
    if (list.isEmpty)
      SliverToBoxAdapter(
        child: EmptyState(icon: Icons.search_off_rounded, title: s.noResults, body: s.noResultsBody),
      )
    else
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 18,
            crossAxisSpacing: 14,
            mainAxisExtent: 288,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) => _PlaceGridCard(
            destination: list[i],
            regionName: _regionName(list[i].region),
          ),
        ),
      ),
  ];

  String? _regionName(String slug) {
    final region = widget.regions.where((r) => r.slug == slug).firstOrNull;
    return region == null ? null : bilingual(context, region.name, region.nameKh).$1;
  }
}

/// Two-up card: square photo with the heart (and a tick for verified places),
/// then the name, its province and the region it belongs to.
class _PlaceGridCard extends StatelessWidget {
  const _PlaceGridCard({required this.destination, this.regionName});

  final Destination destination;
  final String? regionName;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(child: AppImage(d.image, radius: BorderRadius.circular(18))),
                Positioned(
                  top: 8,
                  left: 8,
                  child: SaveButton(kind: SavedKind.destination, itemKey: d.key, size: 34),
                ),
                if (d.verified)
                  Positioned(
                    top: 50,
                    left: 12,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(color: Color(0xFFD7F5EC), shape: BoxShape.circle),
                      child: const Icon(Icons.verified_user_rounded, size: 15, color: AppColors.success),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.sand500),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  d.province,
                  style: AppText.sans(12.5, color: AppColors.sand500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (regionName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.sand200),
              ),
              child: Text(
                regionName!,
                style: AppText.sans(11.5, color: AppColors.sand700, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The interests as underlined tabs, the open one in black.
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.interests, required this.selected, required this.onSelect});

  final List<Interest> interests;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.sand200)),
      ),
      child: SizedBox(
        height: 46,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: interests.length,
          itemBuilder: (context, i) {
            final interest = interests[i];
            final isSelected = interest.slug == selected;
            return InkWell(
              onTap: () => onSelect(interest.slug),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppColors.sand900 : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  bilingual(context, interest.name, interest.nameKh).$1,
                  style: AppText.sans(
                    14,
                    weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.sand900 : AppColors.sand500,
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
