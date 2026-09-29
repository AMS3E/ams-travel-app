import 'dart:math' as math;

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

/// Colour of each tier's medal.
const tierColors = <Tier, Color>{
  Tier.bronze: Color(0xFFB45309),
  Tier.silver: Color(0xFF94A3B8),
  Tier.gold: Color(0xFFE0922F),
  Tier.platinum: Color(0xFF6B7BA8),
};

/// The scalloped medal with a star in the middle.
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({super.key, required this.tier, this.size = 56, this.muted = false});
  final Tier tier;
  final double size;

  /// Grey, for a tier that is not reached yet.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colour = muted ? AppColors.sand300 : (tierColors[tier] ?? AppColors.sand400);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RosettePainter(colour),
        child: Center(
          child: Icon(Icons.star_outline_rounded, size: size * 0.5, color: Colors.white),
        ),
      ),
    );
  }
}

/// The scalloped disc behind the star: a circle with a wavy edge.
class _RosettePainter extends CustomPainter {
  const _RosettePainter(this.colour);
  final Color colour;

  static const _points = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final path = Path();
    const steps = 360;
    for (var i = 0; i <= steps; i++) {
      final angle = i * 2 * math.pi / steps;
      final wave = 1 + 0.09 * math.cos(_points * angle);
      final r = radius * wave / 1.09;
      final point = centre + Offset(math.cos(angle) * r, math.sin(angle) * r);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_RosettePainter old) => old.colour != colour;
}

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
                itemBuilder: (_, i) => _BadgeCard(
                  badge: badges[i],
                  onTap: () => context.push(Routes.badgeTiers(badges[i].key)),
                ),
              ),
            ],
          );
        },
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.currentStatus, style: AppText.sans(11.5, color: AppColors.sand500)),
          const SizedBox(height: 2),
          Text(
            '${badge.tier.label(s)} ${badge.name}',
            style: AppText.sans(19, weight: FontWeight.w700, color: AppColors.violet),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BadgeMedal(tier: badge.tier, size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(badge.blurb, style: AppText.sans(12.5, color: AppColors.sand600, height: 1.4)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: badge.progress,
                        minHeight: 7,
                        backgroundColor: Colors.white,
                        valueColor: const AlwaysStoppedAnimation(AppColors.sand900),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      next == null
                          ? s.topTierReached
                          : '${(badge.progress * 100).round()}% ${s.ofTheWayTo} ${next.label(s)}',
                      style: AppText.sans(11.5, color: AppColors.sand500),
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
            BadgeMedal(tier: badge.tier, size: 40),
            const SizedBox(height: 12),
            Text(
              badge.name,
              style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900, height: 1.25),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${badge.count} ${badge.shortUnit}',
              style: AppText.sans(11.5, color: AppColors.sand500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
