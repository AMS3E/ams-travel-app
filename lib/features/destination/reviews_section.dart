import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/auth_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/detail_scaffold.dart';

class ReviewsSection extends StatefulWidget {
  const ReviewsSection({super.key, required this.destination});
  final Destination destination;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  final int _version = 0;

  /// Every review on this place, in a sheet.
  void _showAll(BuildContext context, List<Review> reviews, String? username) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (context, controller) => ListView.separated(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _ReviewCard(review: reviews[i], own: reviews[i].author == username),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = context.read<TravelRepository>();
    return AsyncView<List<Review>>(
      key: ValueKey(_version),
      load: () => repo.getReviews(widget.destination.ref),
      loading: const LoadingView(padding: EdgeInsets.all(24)),
      builder: (context, reviews, _) {
        final avg = reviews.isEmpty ? null : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
        final username = context.select<AuthProvider, String?>((a) => a.user?.username);
        return DetailSection(
          title: s.whatTravelersSay,
          trailing: avg == null
              ? null
              : Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.star, size: 22),
                    const SizedBox(width: 4),
                    Text(avg.toStringAsFixed(1), style: AppText.display(20)),
                    Text('  (${reviews.length})', style: AppText.sans(13, color: AppColors.sand500)),
                  ],
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reviews.isEmpty)
                SurfaceCard(
                  child: Column(
                    children: [
                      const Stars(0, size: 26),
                      const SizedBox(height: 10),
                      Text(
                        s.noReviews,
                        style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sand900),
                      ),
                      const SizedBox(height: 2),
                      Text(s.beFirst, style: AppText.sans(13.5, color: AppColors.sand500)),
                    ],
                  ),
                )
              else ...[
                // Side by side, so the section stays short whatever is written.
                SizedBox(
                  height: 178,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: reviews.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => SizedBox(
                      width: 268,
                      child: _ReviewCard(review: reviews[i], own: reviews[i].author == username),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: BorderSide(color: AppColors.violet.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _showAll(context, reviews, username),
                  child: Text(
                    '${s.showAllReviews} ${thousands(widget.destination.reviewCount ?? reviews.length)} '
                    '${s.reviewsWord.toLowerCase()}',
                    style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.violet),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.own});
  final Review review;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final d = review.createdAt;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: own ? AppColors.brand50 : AppColors.sand100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.brand600,
                child: Text(
                  review.author.isEmpty ? '?' : review.author[0].toUpperCase(),
                  style: AppText.sans(13, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.sand900),
                    ),
                    Text(
                      '${d.day} ${months[d.month - 1]} ${d.year}',
                      style: AppText.sans(12, color: AppColors.sand500),
                    ),
                  ],
                ),
              ),
              Stars(review.rating, size: 15),
            ],
          ),
          if (review.text != null && review.text!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(review.text!, style: AppText.sans(14, color: AppColors.sand700, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
