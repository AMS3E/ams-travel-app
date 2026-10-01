import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/place_list_row.dart';

/// Everything in one province, a category at a time.
class ProvincePlacesScreen extends StatelessWidget {
  const ProvincePlacesScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<(Province, List<Destination>, List<Interest>)>(
          load: () async {
            final (province, places, interests) = await (
              repo.getProvince(slug),
              repo.getDestinations(province: slug),
              repo.getInterests(),
            ).wait;
            places.sort((a, b) {
              final byFeatured = (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
              if (byFeatured != 0) return byFeatured;
              return (b.rating ?? 0).compareTo(a.rating ?? 0);
            });
            // Corridors run across provinces, so they are not a chip here.
            return (province, places, interests.where((i) => i.categories.isNotEmpty).toList());
          },
          builder: (context, data, _) {
            final (province, places, interests) = data;
            return _Body(province: province, places: places, interests: interests);
          },
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.province, required this.places, required this.interests});
  final Province province;
  final List<Destination> places;
  final List<Interest> interests;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// Which category is being looked at; null is "All".
  int? _index;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = bilingual(context, widget.province.name, widget.province.nameKh).$1;
    final categories = _index == null ? null : widget.interests[_index!].categories.toSet();
    final places = categories == null
        ? widget.places
        : widget.places.where((d) => categories.contains(d.category)).toList();

    return Column(
      children: [
        BrowseSearchBar(hint: '${s.exploreMoreIn} $name'),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.interests.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => i == 0
                ? CategoryChip(
                    label: s.all,
                    selected: _index == null,
                    onTap: () => setState(() => _index = null),
                  )
                : CategoryChip(
                    label: shortInterestName(s, widget.interests[i - 1]),
                    selected: _index == i - 1,
                    onTap: () => setState(() => _index = i - 1),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: places.isEmpty
              ? Center(child: Text(s.noResults, style: AppText.sans(14.5, color: AppColors.sand500)))
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.sand200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                          ),
                          const SizedBox(height: 6),
                          for (final d in places) PlaceListRow(destination: d),
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
