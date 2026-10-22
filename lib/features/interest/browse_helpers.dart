import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/open_status.dart';
import '../../widgets/overview_card.dart';
import '../../widgets/app_image.dart';
import '../../widgets/async_view.dart';

/// A server search shown page after page. Give it a new `key` when the
/// filters change, so it starts again from the first page.
class PagedCards extends StatefulWidget {
  const PagedCards({super.key, required this.load, required this.builder, this.initial, this.empty});

  /// One page of the search, from 0.
  final Future<PageOf<PlaceCard>> Function(int page) load;

  /// The cards so far, the server's total, and a "Show more" button while
  /// there are pages left (else null).
  final Widget Function(BuildContext context, List<PlaceCard> cards, int total, Widget? more) builder;

  /// The first page, when the screen already has it.
  final PageOf<PlaceCard>? initial;

  /// Shown when the search finds nothing.
  final Widget? empty;

  @override
  State<PagedCards> createState() => _PagedCardsState();
}

class _PagedCardsState extends State<PagedCards> {
  final _cards = <PlaceCard>[];
  int _total = 0;
  int _page = -1;
  bool _last = false;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final first = widget.initial;
    if (first != null) {
      _take(first);
    } else {
      _more();
    }
  }

  void _take(PageOf<PlaceCard> page) {
    _cards.addAll(page.content);
    _total = page.totalElements;
    _page = page.number;
    _last = page.isLast || page.content.isEmpty;
  }

  Future<void> _more() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.load(_page + 1);
      if (mounted) {
        setState(() {
          _take(page);
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      if (_error != null) return ErrorView(error: _error!, onRetry: _more);
      if (_busy || _page < 0) return const LoadingView();
      return widget.empty ?? const SizedBox.shrink();
    }
    final s = S.of(context);
    final Widget? more = _last
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Center(
              child: _busy
                  ? const LoadingView(padding: EdgeInsets.all(8))
                  : TextButton(
                      onPressed: _more,
                      child: Text(
                        s.showMore,
                        style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.violet),
                      ),
                    ),
            ),
          );
    return widget.builder(context, _cards, _total, more);
  }
}

/// The white rounded panel the browse lists sit in.
class BrowsePanel extends StatelessWidget {
  const BrowsePanel({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    // The orange-to-violet border of the place pages' cards.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: GradientFrame(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
              ),
              const SizedBox(height: 6),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// One card in a two-column grid: photo, name, and what kind of place it is.
class PlaceTile extends StatelessWidget {
  const PlaceTile({super.key, required this.card});
  final PlaceCard card;

  @override
  Widget build(BuildContext context) {
    final d = card;
    final detail = d.categoryNames.isNotEmpty ? d.categoryNames.join(', ') : (d.provinceName ?? '');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(Routes.card(d)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 58, height: 58, child: AppImage(d.coverUrl, radius: BorderRadius.circular(12))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: AppText.sans(13, weight: FontWeight.w700, color: AppColors.sand900, height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (OpenStatusLine.shows(d)) ...[
                  const SizedBox(height: 3),
                  OpenStatusLine(card: d, size: 11.5),
                ] else if (detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: AppText.sans(11.5, color: AppColors.sand500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
