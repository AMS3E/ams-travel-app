import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../data/api/ams_api.dart';
import '../../state/auth_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import 'badges_screen.dart';
import 'season_points.dart';

// When a season ends the API marks it COMPLETED and keeps what the traveller
// did in it. `GET /seasons/me/history` has their totals per season,
// `GET /badges/me/progress?seasonId=` a season's ladders as they were left,
// `GET /badges/me/earned` every badge across seasons, and `GET /seasons`
// (public) each season's dates. Everything here is read-only.

/// The seasons a past season page reads, keyed by id, from `GET /seasons`;
/// empty when that call fails (the pages then go without dates).
Future<Map<String, Season>> _seasonsById(AmsApi api) async => {
  for (final season in await api.seasons().orNull ?? const <Season>[]) season.id: season,
};

class _PastSeasons {
  const _PastSeasons(this.history, this.earned, this.seasons);

  /// Completed seasons the traveller took part in, newest first.
  final List<SeasonProgress> history;
  final List<UserBadge> earned;
  final Map<String, Season> seasons;

  List<UserBadge> earnedIn(String seasonId) => [
    for (final b in earned)
      if (b.seasonId == seasonId) b,
  ];

  // TODO R-070: browses, check-ins, the badge count and the dates on each
  // history row would make this one call.
  static Future<_PastSeasons> load(AmsApi api) async {
    final (history, earned, seasons) = await (api.seasonHistory(), api.earnedBadges().orNull, _seasonsById(api)).wait;
    return _PastSeasons(
      [
        for (final p in history)
          if (p.past) p,
      ],
      earned ?? const [],
      seasons,
    );
  }
}

/// Every season the traveller took part in that has ended, newest first, with
/// their points, counts and the badges they earned in it.
class PastSeasonsScreen extends StatelessWidget {
  const PastSeasonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final userId = context.select<AuthProvider, String?>((a) => a.userId);

    return Scaffold(
      appBar: AppBar(title: Text(s.pastSeasons, style: AppText.display(20)), centerTitle: true),
      body: userId == null
          ? const BadgesSignIn()
          : AsyncView<_PastSeasons>(
              key: ValueKey(userId),
              load: () => _PastSeasons.load(context.read<AmsApi>()),
              builder: (context, data, reload) => RefreshIndicator(
                onRefresh: reload,
                child: data.history.isEmpty
                    ? ListView(
                        children: [
                          EmptyState(icon: Icons.history_rounded, title: s.noPastSeasons, body: s.noPastSeasonsBody),
                        ],
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset(context)),
                        itemCount: data.history.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final p = data.history[i];
                          return _PastSeasonCard(
                            totals: p,
                            season: data.seasons[p.seasonId],
                            earned: data.earnedIn(p.seasonId),
                            onTap: () => context.push(Routes.seasonBadges(p.seasonId)),
                          );
                        },
                      ),
              ),
            ),
    );
  }
}

