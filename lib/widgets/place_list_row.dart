import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/models/models.dart';
import 'app_image.dart';
import 'destination_card.dart';

/// One place: photo, name, what it is known for, and who recommends it.
class PlaceListRow extends StatelessWidget {
  const PlaceListRow({super.key, required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    // What the place is known for: its facts if the data has them, else what
    // kind of place it is.
    final detail = d.facets.isEmpty ? d.category : d.facets.values.join(', ');

    return InkWell(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 54, height: 54, child: AppImage(d.image, radius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF34D399)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          // The app puts its own name to the places it picks out.
                          d.featured ? s.recommendByAms : s.recommendByTraveler,
                          style: AppText.sans(10.5, color: AppColors.sand500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
