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


/// Provinces and what to see in them, one interest at a time.
class ProvincesExploreScreen extends StatelessWidget {
  const ProvincesExploreScreen({super.key});

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

    // Corridors run across provinces, so they are not one of the chips here.
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
  int _index = 0;

  /// Every province, or only the ones with a few places worth seeing.
  bool _all = false;

  List<(Province, List<Destination>)> get _groups {
    final categories = widget.interests.isEmpty
        ? null
        : widget.interests[_index].categories.toSet();

    final byProvince = <String, List<Destination>>{};
    for (final d in widget.places) {
      if (categories != null && !categories.contains(d.category)) continue;
      (byProvince[d.province] ??= []).add(d);
    }
    final groups = <(Province, List<Destination>)>[
      for (final p in widget.provinces)
        if (_all || (byProvince[p.name] ?? const []).isNotEmpty) (p, byProvince[p.name] ?? const []),
    ];
    // All 25 stay in their own order; otherwise the fullest come first.
    if (_all) return groups;
    return groups..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final groups = _groups;

    return Column(
      children: [
        BrowseSearchBar(hint: s.popularProvinces),
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
              for (final (province, places) in groups)
                PlaceGroup(
                  title: bilingual(context, province.name, province.nameKh).$1,
                  route: Routes.province(province.slug),
                  places: places,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: OutlinedButton(
                  onPressed: () => setState(() => _all = !_all),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: AppColors.violet),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _all
                        ? s.showLess
                        : s.showAllProvinces.replaceFirst('{n}', '${widget.provinces.length}'),
                    style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.violet),
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
