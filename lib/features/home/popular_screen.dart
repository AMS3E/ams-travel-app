import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/async_view.dart';
import '../../widgets/browse_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/interest_filter.dart';
import '../../widgets/overview_card.dart';
import '../../widgets/place_list_row.dart';

/// The chips the page filters by: provinces and the six interest groups.
class _Chips {
  const _Chips(this.provinces, this.groups);
  final List<CatalogProvince> provinces;
  final List<InterestGroup> groups;
}

/// Everything under "Explore by Popular", in one list: `GET /popular` by
/// province and interest, then the cards for those ids.
class PopularScreen extends StatelessWidget {
  const PopularScreen({super.key});

  static Future<_Chips> _load(AmsApi api) async {
    final (provinces, groups) = await (api.provinces(), api.interestGroups()).wait;
    // Display order only.
    return _Chips([...provinces]..sort((a, b) => a.name.compareTo(b.name)), groups);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<_Chips>(
          load: () => _load(api),
          builder: (context, chips, _) => _Body(chips: chips),
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.chips});
  final _Chips chips;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// The province being looked at; null (no chip lit) is all of them. A
  /// lit chip tapped again goes back to all.
  String? _provinceId;

  /// The interest group being looked at. There is no "All" chip: the page
  /// opens on the first group (Attraction Sites).
  late int? _group = widget.chips.groups.isEmpty ? null : 0;

  /// Interests picked inside that group; empty is the whole group.
  final _picked = <String>{};

  /// The kind the chosen group stands for: Stays, Food and Tourism
  /// Corridors are their own kinds; every other group is attractions.
  CardType get _type => (_group == null ? null : widget.chips.groups[_group!].cardType) ?? CardType.destination;

  /// A kind group filters by kind alone, unless interests in it are picked;
  /// an attraction group sends its interests.
  List<String> get _interestIds =>
      _type == CardType.destination ? InterestFilter.idsFor(widget.chips.groups, _group, _picked) : _picked.toList();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final provinces = widget.chips.provinces;
    final interestIds = _interestIds;

    return Column(
      children: [
        BrowseSearchBar(hint: s.popularDestinations, onWhite: true),
        const SizedBox(height: 12),

        // Where to look…
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: provinces.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = provinces[i];
              return _Chip(
                label: p.name,
                icon: Icons.temple_buddhist_outlined,
                selected: _provinceId == p.id,
                onTap: () => setState(() => _provinceId = _provinceId == p.id ? null : p.id),
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Divider(height: 1, color: AppColors.sand200),
        ),

        // …and what to look for: the kind chips are `type`, the interests
        // `interestIds`.
        InterestFilter(
          groups: widget.chips.groups,
          index: _group,
          showAll: false,
          onIndex: (i) => setState(() {
            _group = i;
            _picked.clear();
          }),
          picked: _picked,
          onPicked: (id) => setState(() => _picked.contains(id) ? _picked.remove(id) : _picked.add(id)),
        ),
        const SizedBox(height: 14),

        Expanded(
          child: AsyncView<List<PlaceCard>>(
            key: ValueKey('$_provinceId|${_type.code}|${interestIds.join(',')}'),
            load: () => context.read<AmsApi>().popular(
              type: _type,
              provinceIds: [?_provinceId],
              interestIds: interestIds,
              limit: 50,
            ),
            builder: (context, places, _) {
              // The server fills the list up to the limit, so it is only
              // empty when nothing at all matches the chips.
              if (places.isEmpty) {
                return SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.local_fire_department_outlined,
                    title: s.popularEmptyTitle,
                    body: s.popularEmptyBody,
                  ),
                );
              }
              return ListView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + MediaQuery.paddingOf(context).bottom),
                children: [
                  GradientFrame(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: Column(children: [for (final c in places) PlaceListRow(card: c)]),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A province chip, with its symbol: the gradient border of the cards
/// until picked, then solid violet.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = selected ? Colors.white : AppColors.violet;
    return GradientFrame(
      radius: 99,
      expand: false,
      padding: EdgeInsets.zero,
      color: selected ? AppColors.violet : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        // Its words in the middle of the row's height.
        child: Center(
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: colour),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppText.sans(13, weight: FontWeight.w500, color: colour),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
