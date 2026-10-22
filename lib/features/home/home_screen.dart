import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/location.dart';
import '../../data/api/ams_api.dart';
import '../../state/collections_provider.dart';
import '../../state/notifications_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/interest_style.dart';
import '../search/filter_sheet.dart';

/// Everything Explore shows, read as a guest from the public API.
class _HomeData {
  _HomeData({
    required this.groups,
    required this.regions,
    required this.popular,
    required this.corridors,
    required this.provinces,
  });

  final List<InterestGroup> groups;
  final List<CatalogRegion> regions;
  final List<PlaceCard> popular;
  final List<PlaceCard> corridors;
  final List<CatalogProvince> provinces;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<_HomeData> _load(AmsApi api) async {
    final (interests, regions, popular, corridors, provinces) = await (
      api.interests(),
      api.tourismRegions(),
      api.popular(limit: 10),
      api.search(type: CardType.corridor),
      api.provinces(),
    ).wait;
    return _HomeData(
      groups: InterestGroup.of(interests),
      regions: regions,
      popular: popular,
      corridors: corridors.content,
      provinces: provinces,
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: AsyncView<_HomeData>(
            load: () => _load(api),
            builder: (context, data, reload) => RefreshIndicator(
              onRefresh: reload,
              color: AppColors.violet,
              child: _HomeBody(data: data),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.data});
  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return ListView(
      padding: EdgeInsets.only(bottom: bottomInset(context)),
      children: [
        const _TopBar(),
        const SizedBox(height: 14),
        const _SearchBar(),
        const SizedBox(height: 18),
        _QuickActions(groups: data.groups),
        const SizedBox(height: 22),

        // Tourism regions
        _SectionHeader(title: s.exploreByRegion, onMore: () => context.push(Routes.exploreRegions)),
        SizedBox(
          height: 212,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.regions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final r = data.regions[i];
              return _WideCard(
                image: r.coverUrl,
                title: r.name,
                // Staff marked the region.
                seal: r.amsRecommended ? s.recommendByAms : null,
                savedKind: SavedKind.region,
                savedKey: r.id,
                onTap: () => context.push(Routes.region(r.id)),
              );
            },
          ),
        ),
        const SizedBox(height: 22),

        // Popular places: the server fills the row up to its limit.
        if (data.popular.isNotEmpty) ...[
          _SectionHeader(title: s.exploreByPopular, onMore: () => context.push(Routes.popular)),
          SizedBox(
            height: 182,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: data.popular.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _SmallCard.place(context, data.popular[i]),
            ),
          ),
          const SizedBox(height: 22),
        ],

        // Corridors
        _SectionHeader(title: s.exploreByCorridors, onMore: () => context.push(Routes.exploreCorridors)),
        SizedBox(
          height: 212,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.corridors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = data.corridors[i];
              return _WideCard(
                image: c.coverUrl,
                title: c.name,
                averageRating: c.averageRating,
                reviewCount: c.reviewCount,
                scored: true,
                savedKind: SavedKind.corridor,
                savedKey: c.id,
                onTap: () => context.push(Routes.corridor(c.id)),
              );
            },
          ),
        ),
        const SizedBox(height: 22),

        // Provinces
        _SectionHeader(title: s.exploreByProvinces, onMore: () => context.push(Routes.exploreProvinces)),
        SizedBox(
          height: 182,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.provinces.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _SmallCard.province(context, data.provinces[i]),
          ),
        ),
      ],
    );
  }
}

