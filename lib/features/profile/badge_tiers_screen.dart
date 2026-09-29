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
import '../../state/collections_provider.dart';
import 'badges_screen.dart';

/// The tiers of one badge, highest first. A tier only opens once the one
/// below it is complete.
class BadgeTiersScreen extends StatelessWidget {
  const BadgeTiersScreen({super.key, required this.badgeKey});
  final String badgeKey;

  /// Bronze is where everyone starts, so the ladder itself is these three.
  static const ladder = [Tier.platinum, Tier.gold, Tier.silver];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final browsed = context.watch<BrowseCounter>().count;
    final stamps = context.watch<StampsProvider>();
    final author = context.select<AuthProvider, String?>((a) => a.user?.username);

    return Scaffold(
      appBar: AppBar(title: Text(s.badges, style: AppText.display(20)), centerTitle: true),
      body: FutureBuilder<List<Review>>(
        future: author == null
            ? Future.value(const <Review>[])
            : context.read<TravelRepository>().getMyReviews(author),
        builder: (context, snap) {
          final badges = buildBadges(
            s,
            browsed: browsed,
            reviews: snap.data?.length ?? 0,
            stamps: stamps.count,
          );
          final badge = badges.firstWhere((b) => b.key == badgeKey, orElse: () => badges.first);

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 28 + MediaQuery.paddingOf(context).bottom),
            children: [
              Text(badge.name, style: AppText.display(20)),
              const SizedBox(height: 4),
              Text(badge.blurb, style: AppText.sans(13, color: AppColors.sand500)),
              const SizedBox(height: 16),
              for (final tier in ladder) ...[
                _TierCard(badge: badge, tier: tier),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sand100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(badge.note, style: AppText.sans(13, color: AppColors.sand600, height: 1.45)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One rung of the ladder: what it asks for, whether it is open yet, and how
/// far along it is.
class _TierCard extends StatelessWidget {
  const _TierCard({required this.badge, required this.tier});
  final TravelBadge badge;
  final Tier tier;

  /// The tier below this one, which has to be finished first.
  Tier get _below => Tier.values[tier.index - 1];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final target = badge.stepFor(tier);
    final earned = badge.count >= target;
    // Silver opens from the start; the rest wait for the tier below.
    final open = tier == Tier.silver || badge.count >= badge.stepFor(_below);
    final progress = (badge.count / target).clamp(0, 1).toDouble();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: earned ? () => context.push(Routes.achievement(badge.key)) : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: earned ? AppColors.violet.withValues(alpha: 0.4) : AppColors.sand200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BadgeMedal(tier: tier, size: 40, muted: !open),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.label(s),
                        style: AppText.sans(
                          15,
                          weight: FontWeight.w700,
                          color: open ? AppColors.sand900 : AppColors.sand500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        open
                            ? '>$target ${badge.shortUnit} ${s.requiredWord}'
                            : s.completeFirst.replaceFirst('{tier}', _below.label(s)),
                        style: AppText.sans(12, color: AppColors.sand500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (earned)
                  const Icon(Icons.check_circle_rounded, size: 24, color: AppColors.violet)
                else if (open)
                  const Icon(Icons.circle_outlined, size: 24, color: AppColors.sand300)
                else
                  const Icon(Icons.lock_outline_rounded, size: 22, color: AppColors.sand300),
              ],
            ),
            const SizedBox(height: 12),
            Text(s.progressLabel, style: AppText.sans(11.5, color: AppColors.sand500)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: open ? progress : 0,
                      minHeight: 7,
                      backgroundColor: AppColors.sand100,
                      valueColor: const AlwaysStoppedAnimation(AppColors.violet),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${badge.count.clamp(0, target)} / $target',
                  style: AppText.sans(11.5, weight: FontWeight.w600, color: AppColors.sand600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
