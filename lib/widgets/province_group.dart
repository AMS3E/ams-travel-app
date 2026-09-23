import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/geo.dart';
import '../data/models/models.dart';
import 'app_image.dart';
import 'common.dart';
import 'destination_card.dart';


/// One province: its name, a way into the province page, and its places.
class ProvinceGroup extends StatelessWidget {
  const ProvinceGroup({super.key, required this.province, required this.places});
  final Province province;
  final List<Destination> places;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    bilingual(context, province.name, province.nameKh).$1,
                    style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Material(
                  color: AppColors.violet,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => context.push(Routes.province(province.slug)),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 14),
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _PlaceCard(destination: places[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Photo, name, stars and how many people have reviewed the place.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: SizedBox(
        width: 146,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 112,
              width: double.infinity,
              child: AppImage(d.image, radius: BorderRadius.circular(14)),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            if (d.rating != null)
              Row(
                children: [
                  Stars(d.rating!.round(), size: 11),
                  if (d.reviewCount != null) ...[
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${thousands(d.reviewCount!)} ${s.reviewsWord.toLowerCase()}',
                        style: AppText.sans(10.5, color: AppColors.sand500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
