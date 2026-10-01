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

enum _Sort { recent, oldest, highest, lowest }

/// Every review this traveller has written, with how they add up.
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  _Sort _sort = _Sort.recent;

  /// Null shows every rating; otherwise only reviews with that many stars.
  int? _stars;

  String _sortLabel(S s) => switch (_sort) {
    _Sort.recent => s.mostRecent,
    _Sort.oldest => s.oldest,
    _Sort.highest => s.highestRated,
    _Sort.lowest => s.lowestRated,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = context.read<TravelRepository>();
    final author = context.select<AuthProvider, String?>((a) => a.user?.username);

    return Scaffold(
      appBar: AppBar(title: Text(s.reviews, style: AppText.display(20)), centerTitle: true),
      body: AsyncView<(List<Review>, List<Destination>)>(
        load: () => (
          author == null ? Future.value(const <Review>[]) : repo.getMyReviews(author),
          repo.getDestinations(),
        ).wait,
        builder: (context, data, _) {
          final (all, places) = data;
          final byKey = {for (final d in places) d.key: d};
          final average = all.isEmpty ? null : all.map((r) => r.rating).reduce((a, b) => a + b) / all.length;

          final list = all.where((r) => _stars == null || r.rating == _stars).toList()
            ..sort(switch (_sort) {
              _Sort.recent => (a, b) => b.createdAt.compareTo(a.createdAt),
              _Sort.oldest => (a, b) => a.createdAt.compareTo(b.createdAt),
              _Sort.highest => (a, b) => b.rating.compareTo(a.rating),
              _Sort.lowest => (a, b) => a.rating.compareTo(b.rating),
            });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(child: _Stat(value: '${all.length}', label: s.reviewsWritten)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Stat(
                        value: average == null ? '—' : average.toStringAsFixed(1),
                        label: s.averageRating,
                        star: average != null,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    PopupMenuButton<_Sort>(
                      initialValue: _sort,
                      position: PopupMenuPosition.under,
                      onSelected: (v) => setState(() => _sort = v),
                      itemBuilder: (context) => [
                        for (final v in _Sort.values)
                          PopupMenuItem(
                            value: v,
                            child: Text(switch (v) {
                              _Sort.recent => s.mostRecent,
                              _Sort.oldest => s.oldest,
                              _Sort.highest => s.highestRated,
                              _Sort.lowest => s.lowestRated,
                            }),
                          ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.sand200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${s.sortBy}: ${_sortLabel(s)}',
                              style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand800),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.sand500),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<int?>(
                      initialValue: _stars,
                      position: PopupMenuPosition.under,
                      onSelected: (v) => setState(() => _stars = v),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: null, child: Text(s.allRatings)),
                        for (var i = 5; i >= 1; i--)
                          PopupMenuItem(value: i, child: Text('$i ★')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _stars == null ? Colors.white : AppColors.brand50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _stars == null ? AppColors.sand200 : AppColors.brand600),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: _stars == null ? AppColors.sand600 : AppColors.brand600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(icon: Icons.rate_review_outlined, title: s.noReviews, body: s.noReviewsBody)
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + MediaQuery.paddingOf(context).bottom),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ReviewRow(
                          review: list[i],
                          place: byKey[list[i].destination],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.star = false});
  final String value;
  final String label;
  final bool star;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.sand100,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: AppText.display(24)),
              if (star) ...[
                const SizedBox(width: 4),
                const Icon(Icons.star_rounded, size: 20, color: AppColors.star),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.sans(13, color: AppColors.sand500)),
        ],
      ),
    );
  }
}

/// One review: the place's photo, its name, the stars, when, and the opening
/// of what was written.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review, this.place});
  final Review review;
  final Destination? place;

  @override
  Widget build(BuildContext context) {
    final r = review;
    return InkWell(
      onTap: () => context.push(Routes.myReview(review.id), extra: review),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              height: 74,
              child: place == null
                  ? const ColoredBox(color: AppColors.sand100)
                  : AppImage(place!.image, radius: BorderRadius.circular(12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place?.name ?? r.title ?? '',
                    style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Stars(r.rating, size: 14),
                  const SizedBox(height: 3),
                  Text(
                    _monthYear(r.visitedOn ?? r.createdAt),
                    style: AppText.sans(12, color: AppColors.sand500),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    r.text ?? '',
                    style: AppText.sans(12.5, color: AppColors.sand600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
          ],
        ),
      ),
    );
  }

  static String _monthYear(DateTime d) {
    const months = [
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
    return '${months[d.month - 1]} ${d.year}';
  }
}
