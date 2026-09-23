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

/// Tiers a badge climbs through as the traveller uses the app.
enum Tier { bronze, silver, gold, platinum }

extension TierName on Tier {
  String label(S s) => switch (this) {
    Tier.bronze => s.bronzeTier,
    Tier.silver => s.silverTier,
    Tier.gold => s.goldTier,
    Tier.platinum => s.platinumTier,
  };
}

/// One badge: what it counts, how far along it is and what comes next.
class TravelBadge {
  const TravelBadge({
    required this.key,
    required this.icon,
    required this.name,
    required this.blurb,
    required this.note,
    required this.count,
    required this.unit,
    required this.shortUnit,
    required this.steps,
  });

  /// 'browser', 'reviewer' or 'adventure'.
  final String key;

  final IconData icon;
  final String name;

  /// One line under the name in the badge sheet.
  final String blurb;

  /// How the count is made, spelled out at the foot of the sheet.
  final String note;

  /// Places opened, reviews written or stamps collected.
  final int count;

  /// What the count is measured in ("pages browsed"), and the short form used
  /// on the tier lines ("300+ browse").
  final String unit;
  final String shortUnit;

  /// What each tier asks for: bronze, silver, gold, platinum.
  final List<int> steps;

  int stepFor(Tier t) => steps[t.index];

  Tier get tier {
    var reached = Tier.bronze;
    for (final t in Tier.values) {
      if (count >= steps[t.index]) reached = t;
    }
    return reached;
  }

  Tier? get next => switch (tier) {
    Tier.bronze => Tier.silver,
    Tier.silver => Tier.gold,
    Tier.gold => Tier.platinum,
    Tier.platinum => null,
  };

  int get target => steps[(tier.index + 1).clamp(0, steps.length - 1)];

  /// How far into the current tier, 0 to 1.
  double get progress => next == null ? 1 : (count / target).clamp(0, 1).toDouble();

  int get remaining => (target - count).clamp(0, target);
}

/// The three badges, with whatever the traveller has done so far.
List<TravelBadge> buildBadges(S s, {required int browsed, required int reviews, required int stamps}) => [

            TravelBadge(
              key: 'browser',
              icon: Icons.explore_outlined,
              name: s.browserBadge,
              blurb: s.browserBadgeBlurb,
              note: s.browseNote,
              count: browsed,
              unit: s.browseUnit,
              shortUnit: s.browseShort,
              steps: const [0, 300, 800, 1000],
            ),
            TravelBadge(
              key: 'reviewer',
              icon: Icons.star_outline_rounded,
              name: s.reviewerBadge,
              blurb: s.reviewerBadgeBlurb,
              note: s.reviewNote,
              count: reviews,
              unit: s.reviewsWord,
              shortUnit: s.reviewsWord,
              steps: const [0, 50, 400, 1000],
            ),
            TravelBadge(
              key: 'adventure',
              icon: Icons.landscape_outlined,
              name: s.adventureBadge,
              blurb: s.adventureBadgeBlurb,
              note: s.stampNote,
              count: stamps,
              unit: s.digitalStamps,
              shortUnit: s.digitalStamps,
              steps: const [0, 50, 200, 1000],
            ),
          
];

/// The traveller's badges: the strongest one on top, then every category.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final browsed = context.watch<BrowseCounter>().count;
    final stamps = context.watch<StampsProvider>();
    final author = context.select<AuthProvider, String?>((a) => a.user?.username);

    return Scaffold(
      appBar: AppBar(title: Text(s.badges, style: AppText.display(22)), centerTitle: true),
      body: FutureBuilder<List<Review>>(
        future: author == null
            ? Future.value(const <Review>[])
            : context.read<TravelRepository>().getMyReviews(author),
        builder: (context, snap) {
          final badges = buildBadges(s, browsed: browsed, reviews: snap.data?.length ?? 0, stamps: stamps.count);
          // Note the day each tier was first reached, for the achievement page.
          final log = context.read<BadgeLog>();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            for (final b in badges) {
              for (final t in Tier.values) {
                if (t != Tier.bronze && b.count >= b.stepFor(t)) log.record(b.key, t.name);
              }
            }
          });

          // The badge furthest along is the one shown as the current status.
          final leader = badges.reduce((a, b) => b.count > a.count ? b : a);

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + MediaQuery.paddingOf(context).bottom),
            children: [
              GestureDetector(
                onTap: () => context.push(Routes.achievement(leader.key)),
                child: _Status(badge: leader),
              ),
              const SizedBox(height: 24),
              Text(s.badgeCategories, style: AppText.display(18)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 178,
                ),
                itemCount: badges.length,
                itemBuilder: (_, i) => _BadgeCard(badge: badges[i], onTap: () => _showTiers(context, badges[i])),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// What each tier of this badge asks for, which are earned, and how the count
/// is made.
void _showTiers(BuildContext context, TravelBadge badge) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (_) => _BadgeSheet(badge: badge),
  );
}

