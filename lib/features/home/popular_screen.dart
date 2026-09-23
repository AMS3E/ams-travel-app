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

const _violet = Color(0xFF5B2EE5);

/// Everything under "Explore by Popular", province by province.
class PopularScreen extends StatelessWidget {
  const PopularScreen({super.key});

  Future<(List<Province>, List<Destination>)> _load(TravelRepository repo) async {
    final (provinces, places) = await (repo.getProvinces(), repo.getDestinations()).wait;

    places.sort((a, b) {
      final byFeatured = (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
      if (byFeatured != 0) return byFeatured;
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      return byRating != 0 ? byRating : (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
    });

    return (provinces, places);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<(List<Province>, List<Destination>)>(
          load: () => _load(repo),
          builder: (context, data, _) {
            final (provinces, places) = data;
            return _Body(provinces: provinces, places: places);
          },
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.provinces, required this.places});
  final List<Province> provinces;

  /// Every place, the best known first.
  final List<Destination> places;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// Every province, or only the ones with a few places worth seeing.
  bool _allProvinces = false;

  /// Provinces and their places, the fullest first.
  List<(Province, List<Destination>)> get _groups {
    final byProvince = <String, List<Destination>>{};
    for (final d in widget.places) {
      if (!_allProvinces && !d.featured && (d.rating ?? 0) < 4.6) continue;
      (byProvince[d.province] ??= []).add(d);
    }
    final groups = <(Province, List<Destination>)>[
      for (final p in widget.provinces)
        if (_allProvinces || (byProvince[p.name] ?? const []).length >= 3)
          (p, byProvince[p.name] ?? const []),
    ];
    if (_allProvinces) return groups;
    return groups..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final groups = _groups;
    // The chips suggest what other people look for: the best known places,
    // then the provinces they sit in.
    final keywords = <String>{
      for (final (_, places) in groups.take(2)) ...places.take(2).map((d) => d.name),
      for (final (province, _) in groups.take(3)) province.name,
    }.take(6).toList();

    return Column(
      children: [
        const _SearchRow(),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: keywords.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _Keyword(word: keywords[i]),
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

/// One thing other people search for.
class _Keyword extends StatelessWidget {
  const _Keyword({required this.word});
  final String word;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: () => context.push('${Routes.search}?q=${Uri.encodeQueryComponent(word)}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 15, color: AppColors.sand500),
            const SizedBox(width: 5),
            Text(
              word.toLowerCase(),
              style: AppText.sans(13, weight: FontWeight.w500, color: AppColors.sand800),
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
