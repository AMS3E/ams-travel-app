import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../data/api/catalog.dart';
import 'browse_bar.dart';

/// The filter every browse page wears: the six interest groups in one row,
/// and the interests of the chosen group in a second row underneath. The
/// page sends the result to the server with [InterestFilter.idsFor].
class InterestFilter extends StatefulWidget {
  const InterestFilter({
    super.key,
    required this.groups,
    required this.index,
    required this.onIndex,
    required this.picked,
    required this.onPicked,
    this.showAll = true,
  });

  final List<InterestGroup> groups;

  /// Which group is chosen, or null for "All".
  final int? index;
  final ValueChanged<int?> onIndex;

  /// Ids of the interests picked in the second row; empty means all of them.
  final Set<String> picked;
  final ValueChanged<String> onPicked;

  /// The interests in the second row: the chosen group's, or with "All"
  /// every group's but the corridors (whose children are routes, not kinds
  /// of place).
  static List<CatalogInterest> secondRow(List<InterestGroup> groups, int? index) => index == null
      ? [
          for (final g in groups)
            if (!g.isCorridors) ...g.interests,
        ]
      : groups[index].interests;

  /// The `interestIds` to send: the picked interests, else the whole chosen
  /// group, else nothing (no filter).
  static List<String> idsFor(List<InterestGroup> groups, int? index, Set<String> picked) {
    if (picked.isNotEmpty) return picked.toList();
    if (index == null) return const [];
    return groups[index].interestIds;
  }

  /// False on a page that is always about one interest, where "All" would
  /// have nothing to mean.
  final bool showAll;

  @override
  State<InterestFilter> createState() => _InterestFilterState();
}

class _InterestFilterState extends State<InterestFilter> {
  /// So a page that opens on an interest further along the row can bring its
  /// chip into view.
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _selectedKey.currentContext;
      if (context != null) Scrollable.ensureVisible(context, alignment: 0.1, duration: Duration.zero);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final groups = widget.groups;
    final index = widget.index;
    final items = InterestFilter.secondRow(groups, index);
    final picked = widget.picked;
    final showAll = widget.showAll;
    final onIndex = widget.onIndex;
    final onPicked = widget.onPicked;

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // "All" first, then one chip per group.
            itemCount: groups.length + (showAll ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (showAll && i == 0) {
                return CategoryChip(label: s.all, selected: index == null, onTap: () => onIndex(null));
              }
              final at = showAll ? i - 1 : i;
              return CategoryChip(
                key: index == at ? _selectedKey : null,
                label: s.interestGroup(groups[at].name),
                selected: index == at,
                onTap: () => onIndex(at),
              );
            },
          ),
        ),
        if (items.isNotEmpty) ...[
          // A thin violet line between the groups and their interests.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Divider(height: 1, thickness: 1, color: AppColors.violet.withValues(alpha: 0.6)),
          ),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              // Only the interests tapped light up; with none picked the whole
              // group is shown, all chips left white.
              itemBuilder: (_, i) => CategoryChip(
                label: items[i].name,
                selected: picked.contains(items[i].id),
                onTap: () => onPicked(items[i].id),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
