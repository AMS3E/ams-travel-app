import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/interest_filter.dart';
import '../../widgets/place_list_row.dart';
import '../interest/browse_helpers.dart';

/// Everything in one province, a kind and an interest at a time
/// (`GET /search?provinceId=&interestIds=&type=`).
class ProvincePlacesScreen extends StatelessWidget {
  const ProvincePlacesScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<(CatalogProvince, List<InterestGroup>)>(
          load: () => (api.province(id), api.interestGroups()).wait,
          builder: (context, data, _) => _Body(province: data.$1, groups: data.$2),
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.province, required this.groups});
  final CatalogProvince province;
  final List<InterestGroup> groups;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// Which group is chosen; null is "All".
  int? _index;

  /// Interest ids picked in the second row.
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    final s = S.of(context);
    final groups = widget.groups;
    final name = widget.province.name;
    final ids = InterestFilter.idsFor(groups, _index, _picked);
    final type = _index == null ? null : groups[_index!].cardType;

    return Column(
      children: [
        BrowseSearchBar(hint: '${s.exploreMoreIn} $name'),
        const SizedBox(height: 12),
        InterestFilter(
          groups: groups,
          index: _index,
          onIndex: (i) => setState(() {
            _index = i;
            _picked.clear();
          }),
          picked: _picked,
          onPicked: (id) => setState(() => _picked.remove(id) ? null : _picked.add(id)),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: PagedCards(
            key: ValueKey('${type?.code}|${(ids.toList()..sort()).join(',')}'),
            load: (page) => api.search(provinceId: widget.province.id, interestIds: ids, type: type, page: page),
            empty: EmptyState(icon: Icons.search_off_rounded, title: s.noResults, body: s.noResultsBody),
            builder: (context, cards, _, more) => ListView(
              padding: EdgeInsets.only(bottom: 20 + MediaQuery.paddingOf(context).bottom),
              children: [
                BrowsePanel(
                  title: name,
                  child: Column(
                    children: [
                      for (final c in cards) PlaceListRow(card: c),
                      ?more,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