class _PastSeasonCard extends StatelessWidget {
  const _PastSeasonCard({required this.totals, required this.season, required this.earned, required this.onTap});
  final SeasonProgress totals;
  final Season? season;
  final List<UserBadge> earned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dates = seasonDates(season);
    final style = seasonStyle(s, totals.seasonType);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SeasonIcon(type: totals.seasonType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totals.seasonName,
                        style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                      ),
                      if (dates != null) Text(dates, style: AppText.sans(12, color: AppColors.sand600)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${totals.points}', style: AppText.display(26, color: style.color)),
                const SizedBox(width: 5),
                Text(
                  s.pointsWord,
                  style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.sand700),
                ),
              ],
            ),
            Text(
              s.fill(s.seasonActivity, {'reviews': totals.reviewCount, 'ratings': totals.ratingCount}),
              style: AppText.sans(12.5, color: AppColors.sand600),
            ),
            Text(
              s.fill(s.seasonPlaces, {'reviewed': totals.reviewedPlaceCount, 'rated': totals.ratedPlaceCount}),
              style: AppText.sans(12.5, color: AppColors.sand600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final b in earned.take(6))
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: BadgeMedal(level: b.level, size: 24),
                  ),
                if (earned.isNotEmpty) const SizedBox(width: 4),
                Text(
                  earned.isEmpty ? s.noBadgesThatSeason : s.badgeCountText(earned.length),
                  style: AppText.sans(12, weight: FontWeight.w600, color: AppColors.sand700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonBadges {
  const _SeasonBadges(this.board, this.totals);
  final BadgeBoard board;
  final SeasonProgress? totals;

  static Future<_SeasonBadges> load(AmsApi api, String seasonId) async {
    final (definitions, progress, seasons, history) = await (
      api.badges(),
      api.badgeProgress(seasonId: seasonId),
      _seasonsById(api),
      api.seasonHistory().orNull,
    ).wait;
    return _SeasonBadges(
      BadgeBoard(definitions: definitions, progress: progress, season: seasons[seasonId]),
      history?.where((p) => p.seasonId == seasonId).firstOrNull,
    );
  }
}

/// One season as it was left: its totals, each ladder's level and thresholds,
/// and the badges earned in it. Nothing here counts towards the current season.
class SeasonBadgesScreen extends StatelessWidget {
  const SeasonBadgesScreen({super.key, required this.seasonId});
  final String seasonId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final userId = context.select<AuthProvider, String?>((a) => a.userId);

    return Scaffold(
      appBar: AppBar(title: Text(s.badges, style: AppText.display(20)), centerTitle: true),
      body: userId == null
          ? const BadgesSignIn()
          : AsyncView<_SeasonBadges>(
              key: ValueKey(userId),
              load: () => _SeasonBadges.load(context.read<AmsApi>(), seasonId),
              builder: (context, data, _) {
                final board = data.board;
                final tracks = board.tracks;
                final earned = [...board.progress.earned]
                  ..sort((a, b) => (b.earnedAt ?? DateTime(0)).compareTo(a.earnedAt ?? DateTime(0)));

                return ListView(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset(context)),
                  children: [
                    _SeasonHeader(board: board, totals: data.totals),
                    const SizedBox(height: 24),
                    Text(s.levelsReached, style: AppText.display(18)),
                    const SizedBox(height: 12),
                    for (final t in tracks) ...[_PastTrack(track: t, board: board), const SizedBox(height: 12)],
                    const SizedBox(height: 12),
                    Text(s.badgesEarnedThisSeason, style: AppText.display(18)),
                    const SizedBox(height: 4),
                    if (earned.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(s.noBadgesThatSeason, style: AppText.sans(13.5, color: AppColors.sand500)),
                      ),
                    for (final b in earned)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: BadgeMedal(level: b.level, size: 36),
                        title: Text('${levelLabel(s, b.level)} ${trackLabel(s, b.type, fallback: b.name)}'),
                        subtitle: b.earnedAt == null ? null : Text('${s.earnedOn} ${Dates.long(b.earnedAt!)}'),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
                        // The badge's own page, with its share link.
                        onTap: () => context.push(Routes.achievement(b.code, earned: b.id)),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

/// The season's name, dates and status, the points with the counts behind
/// them, and where the traveller finished among members.
class _SeasonHeader extends StatelessWidget {
  const _SeasonHeader({required this.board, required this.totals});
  final BadgeBoard board;
  final SeasonProgress? totals;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final season = board.season;
    final totals = this.totals;
    final type = season?.type ?? totals?.seasonType;
    final style = seasonStyle(s, type);
    final name = season?.name ?? board.progress.seasonName ?? totals?.seasonName ?? '';
    final dates = seasonDates(season);
    final completed = (season?.status ?? totals?.seasonStatus) == 'COMPLETED';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.color.withValues(alpha: 0.14), style.color.withValues(alpha: 0.03)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: style.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SeasonIcon(type: type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                    ),
                    if (dates != null) Text(dates, style: AppText.sans(12, color: AppColors.sand600)),
                  ],
                ),
              ),
              if (completed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.sand200, borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    s.seasonCompleted,
                    style: AppText.sans(11, weight: FontWeight.w700, color: AppColors.sand700),
                  ),
                ),
            ],
          ),
          if (totals != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${totals.points}', style: AppText.display(34, color: style.color)),
                const SizedBox(width: 6),
                Text(
                  s.pointsWord,
                  style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.sand700),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              s.fill(s.seasonActivity, {'reviews': totals.reviewCount, 'ratings': totals.ratingCount}),
              style: AppText.sans(12.5, color: AppColors.sand600),
            ),
            Text(
              s.fill(s.seasonPlaces, {'reviewed': totals.reviewedPlaceCount, 'rated': totals.ratedPlaceCount}),
              style: AppText.sans(12.5, color: AppColors.sand600),
            ),
          ],
          if (board.progress.percentile case final top?) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined, size: 18, color: AppColors.sunset500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.fill(s.finishedTopPercent, {'n': top}),
                    style: AppText.sans(13, weight: FontWeight.w600, color: AppColors.sand800),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One ladder as the season left it: the level reached and the count, then
/// each level with its threshold, ticked when earned. A level started but not
/// finished (a badge row with no `earnedAt`) shows how far it got.
class _PastTrack extends StatelessWidget {
  const _PastTrack({required this.track, required this.board});
  final BadgeTrack track;
  final BadgeBoard board;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = trackLabel(s, track.type, fallback: board.nameOf(track.type));
    final defs = board.byType[track.type] ?? const <BadgeDefinition>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BadgeMedal(level: track.level, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.level == null ? name : '${levelLabel(s, track.level)} $name',
                      style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
                    ),
                    Text(
                      '${track.count} ${trackUnit(s, track.type)}',
                      style: AppText.sans(12, color: AppColors.sand500),
                    ),
                  ],
                ),
              ),
              Icon(trackIcon(track.type), size: 20, color: AppColors.sand400),
            ],
          ),
          const SizedBox(height: 10),
          for (final d in defs) _PastLevel(definition: d, row: board.mine(d), track: track),
        ],
      ),
    );
  }
}

