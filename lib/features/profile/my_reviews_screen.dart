import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/auth_provider.dart';
import '../../state/collections_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../auth/sign_in.dart' as auth;
import '../../core/utils/dates.dart';

/// The orders `GET /reviews/me` sorts in.
enum _Sort {
  recent('createdAt,desc'),
  oldest('createdAt,asc'),
  highest('rating,desc'),
  lowest('rating,asc');

  const _Sort(this.param);
  final String param;
}

/// Every review this traveller has written (`GET /reviews/me`, a page at a
/// time, sorted by the server), with the place each one is about: one
/// `GET /search/cards` per kind of place on the page.
///
/// The average is taken from the rows loaded, as screens-to-api.md says. The
/// star filter is the server's (`rating=`).
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  static const _pageSize = 20;

  _Sort _sort = _Sort.recent;

  /// The star rating to show; null is every review.
  int? _stars;
  final List<TravelReview> _rows = [];
  final Map<String, PlaceCard> _places = {};
  int _total = 0;

  /// Reviews written in all, from an unfiltered page.
  int? _written;
  int _next = 0;
  bool _last = false;
  bool _loading = false;
  Object? _error;
  String? _loadedFor;

  Future<void> _reset() async {
    _rows.clear();
    _next = 0;
    _last = false;
    _total = 0;
    await _more();
  }

  /// The next page, then the cards for its places.
  Future<void> _more() async {
    if (_loading || _last) return;
    final api = context.read<AmsApi>();
    final sort = _sort;
    final stars = _stars;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await api.myReviews(rating: [?stars], page: _next, size: _pageSize, sort: sort.param);
      final byType = <CardType, List<String>>{};
      for (final r in page.content) {
        if (!_places.containsKey(FoldersProvider.keyOf(r.targetType, r.targetId))) {
          byType.putIfAbsent(r.targetType, () => []).add(r.targetId);
        }
      }
      final cards = await Future.wait([
        for (final e in byType.entries) api.cards(e.value.toSet().toList(), type: e.key).or(const []),
      ]);
      if (!mounted || sort != _sort || stars != _stars) return;
      setState(() {
        for (final c in cards.expand((l) => l)) {
          _places[FoldersProvider.keyOf(c.type, c.id)] = c;
        }
        _rows.addAll(page.content);
        _total = page.totalElements;
        if (stars == null) _written = page.totalElements;
        _next = page.number + 1;
        _last = page.isLast;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        // The order or the filter changed while this page was on its way:
        // start over with them.
        if (sort != _sort || stars != _stars) _more();
      }
    }
  }

  String _label(S s, _Sort v) => switch (v) {
    _Sort.recent => s.mostRecent,
    _Sort.oldest => s.oldest,
    _Sort.highest => s.highestRated,
    _Sort.lowest => s.lowestRated,
  };

  Future<void> _open(TravelReview r) async {
    final changed = await context.push<Object?>(Routes.myReview(r.id), extra: r);
    if (changed == true && mounted) await _reset();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final userId = context.select<AuthProvider, String?>((a) => a.userId);
    if (userId != null && _loadedFor != userId) {
      _loadedFor = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reset();
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.reviews, style: AppText.display(20)), centerTitle: true),
      body: userId == null
          ? auth.SignInPrompt(icon: Icons.rate_review_outlined, title: s.reviews, body: s.reviewsSignIn)
          : _body(s),
      // A review is about a place: find it first, then write from its page.
      bottomNavigationBar: userId == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
                onPressed: () => context.push(Routes.search),
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                label: Text(
                  s.writeReview,
                  style: AppText.sans(15.5, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
    );
  }

  Widget _body(S s) {
    if (_rows.isEmpty && _error != null) return ErrorView(error: _error!, onRetry: _reset);
    if (_rows.isEmpty && (_loading || _loadedFor == null || !_last)) return const LoadingView();
    final average = _rows.isEmpty ? null : _rows.map((r) => r.rating).reduce((a, b) => a + b) / _rows.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: _Stat(value: '${_written ?? _total}', label: s.reviewsWritten),
              ),
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
                onSelected: (v) {
                  if (v == _sort) return;
                  setState(() => _sort = v);
                  _reset();
                },
                itemBuilder: (context) => [
                  for (final v in _Sort.values) PopupMenuItem(value: v, child: Text(_label(s, v))),
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
                        '${s.sortBy}: ${_label(s, _sort)}',
                        style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand800),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.sand500),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<int>(
                position: PopupMenuPosition.under,
                // 0 stands for every review: a menu item cannot carry null.
                onSelected: (v) {
                  final stars = v == 0 ? null : v;
                  if (stars == _stars) return;
                  setState(() => _stars = stars);
                  _reset();
                },
                itemBuilder: (context) => [
                  for (final n in const [0, 5, 4, 3, 2, 1])
                    CheckedPopupMenuItem(value: n, checked: (_stars ?? 0) == n, child: Text(n == 0 ? s.all : '$n ★')),
                ],
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _stars == null ? AppColors.sand200 : AppColors.violet),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 16, color: AppColors.sand700),
                      const SizedBox(width: 6),
                      Text(
                        _stars == null ? s.all : '$_stars ★',
                        style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _rows.isEmpty
              ? SingleChildScrollView(
                  child: EmptyState(icon: Icons.rate_review_outlined, title: s.noReviews, body: s.noReviewsBody),
                )
              : RefreshIndicator(
                  onRefresh: _reset,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + MediaQuery.paddingOf(context).bottom),
                    itemCount: _rows.length + (_last ? 0 : 1),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      if (i == _rows.length) {
                        return Center(
                          child: _loading
                              ? const LoadingView(padding: EdgeInsets.all(12))
                              : TextButton(onPressed: _more, child: Text(s.showMore)),
                        );
                      }
                      final r = _rows[i];
                      return _ReviewRow(
                        review: r,
                        place: _places[FoldersProvider.keyOf(r.targetType, r.targetId)],
                        onTap: () => _open(r),
                      );
                    },
                  ),
                ),
        ),
      ],
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
      decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(AppTheme.radius)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: AppText.display(24)),
              if (star) ...[const SizedBox(width: 4), const Icon(Icons.star_rounded, size: 20, color: AppColors.star)],
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.sans(13, color: AppColors.sand500)),
        ],
      ),
    );
  }
}

/// One review: the place's photo and name, the stars, the month of the visit
/// and the opening of what was written.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review, required this.place, required this.onTap});
  final TravelReview review;
  final PlaceCard? place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = review;
    final when = r.visitedMonth ?? r.createdAt.toLocal();
    return InkWell(
      onTap: onTap,
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
            SizedBox(width: 74, height: 74, child: AppImage(place?.coverUrl ?? '', radius: BorderRadius.circular(12))),
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
                  Row(
                    children: [
                      Stars(r.rating, size: 14),
                      if (r.isPending) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            s.reviewPending,
                            style: AppText.sans(11, color: AppColors.sand500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(Dates.monthYear(when), style: AppText.sans(12, color: AppColors.sand500)),
                  if (r.content != null && r.content!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      r.content!,
                      style: AppText.sans(12.5, color: AppColors.sand600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
          ],
        ),
      ),
    );
  }
}
