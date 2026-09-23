import 'dart:ui';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/opening_hours.dart';
import '../data/models/models.dart';
import '../state/collections_provider.dart';
import '../state/locale_provider.dart';
import 'app_image.dart';
import 'common.dart';

/// Whether place names appear in both languages. Off until the bilingual
/// release: every screen shows one name, though the Khmer names stay in the
/// data and search still matches them. One flip brings them all back.
const showKhmerNames = false;

/// Title + secondary line. With [showKhmerNames] on, Khmer mode puts the Khmer
/// name first and English underneath, and English mode the other way round.
(String, String?) bilingual(BuildContext context, String en, String? kh) {
  if (!showKhmerNames) return (en, null);
  final km = context.watch<LocaleProvider>().isKhmer;
  if (km && kh != null && kh.isNotEmpty) return (kh, en);
  return (en, kh);
}

class SaveButton extends StatelessWidget {
  const SaveButton({
    super.key,
    required this.kind,
    required this.itemKey,
    this.onImage = true,
    this.dark = false,
    this.size = 37,
  });

  final SavedKind kind;
  final String itemKey;
  final bool onImage;

  /// Dark frosted circle with a white heart — used on place-card photos.
  final bool dark;

  /// Diameter of the round button when [onImage].
  final double size;

  @override
  Widget build(BuildContext context) {
    final saved = context.select<SavedProvider, bool>((p) => p.isSaved(kind, itemKey));
    final idle = dark ? Colors.white : (onImage ? AppColors.sand900 : AppColors.sand700);
    final icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        key: ValueKey(saved),
        size: dark ? 23 : 21,
        color: saved ? AppColors.sunset500 : idle,
      ),
    );
    void onTap() {
      final s = S.read(context);
      final nowSaved = context.read<SavedProvider>().toggle(kind, itemKey);
      showToast(context, nowSaved ? s.savedToList : s.removedFromList);
    }

    if (!onImage) {
      return IconButton(onPressed: onTap, icon: icon, tooltip: S.of(context).save);
    }
    final button = Material(
      color: dark ? Colors.black.withValues(alpha: 0.32) : Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Center(child: icon),
        ),
      ),
    );
    if (!dark) return button;
    return ClipOval(
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: button),
    );
  }
}

/// Place card: photo with category label and heart, then name, open status,
/// rating, hours and province.
class DestinationCard extends StatelessWidget {
  const DestinationCard({super.key, required this.destination, this.badge, this.rating, this.bestTime, this.width});

  final Destination destination;

  /// Overrides the "Featured" badge (Home's "Most visited", "Off the trail"…).
  final String? badge;

  /// Fallback rating when the place itself has none.
  final double? rating;
  final String? bestTime;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    final r = d.rating ?? rating;
    final status = openStatus(d);
    final hours = formatHours(d);
    final badges = <Widget>[
      if (badge != null) Pill.onImage(badge!) else if (d.featured) Pill.onImage(s.featured),
      if (d.unesco) Pill.accent(s.unesco, icon: Icons.account_balance_rounded),
    ];
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
            onTap: () => context.push(Routes.destination(d.region, d.slug)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1.6,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(tag: 'dest-${d.key}', child: AppImage(d.image)),
                      if (badges.isNotEmpty)
                        Positioned(
                          left: 12,
                          top: 12,
                          right: 64,
                          child: Wrap(spacing: 6, runSpacing: 6, children: badges),
                        ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: SaveButton(kind: SavedKind.destination, itemKey: d.key, dark: true, size: 44),
                      ),
                      Positioned(left: 12, bottom: 12, right: 12, child: _ImageLabel(d.category)),
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
                              title,
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
                          Expanded(
                            child: _StatusLabel(status: status, open24h: d.open24h, style: muted),
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
                                  if (d.reviewCount != null) TextSpan(text: ' (${d.reviewCount})', style: muted),
                                ],
                              ),
                            )
                          else
                            Text(s.noReviews, style: AppText.sans(13, color: AppColors.sand400)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (hours != null) ...[
                            const Icon(Icons.schedule_rounded, size: 16, color: AppColors.sand400),
                            const SizedBox(width: 5),
                            Text(hours, style: muted),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Row(
                              mainAxisAlignment: hours != null ? MainAxisAlignment.end : MainAxisAlignment.start,
                              children: [
                                const Icon(Icons.place_outlined, size: 16, color: AppColors.sand400),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(d.province, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (bestTime != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.sunset500),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${s.bestTime} · $bestTime',
                                style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.sand700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
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

/// "● Open" / "● Closed" / "● Open 24 hours"; nothing when hours are unknown.
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status, required this.open24h, required this.style});
  final OpenStatus status;
  final bool open24h;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (status == OpenStatus.unknown) return const SizedBox.shrink();
    final s = S.of(context);
    final isOpen = status == OpenStatus.open;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isOpen ? const Color(0xFF22C55E) : AppColors.sunset500,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            open24h ? s.open24h : (isOpen ? s.openNow : s.closedNow),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Slim list row: thumbnail, name, rating stars, category · province and the
/// first line of the description. Used where a list has to stay compact.
class PlaceRow extends StatelessWidget {
  const PlaceRow({super.key, required this.destination, this.onTap});

  final Destination destination;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return InkWell(
      onTap: onTap ?? () => context.push(Routes.destination(d.region, d.slug)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(d.image, width: 72, height: 72, radius: BorderRadius.circular(12)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.sans(15.5, weight: FontWeight.w700, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  if (d.rating != null)
                    Stars(d.rating!.round(), size: 14)
                  else
                    Text(s.noReviews, style: AppText.sans(11.5, color: AppColors.sand400)),
                  const SizedBox(height: 3),
                  Text(
                    '${d.category}  ·  ${d.province}',
                    style: AppText.sans(12.5, color: AppColors.sand500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    d.blurb,
                    style: AppText.sans(13, color: AppColors.sand600, height: 1.35),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 6, top: 24),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact row: thumbnail, name, province · category.
class DestinationTile extends StatelessWidget {
  const DestinationTile({super.key, required this.destination, this.trailing, this.caption, this.onTap});

  final Destination destination;
  final Widget? trailing;

  /// Extra line under the meta row ("3 km away", "Stamped 12 Sep").
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    final (title, _) = bilingual(context, d.name, d.nameKh);
    return InkWell(
      onTap: onTap ?? () => context.push(Routes.destination(d.region, d.slug)),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            AppImage(d.image, width: 76, height: 76, radius: BorderRadius.circular(14)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.category.toUpperCase(),
                    style: AppText.sans(
                      10.5,
                      weight: FontWeight.w600,
                      color: AppColors.brand600,
                    ).copyWith(letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: AppText.sans(15.5, weight: FontWeight.w600, color: AppColors.sand900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 14, color: AppColors.sand400),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          caption == null ? d.province : '${d.province}  ·  $caption',
                          style: AppText.sans(12.5, color: AppColors.sand500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