class _PastLevel extends StatelessWidget {
  const _PastLevel({required this.definition, required this.row, required this.track});
  final BadgeDefinition definition;

  /// The traveller's row for this level in the season, if any.
  final UserBadge? row;
  final BadgeTrack track;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = definition;
    final earned = row?.earned ?? false;
    // The season's own threshold: the row's, else the track's, else today's
    // definition. TODO R-069: whether the API keeps a past season's thresholds.
    final target =
        (row != null && row!.threshold > 0 ? row!.threshold : null) ??
        (d.level == null ? null : track.thresholds[d.level]) ??
        d.threshold;
    final started = row != null && !earned;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BadgeMedal(level: d.level, size: 22, muted: !earned),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${d.level == null ? d.name : levelLabel(s, d.level)} · $target ${trackUnit(s, d.type)}',
                  style: AppText.sans(
                    12.5,
                    weight: FontWeight.w600,
                    color: earned ? AppColors.sand900 : AppColors.sand500,
                  ),
                ),
              ),
              if (earned)
                const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.violet)
              else
                const Icon(Icons.circle_outlined, size: 18, color: AppColors.sand300),
            ],
          ),
          if (started) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progressTo(row!.progress, target),
                        minHeight: 5,
                        backgroundColor: AppColors.sand100,
                        valueColor: const AlwaysStoppedAnimation(AppColors.sand400),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.fill(s.notFinishedProgress, {'n': row!.progress, 'target': target}),
                    style: AppText.sans(11, color: AppColors.sand500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
