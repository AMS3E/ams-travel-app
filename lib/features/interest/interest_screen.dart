import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/geo.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/place_list_row.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/corridor_row.dart';
import '../../widgets/interest_filter.dart';
import '../../widgets/overview_card.dart';
import '../destination/place_view.dart' show LazySection;
import 'browse_helpers.dart';

/// One interest group followed across the country: the groups in one row,
/// the interests of the chosen one in a second, and the places the server
/// finds for them in two columns (`GET /interests`, `GET /search?interestIds=&type=`).
/// The Tourism Corridors group lists corridors instead.
class InterestScreen extends StatelessWidget {
  const InterestScreen({super.key, required this.group});

  /// The group the page opens on, as its slugified name ("attraction-sites").
  final String group;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<List<InterestGroup>>(
          load: api.interestGroups,
          builder: (context, groups, _) {
            final at = groups.indexWhere((g) => slugify(g.name) == group);
            return InterestBrowser(groups: groups, initialIndex: at < 0 ? 0 : at);
          },
        ),
      ),
    );
  }
}

/// The body of the interest pages: the two chip rows and the server's
/// answer for them.
class InterestBrowser extends StatefulWidget {
  const InterestBrowser({super.key, required this.groups, required this.initialIndex, this.hint});

  final List<InterestGroup> groups;
  final int initialIndex;

  /// The search bar's words; by default "Search" and the group's name.
  final String? hint;

  @override
  State<InterestBrowser> createState() => _InterestBrowserState();
}

class _InterestBrowserState extends State<InterestBrowser> {
  late int _index = widget.initialIndex;

  /// Interest ids picked in the second row. Empty means the whole group.
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    final s = S.of(context);
    final groups = widget.groups;
    if (groups.isEmpty) {
      return EmptyState(icon: Icons.search_off_rounded, title: s.noResults, body: s.noResultsBody);
    }
    final group = groups[_index];
    final type = group.cardType;
    final ids = InterestFilter.idsFor(groups, _index, _picked);
    final bottom = 24 + MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        BrowseSearchBar(hint: widget.hint ?? '${s.searchIn} ${s.interestGroup(group.name).toLowerCase()}'),
        const SizedBox(height: 12),
        InterestFilter(
          groups: groups,
          index: _index,
          onIndex: (i) => setState(() {
            _index = i ?? 0;
            _picked.clear();
          }),
          picked: _picked,
          onPicked: (id) => setState(() => _picked.remove(id) ? null : _picked.add(id)),
          showAll: false,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PagedCards(
            key: ValueKey('${type?.code}|${(ids.toList()..sort()).join(',')}'),
            load: (page) => api.search(interestIds: ids, type: type, page: page),
            empty: EmptyState(icon: Icons.search_off_rounded, title: s.noResults, body: s.noResultsBody),
            builder: (context, cards, _, more) => ListView(
              padding: EdgeInsets.only(bottom: bottom),
              children: [
                _Outline(
                  child: type == CardType.corridor
                      // Corridors are routes, not places: one row each.
                      ? Column(
                          children: [
                            for (final c in cards) CorridorRow(corridor: c),
                            ?more,
                          ],
                        )
                      : Column(
                          children: [
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 14,
                                mainAxisExtent: 66,
                              ),
                              itemCount: cards.length,
                              itemBuilder: (_, i) => PlaceTile(card: cards[i]),
                            ),
                            ?more,
                          ],
                        ),
                ),
                // The Traveler seal holders of these interests; hidden while
                // no place has the seal.
                if (type == null || type == CardType.destination)
                  _RecommendPanel(key: ValueKey(ids.join(',')), interestIds: ids),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Recommend by Traveler": `GET /search?interestIds=&travelerRecommended=true&size=5`,
/// shown only when the server has some.
class _RecommendPanel extends StatelessWidget {
  const _RecommendPanel({super.key, required this.interestIds});
  final List<String> interestIds;

  @override
  Widget build(BuildContext context) {
    return LazySection<PageOf<PlaceCard>>(
      load: () => context.read<AmsApi>().search(interestIds: interestIds, travelerRecommended: true, size: 5),
      builder: (context, page) {
        if (page.content.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: BrowsePanel(
            title: S.of(context).recommendByTraveler,
            child: Column(children: [for (final c in page.content) PlaceListRow(card: c)]),
          ),
        );
      },
    );
  }
}

/// The card the list sits in, places or corridors: the orange-to-violet
/// border of the place pages' cards.
class _Outline extends StatelessWidget {
  const _Outline({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GradientFrame(padding: const EdgeInsets.fromLTRB(12, 14, 12, 14), child: child),
    );
  }
}
