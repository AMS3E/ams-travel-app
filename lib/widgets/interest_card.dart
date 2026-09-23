import 'dart:ui';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/models/models.dart';
import 'app_image.dart';
import 'destination_card.dart';

/// Icon and accent colour for each interest category, keyed by `Interest.icon`.
const _styles = <String, (IconData, Color)>{
  'temple': (Icons.temple_buddhist_rounded, AppColors.brand600),
  'stay': (Icons.hotel_rounded, AppColors.plum600),
  'food': (Icons.restaurant_rounded, Color(0xFFC05621)),
  'water': (Icons.water_rounded, Color(0xFF0987A0)),
  'activity': (Icons.hiking_rounded, Color(0xFF2F855A)),
  'route': (Icons.route_rounded, AppColors.sunset500),
};

(IconData, Color) interestStyle(Interest interest) =>
    _styles[interest.icon] ?? (Icons.interests_rounded, AppColors.brand600);

/// Interest category card: photo with the category icon, then name,
/// description and how many places it covers. Fills the height it is given.
class InterestCard extends StatelessWidget {
  const InterestCard({super.key, required this.interest});
  final Interest interest;

  static const imageHeight = 128.0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (icon, color) = interestStyle(interest);
    final (title, _) = bilingual(context, interest.name, interest.nameKh);
    final count = interest.count;
    final unit = interest.isCorridors ? s.corridors : s.places;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x141C1935), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.interest(interest.slug)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(interest.image),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
                        ),
                        child: Icon(icon, color: color, size: 23),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            width: 34,
                            height: 34,
                            color: Colors.black.withValues(alpha: 0.32),
                            child: const Icon(Icons.arrow_outward_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900, height: 1.25),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        interest.description,
                        style: AppText.sans(12.5, color: AppColors.sand500, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (count != null)
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$count ${unit.toLowerCase()}',
                              style: AppText.sans(13, weight: FontWeight.w600, color: color),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
