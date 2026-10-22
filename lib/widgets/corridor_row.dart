import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/api/catalog.dart';
import 'app_image.dart';

/// One corridor card: photo, name, days and the stops along it. The whole row
/// opens it.
class CorridorRow extends StatelessWidget {
  const CorridorRow({super.key, required this.corridor});
  final PlaceCard corridor;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = corridor;

    return InkWell(
      onTap: () => context.push(Routes.corridor(c.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 54, height: 54, child: AppImage(c.coverUrl, radius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // The stops along it, else what it is.
                  Text(
                    [
                      if (c.durationDays != null) s.daysCount(c.durationDays!),
                      if (c.stopNames.isNotEmpty) c.stopNames.join(', ') else ?c.shortDescription,
                    ].join(' · '),
                    style: AppText.sans(11, color: AppColors.sand500, height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
