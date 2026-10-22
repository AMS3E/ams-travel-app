import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/map_view.dart';

/// One province: where its places are, and the first of them
/// (`GET /provinces`, `GET /search?provinceId=&size=100`).
class ProvinceScreen extends StatelessWidget {
  const ProvinceScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return AsyncView<(CatalogProvince, PageOf<PlaceCard>)>(
      load: () => (api.province(id), api.search(provinceId: id, size: 100)).wait,
      loading: const Scaffold(body: LoadingView()),
      builder: (context, data, _) => _ProvinceView(province: data.$1, places: data.$2),
    );
  }
}

class _ProvinceView extends StatelessWidget {
  const _ProvinceView({required this.province, required this.places});
  final CatalogProvince province;
  final PageOf<PlaceCard> places;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cards = places.content;
    final pinned = [
      for (final c in cards)
        if (c.hasPin) c,
    ];

    return DetailScaffold(
      title: province.name,
      image: province.coverUrl,
      expandedHeight: 340,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.province.toUpperCase(), style: AppText.eyebrow(color: AppColors.sunset200)),
          const SizedBox(height: 10),
          Text(province.name, style: AppText.display(34, color: Colors.white)),
          const SizedBox(height: 18),
          Row(
            children: [
              StatBlock(value: thousands(province.placeCount), label: s.places, onDark: true),
              if (province.averageRating != null) ...[
                const SizedBox(width: 28),
                StatBlock(
                  value: province.averageRating!.toStringAsFixed(1),
                  suffix: ' ★',
                  label: s.fill(s.reviewsCountLabel, {'n': thousands(province.reviewCount)}),
                  onDark: true,
                ),
              ],
            ],
          ),
        ],
      ),
      slivers: [
        if (pinned.isNotEmpty)
          SliverToBoxAdapter(
            child: DetailSection(
              title: s.onTheMap,
              subtitle: '${thousands(pinned.length)} ${s.pinnedIn} ${province.name}.',
              child: MapPreview(
                height: 260,
                child: AppMap(
                  fitToPins: pinned.length > 1,
                  pins: [
                    for (final c in pinned)
                      MapPin(
                        id: c.id,
                        point: LatLng(c.latitude!, c.longitude!),
                        color: AppColors.violet,
                        onTap: () => context.push(Routes.card(c)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (cards.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.travel_explore_rounded,
              title: s.noResults,
              body: s.noResultsBody,
              actionLabel: s.exploreRegions,
              onAction: () => context.push(Routes.exploreRegions),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SectionHeader(title: '${s.destinations} · ${province.name}', padding: EdgeInsets.zero),
                  ),
                  TextButton(onPressed: () => context.push(Routes.provincePlaces(province.id)), child: Text(s.viewAll)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 322,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => Align(
                  alignment: Alignment.topCenter,
                  child: DestinationCard(card: cards[i], width: 280),
                ),
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: bottomInset(context))),
      ],
    );
  }
}
