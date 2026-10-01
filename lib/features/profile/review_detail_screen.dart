import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/auth_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

/// One of the traveller's own reviews, as they wrote it.
class ReviewDetailScreen extends StatelessWidget {
  const ReviewDetailScreen({super.key, required this.id, this.review});

  final String id;

  /// Handed over by the list; a deep link fetches it instead.
  final Review? review;

  @override
  Widget build(BuildContext context) {
    if (review != null) return _View(review: review!);

    final author = context.select<AuthProvider, String?>((a) => a.user?.username);
    return AsyncView<List<Review>>(
      load: () => author == null
          ? Future.value(const <Review>[])
          : context.read<TravelRepository>().getMyReviews(author),
      loading: const Scaffold(body: LoadingView()),
      builder: (context, reviews, _) {
        final match = reviews.where((r) => r.id == id).firstOrNull;
        return match == null ? const Scaffold(body: SizedBox()) : _View(review: match);
      },
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.review});
  final Review review;

  /// "10th, August 2026".
  static String _date(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final day = d.day;
    final suffix = (day % 100 >= 11 && day % 100 <= 13)
        ? 'th'
        : switch (day % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$day$suffix, ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = review;
    final ref = r.destination == null ? null : DestinationRef.fromKey(r.destination!);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.reviewTitle, style: AppText.display(20)),
        centerTitle: true,
        actions: [
          if (ref != null)
            IconButton(
              tooltip: s.editReview,
              onPressed: () => context.push(Routes.review(ref.region, ref.slug)),
              icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.sand700),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 28 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(s.yourRate, style: AppText.sans(13.5, color: AppColors.sand600)),
          const SizedBox(height: 8),
          Stars(r.rating, size: 26),
          const SizedBox(height: 16),
          Text(_date(r.visitedOn ?? r.createdAt), style: AppText.sans(13.5, color: AppColors.sand700)),

          if (r.tripType != null) ...[
            const SizedBox(height: 18),
            Text(s.kindOfVisit, style: AppText.sans(13.5, color: AppColors.sand600)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.violet,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  r.tripType!,
                  style: AppText.sans(12.5, weight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],

          if (r.title != null) ...[
            const SizedBox(height: 22),
            Text(r.title!, style: AppText.sans(18, weight: FontWeight.w700, color: AppColors.sand900)),
          ],
          if (r.text != null) ...[
            const SizedBox(height: 10),
            Text(r.text!, style: AppText.sans(14.5, color: AppColors.sand700, height: 1.6)),
          ],

          for (final photo in r.photos) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 220,
              width: double.infinity,
              child: AppImage(photo, radius: BorderRadius.circular(16)),
            ),
          ],
        ],
      ),
    );
  }
}
