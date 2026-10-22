import 'dart:ui';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/sign_in.dart';
import '../data/api/catalog.dart';
import '../state/collections_provider.dart';
import 'app_image.dart';
import 'common.dart';
import 'open_status.dart';

class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.kind, required this.itemKey, this.onImage = true, this.size = 37});

  final SavedKind kind;
  final String itemKey;

  /// On a photo: a white heart in a frosted glass circle, like the other
  /// round buttons on photos ([GlassIconButton]).
  final bool onImage;

  /// Diameter of the round button when [onImage].
  final double size;

  @override
  Widget build(BuildContext context) {
    final saved = context.select<SavedProvider, bool>((p) => p.isSaved(kind, itemKey));
    final icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        key: ValueKey(saved),
        size: size < 36 ? 19 : 21,
        color: saved ? AppColors.sunset500 : (onImage ? GlassScope.iconColor(context) : AppColors.sand700),
      ),
    );
    void onTap() {
      final s = S.read(context);
      whenSignedIn(context, s.logInToSave, () async {
        try {
          final nowSaved = await context.read<SavedProvider>().toggle(kind, itemKey);
          if (context.mounted) showToast(context, nowSaved ? s.savedToList : s.removedFromList);
        } catch (e) {
          if (context.mounted) showToast(context, e.toString());
        }
      });
    }

    if (!onImage) {
      return IconButton(onPressed: onTap, icon: icon, tooltip: S.of(context).save);
    }
    final button = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: size,
        child: Center(child: icon),
      ),
    );
    return (GlassScope.maybeOf(context)?.grouped ?? false) ? button : Glass(child: button);
  }
}

/// Place card: photo with category label and heart, then name, rating and
/// province. Works for every kind of card.
class DestinationCard extends StatelessWidget {
  const DestinationCard({super.key, required this.card, this.badge, this.width});

  final PlaceCard card;

  /// A label on the photo ("Most visited").
  final String? badge;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = card;
    final r = d.averageRating;
    final muted = AppText.sans(14, color: AppColors.sand500);

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x141C1935), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(Routes.card(d)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1.6,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(tag: 'card-${d.id}', child: AppImage(d.coverUrl)),
                      if (badge != null) Positioned(left: 12, top: 12, right: 64, child: Pill.onImage(badge!)),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: SaveButton(kind: SavedKind.of(d.type), itemKey: d.id, size: 44),
                      ),
                      if (d.categoryNames.isNotEmpty)
                        Positioned(left: 12, bottom: 12, right: 12, child: _ImageLabel(d.categoryNames.first)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.name,
                              style: AppText.sans(18, weight: FontWeight.w700, color: AppColors.sand900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (d.verified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, size: 18, color: AppColors.brand500),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 16, color: AppColors.sand400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              d.provinceName ?? '',
                              style: muted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (r != null)
                            Text.rich(
                              TextSpan(
                                children: [
                                  const WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Icon(Icons.star_rounded, size: 19, color: AppColors.star),
                                  ),
                                  TextSpan(
                                    text: ' ${r.toStringAsFixed(1)}',
                                    style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                                  ),
                                  if (d.reviewCount > 0) TextSpan(text: ' (${d.reviewCount})', style: muted),
                                ],
                              ),
                            )
                          else
                            Text(s.noReviews, style: AppText.sans(13, color: AppColors.sand400)),
                        ],
                      ),
                      if (OpenStatusLine.shows(d)) ...[const SizedBox(height: 8), OpenStatusLine(card: d, size: 14)],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted dark label on the photo ("Restaurant", "Temples").
class _ImageLabel extends StatelessWidget {
  const _ImageLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.black.withValues(alpha: 0.38),
            child: Text(
              text,
              style: AppText.sans(14, weight: FontWeight.w500, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
