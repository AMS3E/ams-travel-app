import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/auth_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import 'badges_screen.dart';
import '../../core/utils/dates.dart';

/// What the achievement page reads: the definitions (`GET /badges`), the
/// badges earned (`GET /badges/me/earned`) and the season.
class _Achievements {
  _Achievements(this.definitions, this.earned, this.season);
  final List<BadgeDefinition> definitions;
  final List<UserBadge> earned;
  final Season? season;

  /// The earned row with this id, for a page opened on one particular earn.
  UserBadge? byId(String? id) => id == null ? null : earned.where((b) => b.id == id).firstOrNull;

  UserBadge? earnedOf(BadgeDefinition d) => earned.where((b) => b.isFor(d)).firstOrNull;

  /// [key] is a badge code (BROWSER_GOLDEN), or a track type (BROWSES): the
  /// highest level earned on that track, else its first level.
  BadgeDefinition? resolve(String key) {
    final byCode = definitions.where((d) => d.code == key).firstOrNull;
    if (byCode != null) return byCode;
    final track = definitions.where((d) => d.type == key).toList()..sort((a, b) => a.threshold.compareTo(b.threshold));
    if (track.isEmpty) return null;
    return track.lastWhere((d) => earnedOf(d) != null, orElse: () => track.first);
  }
}

/// One badge on its own page: the level, when it was earned and in which
/// season, a way to share it, and the history of badges and seasons.
class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key, required this.badgeKey, this.earnedId});

  /// A badge code such as BROWSER_GOLDEN, or a track type such as BROWSES.
  final String badgeKey;

  /// One earned row (`GET /badges/me/earned` id), from the badge history or
  /// a past season: that earn, its date, season and share link.
  final String? earnedId;

  Future<_Achievements> _load(AmsApi api) async {
    final (definitions, earned, season) = await (api.badges(), api.earnedBadges(), api.currentSeason().orNull).wait;
    return _Achievements(definitions, earned, season);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final signedIn = context.select<AuthProvider, bool>((a) => a.isSignedIn);

    return Scaffold(
      appBar: AppBar(title: Text(s.achievement, style: AppText.display(20)), centerTitle: true),
      body: !signedIn
          ? const BadgesSignIn()
          : AsyncView<_Achievements>(
              load: () => _load(context.read<AmsApi>()),
              builder: (context, data, _) {
                final picked = data.byId(earnedId);
                final d = data.resolve(picked?.code ?? badgeKey);
                if (d == null) {
                  return EmptyState(icon: Icons.workspace_premium_outlined, title: s.achievement, body: s.noResults);
                }
                final mine = picked ?? data.earnedOf(d);
                // The current season's line belongs under a badge of this
                // season only.
                final current = picked == null || picked.seasonId == null || picked.seasonId == data.season?.id
                    ? data.season
                    : null;
                final earned = mine?.earned ?? false;
                final title = '${levelLabel(s, d.level)} ${trackLabel(s, d.type, fallback: d.name)}';
                final seasonName = mine?.seasonName ?? data.season?.name;

                return ListView(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset(context)),
                  children: [
                    Center(
                      child: BadgeMedal(level: d.level, size: 150, muted: !earned),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: Text(
                        earned ? s.badgeEarned : s.badgeInProgress,
                        style: AppText.sans(13, color: AppColors.sand500),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(title, style: AppText.display(28), textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        earned && mine!.earnedAt != null
                            ? '${s.earnedOn} ${Dates.long(mine.earnedAt!)}${seasonName == null ? '' : ' · $seasonName'}'
                            : '${d.threshold} ${trackUnit(s, d.type)} ${s.requiredWord}',
                        style: AppText.sans(13, color: AppColors.sand500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (d.description != null && d.description!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        d.description!,
                        textAlign: TextAlign.center,
                        style: AppText.sans(13.5, color: AppColors.sand600, height: 1.5),
                      ),
                    ],
                    if (earned) ...[
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.violet,
                          minimumSize: const Size(0, 54),
                        ),
                        // The badge's public page (`shareUrl`) carries the card
                        // Facebook shows.
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            text: [
                              s.fill(s.shareBadgeText, {'badge': title, 'season': seasonName ?? ''}),
                              ?mine?.shareUrl,
                            ].join('\n'),
                            subject: title,
                          ),
                        ),
                        icon: const Icon(Icons.ios_share_rounded, size: 20, color: Colors.white),
                        label: Text(
                          s.shareBadge,
                          style: AppText.sans(15.5, weight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ],
                    if (current != null) ...[const SizedBox(height: 18), Center(child: SeasonLine(season: current))],
                    const SizedBox(height: 8),
                    Center(
                      child: _Link(label: s.viewTerms, onTap: () => context.push(Routes.terms)),
                    ),
                    const SizedBox(height: 22),
                    const Divider(color: AppColors.sand200),
                    const SizedBox(height: 18),
                    Center(
                      child: _Link(label: s.viewBadgeHistory, onTap: () => _history(context, data.earned)),
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// The badges earned, newest first under the season they were earned in
  /// (the list mixes seasons), then each season's totals
  /// (`GET /seasons/me/history`). A badge opens on its own earn, so an old
  /// one can still be shared.
  void _history(BuildContext context, List<UserBadge> earned) {
    final s = S.read(context);
    final api = context.read<AmsApi>();
    final page = context;
    final badges = [...earned]..sort((a, b) => (b.earnedAt ?? DateTime(0)).compareTo(a.earnedAt ?? DateTime(0)));
    final bySeason = <String?, List<UserBadge>>{};
    for (final b in badges) {
      (bySeason[b.seasonId] ??= []).add(b);
    }
    showListSheet(
      context,
      title: s.badgesEarned,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badges.isEmpty) Text(s.notYet, style: AppText.sans(14, color: AppColors.sand500)),
          for (final group in bySeason.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Text(
                group.first.seasonName ?? s.otherSeason,
                style: AppText.sans(12.5, weight: FontWeight.w700, color: AppColors.sand500),
              ),
            ),
            for (final b in group)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: BadgeMedal(level: b.level, size: 36),
                title: Text('${levelLabel(s, b.level)} ${trackLabel(s, b.type, fallback: b.name)}'),
                subtitle: b.earnedAt == null ? null : Text(Dates.short(b.earnedAt!)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(Routes.achievement(b.code, earned: b.id));
                },
              ),
          ],
          const SizedBox(height: 18),
          Text(s.seasonsWord, style: AppText.display(20)),
          const SizedBox(height: 8),
          AsyncView<List<SeasonProgress>>(
            load: api.seasonHistory,
            builder: (context, seasons, _) => seasons.isEmpty
                ? Text(s.noSeasonHistory, style: AppText.sans(14, color: AppColors.sand500))
                : Column(
                    children: [
                      for (final p in seasons)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_outlined, color: AppColors.violet),
                          title: Text(p.seasonName),
                          subtitle: Text(
                            s.fill(s.seasonTotals, {
                              'points': p.points,
                              'reviews': p.reviewCount,
                              'ratings': p.ratingCount,
                            }),
                          ),
                          trailing: p.past ? const Icon(Icons.chevron_right_rounded, color: AppColors.sand400) : null,
                          onTap: p.past
                              ? () {
                                  Navigator.of(context).pop();
                                  page.push(Routes.seasonBadges(p.seasonId));
                                }
                              : null,
                        ),
                    ],
                  ),
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
