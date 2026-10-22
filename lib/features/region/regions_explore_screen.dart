import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/place_group.dart';

/// The tourism regions, each with three of its places
/// (`GET /regions?kind=TOURISM`, then `GET /search?regionId=&size=3` each).
class RegionsExploreScreen extends StatelessWidget {
  const RegionsExploreScreen({super.key});

  static Future<List<(CatalogRegion, List<PlaceCard>)>> load(AmsApi api) async {
    final regions = await api.tourismRegions();
    final pages = await Future.wait([for (final r in regions) api.search(regionId: r.id, size: 3)]);
    return [for (var i = 0; i < regions.length; i++) (regions[i], pages[i].content)];
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    final s = S.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BrowseSearchBar(hint: s.exploreRegions),
            const SizedBox(height: 14),
            Expanded(
              child: AsyncView<List<(CatalogRegion, List<PlaceCard>)>>(
                load: () => load(api),
                builder: (context, regions, reload) => RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    padding: EdgeInsets.only(bottom: 20 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      for (final (region, places) in regions)
                        // A region with nothing published yet has no row to show.
                        if (places.isNotEmpty)
                          PlaceGroup(title: region.name, route: Routes.region(region.id), places: places),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
