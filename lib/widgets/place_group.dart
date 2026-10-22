import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/api/catalog.dart';
import 'app_image.dart';
import '../state/collections_provider.dart';
import 'common.dart';
import 'destination_card.dart';
import 'overview_card.dart';

/// A named group of places — a province or a region — with a way into its own
/// page and a row of what it holds.
class PlaceGroup extends StatelessWidget {
  const PlaceGroup({super.key, required this.title, required this.route, required this.places, this.showHeart = false});

  final String title;

  /// Where the arrow leads: the province or region page.
  final String route;
  final List<PlaceCard> places;

  /// A heart on each photo, for saving straight from the row.
  final bool showHeart;

  @override
  Widget build(BuildContext context) {
    // The orange-to-violet border of the place pages' cards.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: GradientFrame(
        padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
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
                      onTap: () => context.push(route),
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
                itemBuilder: (_, i) => _PlaceCard(card: places[i], showHeart: showHeart),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo, name, stars and how many people have reviewed the place.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.card, required this.showHeart});
  final PlaceCard card;
  final bool showHeart;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = card;
    return GestureDetector(
      onTap: () => context.push(Routes.card(d)),
      child: SizedBox(
        width: 146,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 112,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(d.coverUrl),
                    if (showHeart)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: SaveButton(kind: SavedKind.of(d.type), itemKey: d.id, size: 32),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              d.name,
              style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            if (d.averageRating != null)
              Row(
                children: [
                  Stars(d.averageRating!.round(), size: 11),
                  if (d.reviewCount > 0) ...[
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        s.reviewCountText(d.reviewCount),
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
