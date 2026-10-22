import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../../core/utils/dates.dart';
import '../destination/reviews_screen.dart' show visitTypeLabel;
import 'edit_review_page.dart';

/// One of the traveller's own reviews (`GET /reviews/{id}`), with the place
/// it is about, and the ways to edit (`PUT /reviews/{id}`) or delete it
/// (`DELETE /reviews/{id}`). Pops with true when the review changed.
class ReviewDetailScreen extends StatefulWidget {
  const ReviewDetailScreen({super.key, required this.id, this.review});

  final String id;

  /// Handed over by the list; a deep link fetches it instead.
  final TravelReview? review;

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  late TravelReview? _review = widget.review;
  bool _changed = false;

  /// Bumped after an edit so the page reads the place again.
  int _version = 0;

  Future<(TravelReview, PlaceCard?)> _load(AmsApi api) async {
    final review = _review ?? await api.review(widget.id);
    _review = review;
    final card = await api.card(review.targetId, type: review.targetType).orNull;
    return (review, card);
  }

  Future<void> _edit(TravelReview review, PlaceCard? place) async {
    final updated = await Navigator.of(context).push<TravelReview>(
      MaterialPageRoute(
        builder: (_) => EditReviewPage(review: review, placeName: place?.name),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _review = updated;
        _changed = true;
        _version++;
      });
    }
  }

  Future<void> _delete(TravelReview review) async {
    final s = S.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.deleteReviewConfirm, style: AppText.display(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sunset500),
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AmsApi>().deleteReview(review.id);
      if (!mounted) return;
      showToast(context, s.reviewDeleted);
      context.pop(true);
    } catch (_) {
      if (mounted) showToast(context, s.saveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = context.read<AmsApi>();
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: AsyncView<(TravelReview, PlaceCard?)>(
        key: ValueKey(_version),
        load: () => _load(api),
        loading: const Scaffold(body: LoadingView()),
        builder: (context, data, _) {
          final (review, place) = data;
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: Text(s.reviewTitle, style: AppText.display(20)),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: s.editReview,
                  onPressed: () => _edit(review, place),
                  icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.sand700),
                ),
                IconButton(
                  tooltip: s.deleteReview,
                  onPressed: () => _delete(review),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.sunset600),
                ),
              ],
            ),
            body: _ReviewBody(review: review, place: place),
          );
        },
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.review, required this.place});
  final TravelReview review;
  final PlaceCard? place;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final r = review;
    final month = r.visitedMonth;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset(context)),
      children: [
        if (place != null) ...[
          InkWell(
            onTap: () => context.push(Routes.card(place!)),
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                SizedBox(width: 56, height: 56, child: AppImage(place!.coverUrl, radius: BorderRadius.circular(12))),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    place!.name,
                    style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (r.isUnpublished) ...[
          Align(alignment: Alignment.centerLeft, child: Pill(r.isPending ? s.reviewPending : s.reviewRejected)),
          const SizedBox(height: 14),
        ],
        Text(s.yourRate, style: AppText.sans(13.5, color: AppColors.sand600)),
        const SizedBox(height: 8),
        Stars(r.rating, size: 26),
        const SizedBox(height: 16),
        Text(Dates.long(r.createdAt), style: AppText.sans(13.5, color: AppColors.sand700)),
        if (r.visitType != null || month != null) ...[
          const SizedBox(height: 18),
          Text(s.kindOfVisit, style: AppText.sans(13.5, color: AppColors.sand600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (r.visitType != null) _Chip(visitTypeLabel(s, r.visitType!)),
              if (month != null) _Chip(Dates.monthYear(month), outlined: true),
            ],
          ),
        ],
        if (r.title != null && r.title!.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            r.title!,
            style: AppText.sans(18, weight: FontWeight.w700, color: AppColors.sand900),
          ),
        ],
        if (r.content != null && r.content!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(r.content!, style: AppText.sans(14.5, color: AppColors.sand700, height: 1.6)),
        ],
        for (final photo in r.photos) ...[
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: AppImage(photo.url, radius: BorderRadius.circular(16)),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.outlined = false});
  final String text;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: outlined ? Colors.white : AppColors.violet,
        borderRadius: BorderRadius.circular(99),
        border: outlined ? Border.all(color: AppColors.sand300) : null,
      ),
      child: Text(
        text,
        style: AppText.sans(12.5, weight: FontWeight.w600, color: outlined ? AppColors.sand700 : Colors.white),
      ),
    );
  }
}
