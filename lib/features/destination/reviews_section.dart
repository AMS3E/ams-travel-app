import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/geo.dart';
import '../../data/api/ams_api.dart';
import '../../state/auth_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/overview_card.dart';
import '../auth/sign_in.dart';

/// Opens the review form for a place once the traveller is signed in. True
/// when a review was sent.
Future<bool> writeReviewFor(BuildContext context, CardType type, String id) async {
  if (!context.read<AuthProvider>().isSignedIn) {
    // Says why and offers Keycloak's sign-in page.
    await whenSignedIn(context, S.read(context).logInToReview, () {});
    return false;
  }
  return await context.push<bool>(Routes.writeReview(type, id)) ?? false;
}

/// "What Travelers Say" on a detail page: the newest reviews side by side,
/// the way to all of them and the way to write one.
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({super.key, required this.type, required this.id, this.average, this.count});

  final CardType type;
  final String id;

  /// From the place's card or rating summary; null when nobody has rated it.
  final double? average;
  final int? count;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  int _version = 0;

  Future<void> _write() async {
    final sent = await writeReviewFor(context, widget.type, widget.id);
    if (sent && mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = context.read<AmsApi>();
    final me = context.select<AuthProvider, String?>((a) => a.user?.id);
    return AsyncView<PageOf<TravelReview>>(
      key: ValueKey(_version),
      load: () => api.reviews(widget.type, widget.id, size: 6),
      loading: const LoadingView(padding: EdgeInsets.all(24)),
      builder: (context, page, _) {
        final reviews = page.content;
        final total = widget.count ?? page.totalElements;
        return DetailSection(
          title: s.whatTravelersSay,
          trailing: widget.average == null
              ? null
              : Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.star, size: 22),
                    const SizedBox(width: 4),
                    Text(widget.average!.toStringAsFixed(1), style: AppText.display(20)),
                    Text('  (${thousands(total)})', style: AppText.sans(13, color: AppColors.sand500)),
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
                      child: ReviewCard(review: reviews[i], own: me != null && reviews[i].userId == me),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GradientFrame(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(19),
                    onTap: () async {
                      await context.push(Routes.reviews(widget.type, widget.id));
                      if (mounted) setState(() => _version++);
                    },
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(
                          '${s.showAllReviews} ${thousands(page.totalElements)} ${s.reviewsWord.toLowerCase()}',
                          style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.violet),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // The main action, in the app's violet.
              DecoratedBox(
                decoration: BoxDecoration(color: AppColors.violet, borderRadius: BorderRadius.circular(20)),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _write,
                    child: SizedBox(
                      height: 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            s.writeReview,
                            style: AppText.sans(15, weight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The reviewer's picture, or the first letter of their name.
class ReviewerAvatar extends StatelessWidget {
  const ReviewerAvatar({super.key, required this.review, this.radius = 16});
  final TravelReview review;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final name = review.authorName.trim();
    if (review.authorAvatarUrl.isNotEmpty) {
      return ClipOval(
        child: SizedBox.square(dimension: radius * 2, child: AppImage(review.authorAvatarUrl)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.violet,
      child: Text(
        name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase(),
        style: AppText.sans(radius * 0.8, weight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// One review in the side-by-side row.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.own = false});
  final TravelReview review;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final words = [review.title, review.content].whereType<String>().where((t) => t.trim().isNotEmpty).join(' — ');
    return GradientFrame(
      padding: const EdgeInsets.all(16),
      color: own ? AppColors.brand50 : const Color(0xFFF7F7F8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReviewerAvatar(review: review),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName,
                      style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.sand900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(Dates.short(review.createdAt), style: AppText.sans(12, color: AppColors.sand500)),
                  ],
                ),
              ),
              Stars(review.rating, size: 15),
            ],
          ),
          if (words.isNotEmpty) ...[
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                words,
                style: AppText.sans(14, color: AppColors.sand700, height: 1.5),
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
