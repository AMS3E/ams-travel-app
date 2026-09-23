import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';
import '../search/filter_sheet.dart';

const _violet = Color(0xFF5B2EE5);

class _HomeData {
  _HomeData({
    required this.regions,
    required this.provinces,
    required this.corridors,
    required this.interests,
    required this.places,
    required this.popular,
  });

  final List<Region> regions;
  final List<Province> provinces;
  final List<Corridor> corridors;
  final List<Interest> interests;
  final List<Destination> places;

  /// What to show under "Explore by Popular", grouped by province: the
  /// provinces with the most popular places, each with its own places.
  final List<(Province, List<Destination>)> popular;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.pickedCategories = const <String>{}});

  /// Categories from the interests chosen during onboarding; they move the
  /// matching places to the front of "Popular".
  final Set<String> pickedCategories;

  Future<_HomeData> _load(TravelRepository repo) async {
    final (regions, provinces, corridors, interests, places) = await (
      repo.getRegions(),
      repo.getProvinces(),
      repo.getCorridors(),
      repo.getInterests(),
      repo.getDestinations(),
    ).wait;

    final popular = places.where((d) => d.featured || (d.rating ?? 0) >= 4.6).toList()
      ..sort((a, b) {
        final mine = pickedCategories.contains(a.category) ? 1 : 0;
        final theirs = pickedCategories.contains(b.category) ? 1 : 0;
        final byInterest = theirs.compareTo(mine);
        return byInterest != 0 ? byInterest : (b.rating ?? 0).compareTo(a.rating ?? 0);
      });

    // One block per province, the provinces with the most to see first.
    final byProvince = <String, List<Destination>>{};
    for (final d in popular) {
      (byProvince[d.province] ??= []).add(d);
    }
    final groups = <(Province, List<Destination>)>[
      for (final p in provinces)
        if ((byProvince[p.name] ?? const []).length >= 3) (p, byProvince[p.name]!),
    ]..sort((a, b) => b.$2.length.compareTo(a.$2.length));

    return _HomeData(
      regions: regions,
      provinces: provinces,
      corridors: corridors,
      interests: interests,
      places: places,
      popular: [for (final (p, list) in groups.take(4)) (p, list.take(8).toList())],
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: AsyncView<_HomeData>(
            load: () => _load(repo),
            builder: (context, data, reload) => RefreshIndicator(
              onRefresh: reload,
              color: _violet,
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

  /// Average rating of a region's places, and how many it holds.
  (double?, int) _regionStats(String slug) {
    final places = data.places.where((d) => d.region == slug).toList();
    final rated = places.where((d) => d.rating != null).toList();
    final average = rated.isEmpty ? null : rated.map((d) => d.rating!).reduce((a, b) => a + b) / rated.length;
    return (average, places.length);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return ListView(
      padding: EdgeInsets.only(bottom: 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        const _TopBar(),
        const SizedBox(height: 14),
        const _SearchBar(),
        const SizedBox(height: 18),
        const _QuickActions(),
        const SizedBox(height: 22),

        // Tourism regions
        _SectionHeader(title: s.exploreByRegion, onMore: () => context.go(Routes.explore)),
        SizedBox(
          height: 212,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.regions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final r = data.regions[i];
              final (rating, count) = _regionStats(r.slug);
              return _WideCard(
                image: r.image,
                title: bilingual(context, r.name, r.nameKh).$1,
                rating: rating,
                count: count,
                savedKind: SavedKind.region,
                savedKey: r.slug,
                onTap: () => context.push(Routes.region(r.slug)),
              );
            },
          ),
        ),
        const SizedBox(height: 22),

        // Popular places, a block per province
        _SectionHeader(title: s.exploreByPopular, onMore: () => context.go(Routes.exploreTab('provinces'))),
        for (final (province, places) in data.popular)
          _ProvinceGroup(province: province, places: places),
        const SizedBox(height: 22),

        // Corridors
        _SectionHeader(title: s.exploreByCorridors, onMore: () => context.go(Routes.exploreTab('corridors'))),
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
                image: c.image,
                title: c.name,
                caption: '${c.duration}  ·  ${c.stops.length} ${s.stops.toLowerCase()}',
                savedKind: SavedKind.corridor,
                savedKey: c.slug,
                onTap: () => context.push(Routes.corridor(c.slug)),
              );
            },
          ),
        ),
        const SizedBox(height: 22),

        // Interests
        _SectionHeader(title: s.exploreByInterest, onMore: () => context.push(Routes.allInterests)),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.interests.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _InterestTile(interest: data.interests[i]),
          ),
        ),
        const SizedBox(height: 22),

        // Provinces
        _SectionHeader(title: s.exploreByProvinces, onMore: () => context.go(Routes.exploreTab('provinces'))),
        SizedBox(
          height: 234,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.provinces.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final p = data.provinces[i];
              // Until the API rates provinces, the card averages the places
              // inside the province.
              final inProvince = data.places.where((d) => slugify(d.province) == p.slug).toList();
              final rated = inProvince.where((d) => d.rating != null).toList();
              return _ProvinceCard(
                province: p,
                count: inProvince.length,
                rating: rated.isEmpty ? null : rated.map((d) => d.rating!).reduce((a, b) => a + b) / rated.length,
                reviewCount: rated.fold<int>(0, (sum, d) => sum + (d.reviewCount ?? 0)),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Location on the left, notifications on the right.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: _violet, shape: BoxShape.circle),
            child: const Icon(Icons.place_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.yourLocation, style: AppText.sans(11.5, color: AppColors.sand500)),
                Text(
                  'Phnom Penh, Cambodia',
                  style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.sand100,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => showToast(context, s.noNotifications),
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: Icon(Icons.notifications_none_rounded, size: 22, color: AppColors.sand800),
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
                const Icon(Icons.search_rounded, color: AppColors.sand400),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.searchEverythingHint,
                    style: AppText.sans(14.5, color: AppColors.sand400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Material(
                  color: _violet,
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

/// Hotel · Restaurant · Tour · Tour Guide · More
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final actions = <(IconData, String, VoidCallback)>[
      (Icons.hotel_rounded, s.quickHotel, () => context.push(Routes.interest('stays'))),
      (Icons.restaurant_rounded, s.quickRestaurant, () => context.push(Routes.interest('food'))),
      (Icons.tour_rounded, s.quickTour, () => context.go(Routes.exploreTab('corridors'))),
      (Icons.support_agent_rounded, s.quickTourGuide, () => context.push('${Routes.search}?q=guide')),
      (Icons.grid_view_rounded, s.quickMore, () => context.go(Routes.explore)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final (icon, label, onTap) in actions)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(color: _violet, shape: BoxShape.circle),
                        child: Icon(icon, color: Colors.white, size: 25),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        label,
                        style: AppText.sans(11.5, weight: FontWeight.w500, color: AppColors.sand700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
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
            color: _violet,
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
    this.rating,
    this.count,
    this.caption,
  });

  final String image;
  final String title;
  final SavedKind savedKind;
  final String savedKey;
  final VoidCallback onTap;
  final double? rating;
  final int? count;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
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
                child: SaveButton(kind: savedKind, itemKey: savedKey, dark: true, size: 38),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: caption != null
                              ? Text(
                                  caption!,
                                  style: AppText.sans(12.5, color: Colors.white.withValues(alpha: 0.85)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Row(
                                  children: [
                                    const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF34D399)),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        s.recommendByTraveler,
                                        style: AppText.sans(12.5, color: Colors.white.withValues(alpha: 0.85)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        if (rating != null) _RatingPill(rating: rating!, count: count),
                      ],
                    ),
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

/// Amber star pill on a photo.
class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating, this.count});
  final double rating;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1206),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.star.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
          const SizedBox(width: 3),
          Text(
            count == null ? rating.toStringAsFixed(1) : '${rating.toStringAsFixed(1)} ($count)',
            style: AppText.sans(12, weight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// One province under "Explore by Popular": the name, a way into the province
/// page, and the places inside it.
class _ProvinceGroup extends StatelessWidget {
  const _ProvinceGroup({required this.province, required this.places});
  final Province province;
  final List<Destination> places;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    bilingual(context, province.name, province.nameKh).$1,
                    style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Material(
                  color: _violet,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => context.push(Routes.province(province.slug)),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 14),
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _SmallCard(destination: places[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small photo card for the popular places: photo, name, stars and how many
/// people have reviewed it.
class _SmallCard extends StatelessWidget {
  const _SmallCard({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: SizedBox(
        width: 146,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 112,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(d.image),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: SaveButton(kind: SavedKind.destination, itemKey: d.key, dark: true, size: 30),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            if (d.rating != null)
              Row(
                children: [
                  Stars(d.rating!.round(), size: 11),
                  if (d.reviewCount != null) ...[
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${thousands(d.reviewCount!)} ${s.reviewsWord.toLowerCase()}',
                        style: AppText.sans(10.5, color: AppColors.sand500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Square photo tile with the interest name underneath.
class _InterestTile extends StatelessWidget {
  const _InterestTile({required this.interest});
  final Interest interest;

  @override
  Widget build(BuildContext context) {
    final (title, _) = bilingual(context, interest.name, interest.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.interest(interest.slug)),
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            SizedBox(
              height: 88,
              width: 92,
              child: AppImage(interest.image, radius: BorderRadius.circular(18)),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.sans(11.5, weight: FontWeight.w600, color: AppColors.sand800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// White card in a peach-to-violet outline holding the province artwork, with
/// a heart on the image and the name + rating underneath.
class _ProvinceCard extends StatelessWidget {
  const _ProvinceCard({required this.province, required this.count, this.rating, this.reviewCount});
  final Province province;

  /// Places in this province — the second line when there is no rating yet.
  final int count;
  final double? rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (title, _) = bilingual(context, province.name, province.nameKh);
    final score = province.rating ?? rating;
    return GestureDetector(
      onTap: () => context.push(Routes.province(province.slug)),
      child: SizedBox(
        width: 168,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 168,
              width: double.infinity,
              child: Stack(
                // Without this the stack shrinks to the photo's own size and
                // leaves the rest of the card blank.
                fit: StackFit.expand,
                children: [
                  AppImage(province.image, radius: BorderRadius.circular(20)),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: SaveButton(kind: SavedKind.province, itemKey: province.slug, size: 30),
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
            if (score != null)
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 15, color: AppColors.star),
                  const SizedBox(width: 3),
                  Text(
                    score.toStringAsFixed(1),
                    style: AppText.sans(12.5, weight: FontWeight.w600, color: AppColors.sand900),
                  ),
                  if (reviewCount != null && reviewCount! > 0)
                    Text(' (${thousands(reviewCount!)})', style: AppText.sans(12.5, color: AppColors.sand500)),
                ],
              )
            else
              // No rating for this province yet — see the model's note.
              Text('$count ${s.places.toLowerCase()}', style: AppText.sans(12.5, color: AppColors.sand500)),
          ],
        ),
      ),
    );
  }
}
