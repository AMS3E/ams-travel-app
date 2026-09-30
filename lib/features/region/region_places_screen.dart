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

/// Every place in one region, as a list.
class RegionPlacesScreen extends StatelessWidget {
  const RegionPlacesScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    final s = S.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<(Region, List<Destination>)>(
          load: () => (repo.getRegion(slug), repo.getDestinations(region: slug)).wait,
          builder: (context, data, _) {
            final (region, places) = data;
            return Column(
              children: [
                BrowseSearchBar(hint: s.searchRegion),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
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
                              bilingual(context, region.name, region.nameKh).$1,
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
          },
        ),
      ),
    );
  }
}
