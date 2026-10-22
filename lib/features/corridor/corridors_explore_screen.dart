import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/corridor_row.dart';
import '../interest/browse_helpers.dart';

/// The tourism corridors (`GET /search?type=CORRIDOR`).
class CorridorsExploreScreen extends StatelessWidget {
  const CorridorsExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    final s = S.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BrowseSearchBar(hint: s.exploreCorridors),
            const SizedBox(height: 14),
            Expanded(
              child: PagedCards(
                load: (page) => api.search(type: CardType.corridor, page: page),
                empty: EmptyState(icon: Icons.route_rounded, title: s.noResults, body: s.noResultsBody),
                builder: (context, corridors, _, more) => ListView(
                  padding: EdgeInsets.only(bottom: 20 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    BrowsePanel(
                      title: s.tourismCorridors,
                      child: Column(
                        children: [
                          for (final c in corridors) CorridorRow(corridor: c),
                          ?more,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
