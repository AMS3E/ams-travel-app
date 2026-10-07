import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/destination_card.dart';
import '../../widgets/place_group.dart';

/// The nine tourism regions, each with the places it is known for.
class RegionsExploreScreen extends StatelessWidget {
  const RegionsExploreScreen({super.key});

  Future<(List<Region>, List<Destination>)> _load(TravelRepository repo) async {
    final (regions, places) = await (repo.getRegions(), repo.getDestinations()).wait;

    places.sort((a, b) {
      final byFeatured = (b.featured ? 1 : 0).compareTo(a.featured ? 1 : 0);
      if (byFeatured != 0) return byFeatured;
      final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
      return byRating != 0 ? byRating : (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
    });

    return (regions, places);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TravelRepository>();
    final s = S.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<(List<Region>, List<Destination>)>(
          load: () => _load(repo),
          builder: (context, data, _) {
            final (regions, places) = data;
            final byRegion = <String, List<Destination>>{};
            for (final d in places) {
              (byRegion[d.region] ??= []).add(d);
            }

            return Column(
              children: [
                BrowseSearchBar(hint: s.exploreRegions),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(bottom: 20 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      for (final r in regions)
                        if ((byRegion[r.slug] ?? const []).isNotEmpty)
                          PlaceGroup(
                            title: bilingual(context, r.name, r.nameKh).$1,
                            route: Routes.region(r.slug),
                            places: byRegion[r.slug]!.take(8).toList(),
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