class _BadgeSheet extends StatelessWidget {
  const _BadgeSheet({required this.badge});
  final TravelBadge badge;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final next = badge.next;
    final status = badge.count == 0 ? s.notStarted : badge.tier.label(s);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.sand100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(badge.icon, size: 22, color: AppColors.sand700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(badge.name, style: AppText.display(19)),
                      const SizedBox(height: 2),
                      Text(badge.blurb, style: AppText.sans(13, color: AppColors.sand500)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.brand600,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Where the traveller stands right now.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        status,
                        style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.sand900),
                      ),
                      const Spacer(),
                      Text('${badge.count} ${badge.unit}', style: AppText.sans(13, color: AppColors.sand600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: badge.progress,
                      minHeight: 6,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation(AppColors.brand600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    next == null ? s.topTierReached : '${badge.remaining} ${s.moreToReach} ${next.label(s)}.',
                    style: AppText.sans(12.5, color: AppColors.sand500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Text(s.tiers.toUpperCase(), style: AppText.eyebrow(color: AppColors.sand500)),
            const SizedBox(height: 8),
            for (final t in [Tier.silver, Tier.gold, Tier.platinum]) ...[
              _TierRow(badge: badge, tier: t),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.sand100, borderRadius: BorderRadius.circular(14)),
              child: Text(badge.note, style: AppText.sans(13, color: AppColors.sand600, height: 1.45)),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.keepExploring,
                    style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.brand600),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.brand600),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tier: what it asks for, and how far off it is.
class _TierRow extends StatelessWidget {
  const _TierRow({required this.badge, required this.tier});
  final TravelBadge badge;
  final Tier tier;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final need = badge.stepFor(tier);
    final earned = badge.count >= need;
    // Only the next tier tells you how far off it is; the rest read "locked".
    final isNext = !earned && badge.next == tier;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: earned ? AppColors.brand50 : AppColors.sand100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              earned ? Icons.check_rounded : Icons.lock_outline_rounded,
              size: 18,
              color: earned ? AppColors.brand600 : AppColors.sand500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tier.label(s)} ${s.badgeWord}',
                  style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.sand900),
                ),
                Text('$need+ ${badge.shortUnit}', style: AppText.sans(12.5, color: AppColors.sand500)),
              ],
            ),
          ),
          Text(
            earned
                ? s.earned
                : isNext
                ? '${need - badge.count} ${s.toGo}'
                : s.locked,
            style: AppText.sans(
              13,
              weight: isNext ? FontWeight.w700 : FontWeight.w400,
              color: earned ? AppColors.success : AppColors.sand500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.badge});
  final TravelBadge badge;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final next = badge.next;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.sand100,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.currentStatus, style: AppText.sans(12.5, color: AppColors.sand500)),
          const SizedBox(height: 4),
          Text('${badge.tier.label(s)} ${badge.name}', style: AppText.display(24)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Icon(badge.icon, color: AppColors.brand600, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next == null
                          ? s.topTierReached
                          : '${badge.remaining} ${s.moreToReach} ${next.label(s)}',
                      style: AppText.sans(13.5, color: AppColors.sand600, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: badge.progress,
                        minHeight: 8,
                        backgroundColor: Colors.white,
                        valueColor: const AlwaysStoppedAnimation(AppColors.sand900),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(badge.progress * 100).round()}% · ${badge.count}/${badge.target}',
                      style: AppText.sans(12, color: AppColors.sand500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge, required this.onTap});
  final TravelBadge badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Icon(badge.icon, size: 21, color: AppColors.sand900),
            ),
            const SizedBox(height: 12),
            Text(
              badge.name,
              style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900, height: 1.25),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text('${badge.count}', style: AppText.sans(12, color: AppColors.sand500)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.sand200),
              ),
              child: Text(
                badge.tier.label(s),
                style: AppText.sans(11.5, weight: FontWeight.w600, color: AppColors.sand700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
