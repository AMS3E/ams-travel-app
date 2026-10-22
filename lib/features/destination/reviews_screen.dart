import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/geo.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import 'reviews_section.dart';

/// Every review of a place, stay, food place or corridor, newest first, a
/// page at a time (`GET /reviews?targetType=&targetId=`), under the target's
/// rating summary (`GET /ratings/summary`). The "All" menu narrows the list
/// to one star rating on the server (`rating=`).
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.type, required this.id});
  final CardType type;
  final String id;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

/// "All (500)" with a menu of 5 ★ … 1 ★; the counts per star come from the
/// rating summary.
class _StarMenu extends StatelessWidget {
  const _StarMenu({required this.stars, required this.allCount, required this.starCounts, required this.onPick});
  final int? stars;
  final int allCount;
  final Map<int, int> starCounts;
  final ValueChanged<int?> onPick;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String label(int? n) => n == null ? '${s.all} (${thousands(allCount)})' : '$n ★ (${thousands(starCounts[n] ?? 0)})';

    return PopupMenuButton<int>(
      // 0 stands for All: a menu item cannot carry null.
      onSelected: (v) => onPick(v == 0 ? null : v),
      itemBuilder: (_) => [
        for (final n in const [0, 5, 4, 3, 2, 1])
          CheckedPopupMenuItem<int>(value: n, checked: (stars ?? 0) == n, child: Text(label(n == 0 ? null : n))),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: stars == null ? AppColors.sand200 : AppColors.violet),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label(stars),
              style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.sand800),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.sand600),
          ],
        ),
      ),
    );
  }
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  static const _pageSize = 20;

  final _reviews = <TravelReview>[];
  RatingSummary? _summary;
  int _total = 0;

  /// How many reviews in all, from the unfiltered list.
  int? _allTotal;

  /// The star rating picked in the menu; null is All.
  int? _stars;
  int _next = 0;
  bool _last = false;
  bool _loading = false;

  /// False until the first page has come back.
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  /// Starts the list again; the summary too unless only the star filter
  /// changed (it covers every review either way).
  Future<void> _reload({bool summary = true}) async {
    setState(() {
      _reviews.clear();
      _next = 0;
      _last = false;
      _error = null;
    });
    if (summary) {
      context.read<AmsApi>().ratingSummary(widget.type, widget.id).then((r) {
        if (mounted) setState(() => _summary = r);
      }, onError: (_) {});
    }
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _last) return;
    setState(() => _loading = true);
    try {
      final page = await context.read<AmsApi>().reviews(
        widget.type,
        widget.id,
        rating: [?_stars],
        page: _next,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _reviews.addAll(page.content);
        _total = page.totalElements;
        if (_stars == null) _allTotal = page.totalElements;
        _next = page.number + 1;
        _last = page.isLast || page.content.isEmpty;
        _loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickStars(int? stars) {
    if (stars == _stars) return;
    _stars = stars;
    _reload(summary: false);
  }

  Future<void> _write() async {
    final sent = await writeReviewFor(context, widget.type, widget.id);
    if (sent && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final summary = _summary;
    final average = summary?.shownAverage;

    Widget body;
    if (_error != null && _reviews.isEmpty) {
      body = ErrorView(error: _error!, onRetry: _reload);
    } else if ((_loading || !_loaded) && _reviews.isEmpty) {
      body = const LoadingView();
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400) _more();
          return false;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Row(
              children: [
                _StarMenu(
                  stars: _stars,
                  allCount: _allTotal ?? _total,
                  starCounts: summary?.stars ?? const {},
                  onPick: _pickStars,
                ),
                const Spacer(),
                if (average != null) ...[
                  const Icon(Icons.star_rounded, size: 18, color: AppColors.star),
                  const SizedBox(width: 4),
                  Text(
                    average.toStringAsFixed(1),
                    style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
                  ),
                  const SizedBox(width: 6),
                  Text(s.reviewCountText(summary!.count), style: AppText.sans(12.5, color: AppColors.violet)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
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
            else
              for (final r in _reviews) ReviewBlock(review: r),
            if (_loading && _reviews.isNotEmpty) const LoadingView(padding: EdgeInsets.all(16)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.reviewTitle, style: AppText.display(20)),
        centerTitle: true,
      ),
      body: RefreshIndicator(onRefresh: _reload, color: AppColors.violet, child: body),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.violet,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          ),
          onPressed: _write,
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

/// "Family", "Solo".
String visitTypeLabel(S s, VisitType v) => switch (v) {
  VisitType.business => s.visitBusiness,
  VisitType.couples => s.visitCouples,
  VisitType.family => s.visitFamily,
  VisitType.friends => s.visitFriends,
  VisitType.solo => s.visitSolo,
};

/// One review: who wrote it, when and how they visited, what they said and
/// their photos.
class ReviewBlock extends StatefulWidget {
  const ReviewBlock({super.key, required this.review});
  final TravelReview review;

  @override
  State<ReviewBlock> createState() => _ReviewBlockState();
}

class _ReviewBlockState extends State<ReviewBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = widget.review;
    final visited = r.visitedMonth ?? r.createdAt.toLocal();
    final when = [Dates.monthYear(visited), if (r.visitType != null) visitTypeLabel(s, r.visitType!)].join('  ·  ');
    final content = r.content?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReviewerAvatar(review: r, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.authorName,
                      style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '${r.rating.toDouble().toStringAsFixed(1)}  $when',
                            style: AppText.sans(11.5, color: AppColors.sand500),
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
          if (r.title != null && r.title!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              r.title!.trim(),
              style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.sand900),
            ),
          ],
          if (content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              content,
              style: AppText.sans(13.5, color: AppColors.sand700, height: 1.5),
              maxLines: _open ? null : 3,
              overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (content.length > 110)
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
              itemBuilder: (_, i) => AppImage(r.photos[i].url, radius: BorderRadius.circular(10)),
            ),
          ],
          // The design's Helpful and Report buttons are left out: parked
          // 2026-10-14 (R-043, R-044).
        ],
      ),
    );
  }
}
