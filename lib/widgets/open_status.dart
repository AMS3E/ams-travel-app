import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/opening_hours.dart';
import '../data/api/catalog.dart';

/// "● Open · 7AM–10PM" / "● Closed" for a food card, from the server's
/// `openNow` and `todayHours`. Nothing when the place has no hours.
class OpenStatusLine extends StatelessWidget {
  const OpenStatusLine({super.key, required this.card, this.size = 11});
  final PlaceCard card;
  final double size;

  static bool shows(PlaceCard card) => card.openNow != null;

  @override
  Widget build(BuildContext context) {
    final open = card.openNow;
    if (open == null) return const SizedBox.shrink();
    final s = S.of(context);
    final today = formatHoursLine(card.todayHours);
    return Row(
      children: [
        Container(
          width: size * 0.7,
          height: size * 0.7,
          decoration: BoxDecoration(color: open ? AppColors.success : AppColors.sunset500, shape: BoxShape.circle),
        ),
        SizedBox(width: size * 0.45),
        Flexible(
          child: Text(
            [open ? s.openNow : s.closedNow, ?today].join(' · '),
            style: AppText.sans(size, color: AppColors.sand600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
