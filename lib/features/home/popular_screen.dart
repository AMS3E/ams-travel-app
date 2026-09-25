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
import '../../widgets/destination_card.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/place_group.dart';


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
  /// Provinces and their places, the fullest first.
  List<(Province, List<Destination>)> get _groups {
    final byProvince = <String, List<Destination>>{};
    for (final d in widget.places) {
      if (!d.featured && (d.rating ?? 0) < 4.6) continue;
      (byProvince[d.province] ??= []).add(d);
    }
    return <(Province, List<Destination>)>[
      for (final p in widget.provinces)
        if ((byProvince[p.name] ?? const []).length >= 3) (p, byProvince[p.name]!),
    ]..sort((a, b) => b.$2.length.compareTo(a.$2.length));
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
        BrowseSearchBar(hint: s.popularDestinations, onWhite: true),
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
                      PlaceGroup(
                  title: bilingual(context, province.name, province.nameKh).$1,
                  route: Routes.province(province.slug),
                  places: places,
                ),
                  ],
                ),
        ),
      ],
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
