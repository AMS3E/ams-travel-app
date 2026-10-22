import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/interest_filter.dart';
import '../../widgets/place_group.dart';

/// Provinces and what to see in them, one interest at a time: the whole page
/// in one `GET /search/by-province?interestIds=&type=&perProvince=8`.
class ProvincesExploreScreen extends StatelessWidget {
  const ProvincesExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<List<InterestGroup>>(
          load: api.interestGroups,
          builder: (context, groups, _) => _Body(groups: groups),
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.groups});
  final List<InterestGroup> groups;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// How many provinces show before "Show all".
  static const _first = 8;

  /// Which group is chosen; null is "All".
  int? _index;

  /// Interest ids picked in the second row.
  final _picked = <String>{};

  /// Every province, or the first few.
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final groups = widget.groups;
    final ids = InterestFilter.idsFor(groups, _index, _picked);
    final type = _index == null ? null : groups[_index!].cardType;
    final filter = '${type?.code}|${(ids.toList()..sort()).join(',')}';

    return Column(
      children: [
        BrowseSearchBar(hint: s.searchProvince),
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
          child: AsyncView<List<ProvinceGroup>>(
            key: ValueKey(filter),
            load: () => context.read<AmsApi>().searchByProvince(interestIds: ids, type: type, perProvince: 8),
            builder: (context, all, _) {
              if (all.isEmpty) {
                return SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.travel_explore_rounded,
                    title: s.searchNoMatches,
                    body: s.searchNoMatchesBody,
                  ),
                );
              }
              final rows = _all ? all : all.take(_first).toList();
              return ListView.builder(
                padding: EdgeInsets.only(bottom: 20 + MediaQuery.paddingOf(context).bottom),
                itemCount: rows.length + (all.length > _first ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i < rows.length) {
                    final g = rows[i];
                    return PlaceGroup(
                      title: g.provinceName,
                      route: Routes.provincePlaces(g.provinceId),
                      places: g.content,
                      showHeart: true,
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _all = !_all),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: AppColors.violet),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _all ? s.showLess : s.fill(s.showAllProvinces, {'n': all.length}),
                        style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.violet),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
