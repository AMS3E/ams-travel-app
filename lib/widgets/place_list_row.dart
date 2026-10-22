import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/api/catalog.dart';
import 'app_image.dart';
import 'open_status.dart';

/// One card as a row: photo, name, what kind of place it is, and who
/// recommends it. Works for every kind of card.
class PlaceListRow extends StatelessWidget {
  const PlaceListRow({super.key, required this.card});
  final PlaceCard card;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = card;
    // What kind of place it is, else its one-line description.
    final detail = d.categoryNames.isNotEmpty
        ? d.categoryNames.join(', ')
        : (d.shortDescription ?? d.provinceName ?? '');
    final seal = s.seal(traveler: d.travelerRecommended, verified: d.verified);
    // Green for the travellers' seal, violet for AMS's.
    final sealColour = d.travelerRecommended ? AppColors.seal : AppColors.violet;

    return InkWell(
      onTap: () => context.push(Routes.card(d)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 60, height: 60, child: AppImage(d.coverUrl, radius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: AppText.sans(11, color: AppColors.sand500, height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (OpenStatusLine.shows(d)) ...[
                    const SizedBox(height: 4),
                    OpenStatusLine(card: d, size: 10.5),
                  ] else if (seal != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.verified_rounded, size: 13, color: sealColour),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            seal,
                            style: AppText.sans(10.5, color: AppColors.sand500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
