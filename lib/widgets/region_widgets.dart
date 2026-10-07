import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/models/models.dart';
import '../state/collections_provider.dart';
import 'app_image.dart';
import 'destination_card.dart';

/// The violet and red the region and story pages share.
const regionViolet = Color(0xFF5B2EE5);
const tagRed = Color(0xFFE23E57);

const _dateMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _monthYear(DateTime d) => '${_dateMonths[d.month - 1]} ${d.year}';

class RegionChip extends StatelessWidget {
  const RegionChip({super.key, required this.label, required this.color, required this.onTap, this.filled = false});
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: AppText.sans(12.5, weight: FontWeight.w600, color: filled ? Colors.white : color),
        ),
      ),
    );
  }
}

/// Card with a soft violet-to-peach outline, used for Overview and the map.
class OutlinedCard extends StatelessWidget {
  const OutlinedCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: child,
    );
  }
}

/// "What Travelers Say": a sideways row of review cards and a button that
/// opens every review.
class ReviewsCarousel extends StatelessWidget {
  const ReviewsCarousel({super.key, required this.reviews});
  final List<Review> reviews;

  void _openAll(BuildContext context) {
    final s = S.read(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.whatTravelersSay,
                      style: AppText.sans(19, weight: FontWeight.w800, color: AppColors.sand900),
                    ),
                  ),
                  Text(
                    '${reviews.length}',
                    style: AppText.sans(14, weight: FontWeight.w700, color: regionViolet),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: reviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => ReviewCard(review: reviews[i], expanded: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: OutlinedCard(
          child: Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: regionViolet),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.noReviews,
                      style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                    ),
                    Text(s.beFirst, style: AppText.sans(13, color: AppColors.sand500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 196,
          child: LayoutBuilder(
            // A lone review fills the row; several peek so the row reads as swipeable.
            builder: (context, box) => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: reviews.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                width: reviews.length == 1 ? box.maxWidth - 32 : box.maxWidth * 0.78,
                child: ReviewCard(review: reviews[i], onMore: () => _openAll(context)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => _openAll(context),
            child: Container(
              padding: const EdgeInsets.all(1.4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.sand200),
                color: Colors.white,
              ),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                child: Text(
                  '${s.showAllReviews} ${reviews.length} ${reviews.length == 1 ? s.reviewWord : s.reviewsWord}',
                  style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.onMore, this.expanded = false});
  final Review review;
  final VoidCallback? onMore;

  /// Full text, for the all-reviews sheet.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = review;
    final initials = r.author.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();
    final text = r.text ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: expanded ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: AppColors.brand50,
                  child: Text(
                    initials,
                    style: AppText.sans(15, weight: FontWeight.w700, color: regionViolet),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.author,
                        style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: i <= r.rating ? AppColors.star : AppColors.sand200,
                            ),
                          Text('  ·  ', style: AppText.sans(12, color: AppColors.sand400)),
                          Flexible(
                            child: Text(
                              _monthYear(r.createdAt),
                              style: AppText.sans(13, color: AppColors.sand500),
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
            const SizedBox(height: 10),
            if (expanded)
              Text(text, style: AppText.sans(14, color: AppColors.sand600, height: 1.5))
            else ...[
              Text(
                text,
                style: AppText.sans(14, color: AppColors.sand600, height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              if (onMore != null)
                GestureDetector(
                  onTap: onMore,
                  child: Text(
                    s.showMore,
                    style: AppText.sans(14, weight: FontWeight.w600, color: regionViolet),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class RegionSectionHeader extends StatelessWidget {
  const RegionSectionHeader({super.key, required this.title, this.onMore});
  final String title;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.sans(18, weight: FontWeight.w800, color: AppColors.sand900),
            ),
          ),
          if (onMore != null)
            Material(
              color: AppColors.brand50,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onMore,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.arrow_forward_rounded, color: regionViolet, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LikeCard extends StatelessWidget {
  const LikeCard({super.key, required this.destination});
  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return GestureDetector(
      onTap: () => context.push(Routes.destination(d.region, d.slug)),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 100,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(d.image),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: SaveButton(kind: SavedKind.destination, itemKey: d.key, dark: true, size: 30),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(d.province, style: AppText.sans(11.5, color: AppColors.sand500), maxLines: 1),
          ],
        ),
      ),
    );
  }
}