/// Location on the left, notifications on the right.
class _TopBar extends StatefulWidget {
  const _TopBar();

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  /// Where the traveller is, by name; null until known.
  String? _place;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    // Only reads it if already allowed: Explore does not ask on first open.
    _locate(ask: false);
  }

  Future<void> _locate({required bool ask}) async {
    final here = await currentLocation(ask: ask);
    if (!mounted) return;
    if (!here.ok) {
      setState(() => _denied = true);
      final problem = here.problem;
      if (ask && problem.needsSettings) {
        await openLocationSettings(problem);
      }
      return;
    }
    final name = await placeName(here.latitude!, here.longitude!);
    if (mounted) {
      setState(() {
        _place = name;
        _denied = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final unread = context.select<NotificationsProvider, int>((n) => n.unreadCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _place == null ? () => _locate(ask: true) : null,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: AppColors.violet, shape: BoxShape.circle),
                    child: const Icon(Icons.place_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.yourLocation, style: AppText.sans(11.5, color: AppColors.sand500)),
                        Text(
                          _place ?? (_denied ? s.allowLocationAccess : s.cambodia),
                          style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: AppColors.sand100,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(Routes.notificationsPage),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Badge(
                  isLabelVisible: unread > 0,
                  smallSize: 9,
                  backgroundColor: AppColors.sunset500,
                  child: const Icon(Icons.notifications_none_rounded, size: 22, color: AppColors.sand800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  /// The filter button skips the search screen: pick filters here, then land
  /// on the results.
  Future<void> _openFilters(BuildContext context) async {
    final picked = await showFilterSheet(context, const SearchFilters());
    if (picked == null || !context.mounted || picked.isEmpty) return;
    context.push(Routes.search, extra: picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1.5,
        shadowColor: const Color(0x221C1935),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(Routes.search),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 7, 7, 7),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppColors.violet),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.searchEverythingHint,
                    style: AppText.sans(14.5, color: AppColors.sand400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Material(
                  color: AppColors.violet,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openFilters(context),
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One circle per interest group, in the order of the design. The full names
/// run long, so the row scrolls sideways rather than squeezing them.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.groups});

  final List<InterestGroup> groups;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < groups.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == groups.length - 1 ? 0 : 10),
              child: SizedBox(
                width: 78,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(Routes.interest(groups[i].name)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        _GroupIcon(groups[i]),
                        const SizedBox(height: 7),
                        Text(
                          S.of(context).interestGroup(groups[i].name),
                          textAlign: TextAlign.center,
                          style: AppText.sans(11.5, weight: FontWeight.w500, color: AppColors.sand700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

class _GroupIcon extends StatelessWidget {
  const _GroupIcon(this.group);
  final InterestGroup group;

  @override
  Widget build(BuildContext context) {
    if (group.coverUrl.isNotEmpty) {
      return AppImage(group.coverUrl, width: 62, height: 62, radius: BorderRadius.circular(16));
    }
    final (icon, color) = groupStyle(group.name);
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onMore});
  final String title;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.sans(17, weight: FontWeight.w700, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Material(
            color: AppColors.violet,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onMore,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large photo card used for regions and corridors.
class _WideCard extends StatelessWidget {
  const _WideCard({
    required this.image,
    required this.title,
    required this.savedKind,
    required this.savedKey,
    required this.onTap,
    this.seal,
    this.averageRating,
    this.reviewCount = 0,
    this.scored = false,
  });

  final String image;
  final String title;

  /// "Recommend by AMS Travel" under the name, when the row carries the seal.
  final String? seal;

  /// The score under the name; null means nobody has rated it yet.
  final double? averageRating;
  final int reviewCount;

  /// Whether this kind of card carries a score at all. A region has none of
  /// its own, so its card leaves the line out.
  final bool scored;
  final SavedKind savedKind;
  final String savedKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 300,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(image),
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
                right: 10,
                top: 10,
                child: SaveButton(kind: savedKind, itemKey: savedKey, size: 38),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppText.sans(19, weight: FontWeight.w700, color: Colors.white, height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (seal != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 14, color: AppColors.sealOnPhoto),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              seal!,
                              style: AppText.sans(12, weight: FontWeight.w600, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (scored) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (averageRating != null) ...[
                            const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
                            const SizedBox(width: 4),
                            Text(
                              averageRating!.toStringAsFixed(1),
                              style: AppText.sans(13, weight: FontWeight.w700, color: Colors.white),
                            ),
                            if (reviewCount > 0) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '·  ${S.of(context).reviewCountText(reviewCount)}',
                                  style: AppText.sans(12.5, color: Colors.white70),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ] else
                            Text(S.of(context).noReviews, style: AppText.sans(12.5, color: Colors.white70)),
                        ],
                      ),
                    ],
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

/// A 152-wide card in a home row: photo with a heart, name, then the rating
/// or, without one, [fallback].
class _SmallCard extends StatelessWidget {
  const _SmallCard({
    required this.coverUrl,
    required this.name,
    required this.kind,
    required this.id,
    required this.onTap,
    required this.averageRating,
    required this.reviewCount,
    required this.fallback,
  });

  /// A place from `GET /popular`.
  _SmallCard.place(BuildContext context, PlaceCard card)
    : this(
        coverUrl: card.coverUrl,
        name: card.name,
        kind: SavedKind.destination,
        id: card.id,
        onTap: () => context.push(Routes.card(card)),
        averageRating: card.averageRating,
        reviewCount: card.reviewCount,
        // A place with no score says so, rather than dropping the line.
        fallback: S.read(context).noReviews,
      );

  /// A province; the card opens the list of what is in it.
  _SmallCard.province(BuildContext context, CatalogProvince province)
    : this(
        coverUrl: province.coverUrl,
        name: province.name,
        kind: SavedKind.province,
        id: province.id,
        onTap: () => context.push(Routes.provincePlaces(province.id)),
        averageRating: province.averageRating,
        reviewCount: province.reviewCount,
        fallback: S.read(context).placeCountText(province.placeCount),
      );

  final String coverUrl;
  final String name;
  final SavedKind kind;
  final String id;
  final VoidCallback onTap;
  final double? averageRating;
  final int reviewCount;
  final String? fallback;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final muted = AppText.sans(11.5, color: AppColors.sand500);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 152,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 126,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(coverUrl),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: SaveButton(kind: kind, itemKey: id, size: 32),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (averageRating != null)
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 15, color: AppColors.star),
                  const SizedBox(width: 3),
                  Text(
                    averageRating!.toStringAsFixed(1),
                    style: AppText.sans(12.5, weight: FontWeight.w700, color: AppColors.sand900),
                  ),
                  if (reviewCount > 0) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.reviewCountText(reviewCount),
                        style: muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              )
            else if (fallback != null)
              Text(fallback!, style: muted, maxLines: 1),
          ],
        ),
      ),
    );
  }
}
