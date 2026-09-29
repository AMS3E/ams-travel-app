import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../widgets/app_image.dart';
import '../../widgets/destination_card.dart';

/// Which way the saved places are laid out.
enum SavedView { list, grid }

/// The List / Grid switch above a set of saved places.
class ViewToggle extends StatelessWidget {
  const ViewToggle({super.key, required this.view, required this.onChanged});
  final SavedView view;
  final ValueChanged<SavedView> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget half(SavedView value, IconData icon, String label) {
      final on = value == view;
      return InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? AppColors.violet : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: on ? Colors.white : AppColors.sand600),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppText.sans(
                  12.5,
                  weight: FontWeight.w600,
                  color: on ? Colors.white : AppColors.sand600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.sand100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          half(SavedView.list, Icons.view_list_rounded, 'List'),
          const SizedBox(width: 3),
          half(SavedView.grid, Icons.grid_view_rounded, 'Grid'),
        ],
      ),
    );
  }
}

/// A saved place in a row: photo, name, where it is, its score, and the heart
/// that takes it back out.
class SavedRow extends StatelessWidget {
  const SavedRow({super.key, required this.destination, required this.onRemove});
  final Destination destination;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return InkWell(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            SizedBox(width: 52, height: 52, child: AppImage(d.image, radius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    d.province,
                    style: AppText.sans(11.5, color: AppColors.sand500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (d.rating != null) ...[
                    const SizedBox(height: 4),
                    RatingBadge(rating: d.rating!),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.favorite_rounded, color: AppColors.sunset500),
            ),
          ],
        ),
      ),
    );
  }
}

/// A saved place as a card: photo with its score and the heart, then the name.
class SavedTile extends StatelessWidget {
  const SavedTile({super.key, required this.destination, required this.onRemove});
  final Destination destination;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(d.image),
                  if (d.rating != null)
                    Positioned(left: 8, top: 8, child: RatingBadge(rating: d.rating!, onImage: true)),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: IconButton(
                      onPressed: onRemove,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.sunset500,
                        shadows: [Shadow(color: Color(0x55000000), blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            d.province,
            style: AppText.sans(11.5, color: AppColors.sand500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The amber score badge both layouts carry.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.onImage = false});
  final double rating;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: onImage ? const Color(0xCC1A1206) : AppColors.star.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.star),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: AppText.sans(
              10.5,
              weight: FontWeight.w700,
              color: onImage ? Colors.white : AppColors.sand800,
            ),
          ),
        ],
      ),
    );
  }
}
