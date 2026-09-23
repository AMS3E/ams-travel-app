import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/map_view.dart';

class ProvinceScreen extends StatelessWidget {
  const ProvinceScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return AsyncView<(Province, List<Destination>, List<Region>)>(
      load: () => (repo.getProvince(slug), repo.getDestinations(province: slug), repo.getRegions()).wait,
      loading: const Scaffold(body: LoadingView()),
      builder: (context, data, _) => _ProvinceView(province: data.$1, destinations: data.$2, regions: data.$3),
    );
  }
}

class _ProvinceView extends StatelessWidget {
  const _ProvinceView({required this.province, required this.destinations, required this.regions});
  final Province province;
  final List<Destination> destinations;
  final List<Region> regions;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (title, subtitle) = bilingual(context, province.name, province.nameKh);

    // Group by region, in the regions' own order.
    final byRegion = <Region, List<Destination>>{
      for (final r in regions)
        if (destinations.any((d) => d.region == r.slug)) r: destinations.where((d) => d.region == r.slug).toList(),
    };
    final categories = destinations.map((d) => d.category).toSet().length;

    return DetailScaffold(
      title: title,
      image: province.image,
      expandedHeight: 400,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.province.toUpperCase(), style: AppText.eyebrow(color: AppColors.sunset200)),
          const SizedBox(height: 10),
          Text(title, style: AppText.display(34, color: Colors.white)),
          if (subtitle != null) KhmerText(subtitle, color: Colors.white70, size: 15),
          const SizedBox(height: 8),
          Text(province.tagline, style: AppText.sans(15, color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 18),
          Row(
            children: [
              StatBlock(value: '${destinations.length}', label: s.destinations, onDark: true),
              const SizedBox(width: 28),
              StatBlock(value: '${byRegion.length}', label: s.regions, onDark: true),
              const SizedBox(width: 28),
              StatBlock(value: '$categories', label: s.categories, onDark: true),
            ],
          ),
        ],
      ),
      slivers: [
        SliverToBoxAdapter(
          child: DetailSection(
            title: s.onTheMap,
            subtitle: '${destinations.length} ${s.pinnedIn} ${province.name}.',
            child: MapPreview(
              height: 260,
              expandLabel: s.openFullMap,
              onExpand: () => context.go(Routes.map),
              child: AppMap(
                initialCenter: LatLng(province.lat, province.lng),
                initialZoom: 9,
                fitToPins: destinations.length > 1,
                pins: [
                  for (final d in destinations)
                    MapPin(
                      id: d.key,
                      point: LatLng(d.lat, d.lng),
                      color: AppColors.forRegion(d.region),
                      onTap: () => context.push(Routes.destination(d.region, d.slug)),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (destinations.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.travel_explore_rounded,
              title: s.noResults,
              body: province.tagline,
              actionLabel: s.allNineRegions,
              onAction: () => context.go(Routes.explore),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
              child: SectionHeader(
                title: '${destinations.length} ${s.destinations.toLowerCase()} · ${province.name}',
                subtitle: s.groupedByRegion,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          for (final entry in byRegion.entries) ...[
            SliverToBoxAdapter(
              child: _RegionGroupHeader(region: entry.key, count: entry.value.length),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 322,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: entry.value.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => Align(
                    alignment: Alignment.topCenter,
                    child: DestinationCard(destination: entry.value[i], width: 280),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _RegionGroupHeader extends StatelessWidget {
  const _RegionGroupHeader({required this.region, required this.count});
  final Region region;
  final int count;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (name, _) = bilingual(context, region.name, region.nameKh);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 8, 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: AppColors.forRegion(region.slug), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$name  ($count)',
              style: AppText.sans(15.5, weight: FontWeight.w600, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: () => context.push(Routes.region(region.slug)), child: Text(s.allOfRegion)),
        ],
      ),
    );
  }
}
