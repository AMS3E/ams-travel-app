import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/destination_card.dart';

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
                            for (final d in places) _PlaceRow(destination: d),
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

/// One place: photo, name, what it is known for, and who recommends it.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    // What the place is known for: its facts if the data has them, else what
    // kind of place it is.
    final detail = d.facets.isEmpty ? d.category : d.facets.values.join(', ');

    return InkWell(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 54, height: 54, child: AppImage(d.image, radius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: AppText.sans(11, color: AppColors.sand500, height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF34D399)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          // The app puts its own name to the places it picks out.
                          d.featured ? s.recommendByAms : s.recommendByTraveler,
                          style: AppText.sans(10.5, color: AppColors.sand500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
