import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../data/models/models.dart';
import 'browse_bar.dart';
import 'destination_card.dart';

/// The filter every browse page wears: the interests in one row, and what the
/// chosen one is made of in a second row underneath.
class InterestFilter extends StatelessWidget {
  const InterestFilter({
    super.key,
    required this.interests,
    required this.index,
    required this.onIndex,
    required this.groups,
    required this.picked,
    required this.onPicked,
  });

  final List<Interest> interests;

  /// Which interest is chosen, or null for "All".
  final int? index;
  final ValueChanged<int?> onIndex;

  /// The names in the second row — the groups of the chosen interest, or the
  /// corridors when that is the chosen one.
  final List<String> groups;
  final Set<String> picked;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // "All" first, then one chip per interest.
            itemCount: interests.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => i == 0
                ? CategoryChip(label: s.all, selected: index == null, onTap: () => onIndex(null))
                : CategoryChip(
                    label: bilingual(context, interests[i - 1].name, interests[i - 1].nameKh).$1,
                    selected: index == i - 1,
                    onTap: () => onIndex(i - 1),
                  ),
          ),
        ),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => CategoryChip(
                label: groups[i],
                selected: picked.contains(groups[i]),
                onTap: () => onPicked(groups[i]),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
