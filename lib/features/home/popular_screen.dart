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
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/interest_card.dart';

const _violet = Color(0xFF5B2EE5);

/// Everything under "Explore by Popular", province by province, with the
/// interest categories along the top.
class PopularScreen extends StatelessWidget {
  const PopularScreen({super.key});

  Future<(List<Province>, List<Destination>, List<Interest>)> _load(TravelRepository repo) async {
    final (provinces, places, interests) = await (
      repo.getProvinces(),
      repo.getDestinations(),
      repo.getInterests(),
    ).wait;

    places.sort((a, b) {
      final byFeatured = (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
      if (byFeatured != 0) return byFeatured;
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      return byRating != 0 ? byRating : (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
    });

    // Corridors are not places, so they have no category to filter by.
    return (provinces, places, interests.where((i) => i.categories.isNotEmpty).toList());
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<(List<Province>, List<Destination>, List<Interest>)>(
          load: () => _load(repo),
          builder: (context, data, _) {
            final (provinces, places, interests) = data;
            return _Body(provinces: provinces, places: places, interests: interests);
          },
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.provinces, required this.places, required this.interests});
  final List<Province> provinces;

  /// Every place, the best known first.
  final List<Destination> places;
  final List<Interest> interests;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// The interest being looked at, or null for everything.
  Interest? _interest;

  /// Every province, or only the ones with a few places worth seeing.
  bool _allProvinces = false;

  /// Provinces and their places, the fullest first.
  List<(Province, List<Destination>)> get _groups {
    final categories = _interest?.categories.toSet();
    final byProvince = <String, List<Destination>>{};
    for (final d in widget.places) {
      if (categories != null && !categories.contains(d.category)) continue;
      if (!_allProvinces && !d.featured && (d.rating ?? 0) < 4.6) continue;
      (byProvince[d.province] ??= []).add(d);
    }
    // With a category chosen there is less to go round, so one place is enough.
    final least = _interest == null ? 3 : 1;
    final groups = <(Province, List<Destination>)>[
      for (final p in widget.provinces)
        if (_allProvinces || (byProvince[p.name] ?? const []).length >= least)
          (p, byProvince[p.name] ?? const []),
    ];
    if (_allProvinces) return groups;
    return groups..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final groups = _groups;

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
            itemBuilder: (_, i) {
              final interest = widget.interests[i];
              return _CategoryChip(
                interest: interest,
                selected: interest.slug == _interest?.slug,
                onTap: () => setState(() => _interest = interest.slug == _interest?.slug ? null : interest),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: Text(s.noResults, style: AppText.sans(14.5, color: AppColors.sand500)),
                )
              : ListView(
                  padding: EdgeInsets.only(bottom: 20 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    for (final (province, places) in groups)
                      _ProvinceGroup(province: province, places: places),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: OutlinedButton(
                        onPressed: () => setState(() => _allProvinces = !_allProvinces),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: _violet),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          _allProvinces
                              ? s.showLess
                              : s.showAllProvinces.replaceFirst('{n}', '${widget.provinces.length}'),
                          style: AppText.sans(14.5, weight: FontWeight.w700, color: _violet),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 1.5,
              shadowColor: const Color(0x221C1935),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push(Routes.popularSearch),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 5, 5, 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.popularDestinations,
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

/// One interest category, filtering the provinces below.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.interest, required this.selected, required this.onTap});
  final Interest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, colour) = interestStyle(interest);
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? _violet : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? _violet : AppColors.sand200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : colour),
            const SizedBox(width: 6),
            Text(
              bilingual(context, interest.name, interest.nameKh).$1,
              style: AppText.sans(
                13,
                weight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.sand800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One province: its name, a way into the province page, and its places.
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
          if (places.isEmpty)
            Text(S.of(context).notListedYet, style: AppText.sans(13, color: AppColors.sand500))
          else
            SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 14),
                itemCount: places.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _PlaceCard(destination: places[i]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Photo, name, stars and how many people have reviewed the place.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.destination});
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
              child: AppImage(d.image, radius: BorderRadius.circular(14)),
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
