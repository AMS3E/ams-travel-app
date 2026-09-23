import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/auth_provider.dart';
import '../../state/collections_provider.dart';
import 'badges_screen.dart';

/// One badge on its own page: the tier reached, when it was earned, and what
/// the season means for it.
class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key, required this.badgeKey});
  final String badgeKey;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final browsed = context.watch<BrowseCounter>().count;
    final stamps = context.watch<StampsProvider>();
    final log = context.watch<BadgeLog>();
    final author = context.select<AuthProvider, String?>((a) => a.user?.username);

    return Scaffold(
      appBar: AppBar(title: Text(s.achievement, style: AppText.display(20)), centerTitle: true),
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
          final earned = badge.count >= badge.stepFor(Tier.silver);
          final earnedOn = log.earnedOn(badge.key, badge.tier.name);
          final year = DateTime.now().year;

          return ListView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 28 + MediaQuery.paddingOf(context).bottom),
            children: [
              Center(child: _Medal(badge: badge)),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  earned ? s.badgeEarned : s.badgeInProgress,
                  style: AppText.sans(13, color: AppColors.sand500),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '${badge.tier.label(s)} ${badge.name}',
                  style: AppText.display(28),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  earnedOn != null
                      ? '${s.earnedOn} ${_date(earnedOn)}'
                      : '${badge.count} ${badge.unit}',
                  style: AppText.sans(13, color: AppColors.sand500),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  minimumSize: const Size(0, 54),
                ),
                // Facebook's share dialog takes the link; no SDK needed.
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent('https://ams-travel.netlify.app/')}',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.facebook_rounded, size: 20, color: Colors.white),
                label: Text(
                  s.shareToFacebook,
                  style: AppText.sans(15.5, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${s.badgeSeasonNote} $year.',
                textAlign: TextAlign.center,
                style: AppText.sans(13.5, color: AppColors.sand500, height: 1.5),
              ),
              const SizedBox(height: 8),
              Center(
                child: _Link(
                  label: s.viewTerms,
                  onTap: () => launchUrl(
                    Uri.parse('https://ams-travel.netlify.app/'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Divider(color: AppColors.sand200),
              const SizedBox(height: 18),
              Center(child: _Link(label: s.viewBadgeHistory, onTap: () => _history(context, badge, log))),
            ],
          );
        },
      ),
    );
  }

  /// Every tier of this badge, with the date it was reached.
  void _history(BuildContext context, TravelBadge badge, BadgeLog log) {
    final s = S.read(context);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.viewBadgeHistory, style: AppText.display(20)),
              const SizedBox(height: 12),
              for (final t in [Tier.silver, Tier.gold, Tier.platinum])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        log.earnedOn(badge.key, t.name) != null
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: log.earnedOn(badge.key, t.name) != null ? AppColors.success : AppColors.sand300,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${t.label(s)} ${s.badgeWord}',
                          style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sand900),
                        ),
                      ),
                      Text(
                        log.earnedOn(badge.key, t.name) == null
                            ? s.notYet
                            : _date(log.earnedOn(badge.key, t.name)!),
                        style: AppText.sans(13, color: AppColors.sand500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

/// Ring with the badge icon, filled as far as the tier reached.
class _Medal extends StatelessWidget {
  const _Medal({required this.badge});
  final TravelBadge badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 186,
      height: 186,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: badge.progress == 0 ? 0.02 : badge.progress,
              strokeWidth: 10,
              backgroundColor: AppColors.sand100,
              valueColor: const AlwaysStoppedAnimation(AppColors.brand600),
            ),
          ),
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(color: AppColors.brand50, shape: BoxShape.circle),
            child: Icon(badge.icon, size: 46, color: AppColors.brand600),
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppText.sans(
          14,
          weight: FontWeight.w600,
          color: AppColors.sand800,
        ).copyWith(decoration: TextDecoration.underline),
      ),
    );
  }
}
