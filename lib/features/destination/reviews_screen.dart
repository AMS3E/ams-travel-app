import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

/// Every review of one place.
class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key, required this.region, required this.slug});
  final String region;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final repo = context.read<TravelRepository>();
    final ref = DestinationRef(region, slug);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.reviewTitle, style: AppText.display(20)),
        centerTitle: true,
      ),
      body: AsyncView<(Destination, List<Review>)>(
        load: () => (repo.getDestination(region, slug), repo.getReviews(ref)).wait,
        builder: (context, data, _) {
          final (place, reviews) = data;
          return _Body(place: place, reviews: reviews);
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.violet,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          ),
          onPressed: () => context.push(Routes.review(region, slug)),
          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
          label: Text(
            s.writeReview,
            style: AppText.sans(15.5, weight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.place, required this.reviews});
  final Destination place;
  final List<Review> reviews;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// Only reviews with this many stars; null is all of them.
  int? _stars;

  /// Which reviews this traveller found helpful.
  ///
  /// TODO(api): send these to the backend so they last.
  final _liked = <String>{};

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = widget.place;
    final shown = _stars == null
        ? widget.reviews
        : widget.reviews.where((r) => r.rating == _stars).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        Row(
          children: [
            _StarFilter(
              stars: _stars,
              counts: {
                for (var i = 5; i >= 1; i--) i: widget.reviews.where((r) => r.rating == i).length,
              },
              total: widget.reviews.length,
              onChanged: (v) => setState(() => _stars = v),
            ),
            const Spacer(),
            if (d.rating != null) ...[
              const Icon(Icons.star_rounded, size: 18, color: AppColors.star),
              const SizedBox(width: 4),
              Text(
                d.rating!.toStringAsFixed(1),
                style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
              ),
              const SizedBox(width: 6),
              Text(
                '${thousands(d.reviewCount ?? widget.reviews.length)} ${s.reviewsWord.toLowerCase()}',
                style: AppText.sans(12.5, color: AppColors.violet),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text(s.noResults, style: AppText.sans(14.5, color: AppColors.sand500))),
          )
        else
          for (final r in shown)
            _ReviewBlock(
              review: r,
              liked: _liked.contains(r.id),
              onLike: () => setState(() {
                _liked.contains(r.id) ? _liked.remove(r.id) : _liked.add(r.id);
              }),
            ),
      ],
    );
  }
}

/// "All (500)" with a menu of star ratings behind it.
class _StarFilter extends StatelessWidget {
  const _StarFilter({
    required this.stars,
    required this.counts,
    required this.total,
    required this.onChanged,
  });

  final int? stars;
  final Map<int, int> counts;
  final int total;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopupMenuButton<int?>(
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        PopupMenuItem(value: null, child: Text('${s.all} ($total)')),
        for (var i = 5; i >= 1; i--)
          PopupMenuItem(value: i, child: Text('$i ★  (${counts[i] ?? 0})')),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stars == null ? '${s.all} ($total)' : '$stars ★ (${counts[stars] ?? 0})',
              style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.sand800),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.sand500),
          ],
        ),
      ),
    );
  }
}

/// One review: who wrote it, what they said, their photos, and whether this
/// traveller found it helpful.
class _ReviewBlock extends StatefulWidget {
  const _ReviewBlock({required this.review, required this.liked, required this.onLike});
  final Review review;
  final bool liked;
  final VoidCallback onLike;

  @override
  State<_ReviewBlock> createState() => _ReviewBlockState();
}

class _ReviewBlockState extends State<_ReviewBlock> {
  bool _open = false;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = widget.review;
    final when = '${_months[r.createdAt.month - 1]} ${r.createdAt.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.violet,
                child: Text(
                  r.author.isEmpty ? '?' : r.author[0].toUpperCase(),
                  style: AppText.sans(14, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.author,
                      style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
                        const SizedBox(width: 3),
                        Text(
                          '${r.rating.toDouble().toStringAsFixed(1)}  $when',
                          style: AppText.sans(11.5, color: AppColors.sand500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (r.text != null) ...[
            const SizedBox(height: 10),
            Text(
              r.text!,
              style: AppText.sans(13.5, color: AppColors.sand700, height: 1.5),
              maxLines: _open ? null : 3,
              overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (r.text!.length > 110)
              GestureDetector(
                onTap: () => setState(() => _open = !_open),
                child: Text(
                  _open ? s.showLess : s.showMore,
                  style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.violet),
                ),
              ),
          ],
          if (r.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: r.photos.length,
              itemBuilder: (_, i) => AppImage(r.photos[i], radius: BorderRadius.circular(10)),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: widget.onLike,
                tooltip: s.helpful,
                icon: Icon(
                  widget.liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  size: 18,
                  color: widget.liked ? AppColors.violet : AppColors.sand500,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.sand500),
                // TODO(api): reporting needs somewhere to send the report.
                onSelected: (_) => showToast(context, s.reportLater),
                itemBuilder: (_) => [PopupMenuItem(value: 'report', child: Text(s.reportReview))],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
