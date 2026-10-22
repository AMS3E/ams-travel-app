import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/auth_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../auth/sign_in.dart' as auth;
import '../../core/utils/dates.dart';

// The badges come from the API: `GET /badges` (definitions and thresholds),
// `GET /badges/me/progress` (tracks, badges, earned) and `GET /seasons/current`.
// The API has three ladders, browses, reviews and stamps (the POINTS one was
// retired on 2026-10-20; points are a season total on the Profile tile), each
// SILVER, GOLDEN, PLATINUM; the screens show those as they are, GOLDEN
// written "Gold".

/// The tracks in the order the screens list them.
const trackOrder = ['BROWSES', 'REVIEWS', 'STAMPS', 'DESTINATION_STAMPS'];

/// "Browser badge", "Reviewer badge"…; [fallback] for a type the app has no
/// words for (the API's own badge name).
String trackLabel(S s, String type, {String? fallback}) => switch (type) {
  'BROWSES' => s.browserBadge,
  'REVIEWS' => s.reviewerBadge,
  'STAMPS' => s.adventureBadge,
  _ => fallback ?? type,
};

/// What a track counts, as the tier lines write it ("300 browse required").
String trackUnit(S s, String type) => switch (type) {
  'BROWSES' => s.browseShort,
  'REVIEWS' => s.reviewsWord,
  _ => s.digitalStamps,
};

IconData trackIcon(String type) => switch (type) {
  'BROWSES' => Icons.explore_outlined,
  'REVIEWS' => Icons.star_outline_rounded,
  _ => Icons.landscape_outlined,
};

/// SILVER → "Silver", GOLDEN → "Gold", PLATINUM → "Platinum"; none yet → "No badge yet".
String levelLabel(S s, BadgeLevel? level) => switch (level) {
  BadgeLevel.silver => s.silverTier,
  BadgeLevel.golden => s.goldTier,
  BadgeLevel.platinum => s.platinumTier,
  null => s.noLevelYet,
};

/// The track furthest along: the highest level, then the nearest to its next.
BadgeTrack? leadingTrack(List<BadgeTrack> tracks) {
  if (tracks.isEmpty) return null;
  double score(BadgeTrack t) {
    final reached = t.level == null ? 0 : t.level!.index + 1;
    final target = t.nextTarget;
    final part = target == null || target == 0 ? 0.0 : (t.count / target).clamp(0, 0.99).toDouble();
    return reached + part;
  }

  return tracks.reduce((a, b) => score(b) > score(a) ? b : a);
}

/// How far a track is towards its next level, 0 to 1 (1 at the top).
double trackFraction(BadgeTrack t) {
  final target = t.nextTarget;
  if (target == null) return t.level == null ? 0 : 1;
  return progressTo(t.count, target);
}

/// [count] out of [target], 0 to 1; a zero target counts as reached.
double progressTo(num count, int target) => target == 0 ? 1 : (count / target).clamp(0, 1).toDouble();

/// Colour of each level's medal.
const levelColors = <BadgeLevel, Color>{
  BadgeLevel.silver: Color(0xFF94A3B8),
  BadgeLevel.golden: Color(0xFFE0922F),
  BadgeLevel.platinum: Color(0xFF6B7BA8),
};

/// The scalloped medal with a star in the middle; grey with no level.
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({super.key, required this.level, this.size = 56, this.muted = false});
  final BadgeLevel? level;
  final double size;

  /// Grey, for a level that is not reached yet.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colour = muted || level == null ? AppColors.sand300 : levelColors[level]!;
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

/// What the badge pages read: the definitions by track, the traveller's
/// progress, and the season.
class BadgeBoard {
  BadgeBoard({required List<BadgeDefinition> definitions, required this.progress, this.season})
    : byType = {
        for (final type in {...trackOrder, ...definitions.map((d) => d.type)})
          if (definitions.any((d) => d.type == type))
            type: [
              for (final d in definitions)
                if (d.type == type) d,
            ]..sort((a, b) => a.threshold.compareTo(b.threshold)),
      };

  /// Each track's definitions, lowest threshold first, tracks in [trackOrder].
  final Map<String, List<BadgeDefinition>> byType;
  final BadgeProgress progress;
  final Season? season;

  /// The track from the progress answer, else an empty one with the
  /// definitions' thresholds.
  BadgeTrack track(String type) {
    final found = progress.track(type);
    if (found != null && found.thresholds.isNotEmpty) return found;
    final defs = byType[type] ?? const [];
    return BadgeTrack(
      type: type,
      count: found?.count ?? 0,
      level: found?.level,
      nextLevel: found?.nextLevel ?? (found?.level == null && defs.isNotEmpty ? defs.first.level : null),
      remaining: found?.remaining,
      thresholds: {
        for (final d in defs)
          if (d.level != null) d.level!: d.threshold,
      },
    );
  }

  List<BadgeTrack> get tracks => [for (final t in byType.keys) track(t)];

  /// The traveller's row for a badge, if the progress answer has one.
  UserBadge? mine(BadgeDefinition d) {
    for (final b in [...progress.earned, ...progress.badges]) {
      if (b.isFor(d)) return b;
    }
    return null;
  }

  bool earned(BadgeDefinition d) => mine(d)?.earned ?? false;

  /// The API's own name for a track, for a type the app has no words for.
  String? nameOf(String type) {
    final defs = byType[type];
    return defs == null || defs.isEmpty ? null : defs.first.name;
  }

  static Future<BadgeBoard> load(AmsApi api) async {
    final (definitions, progress, season) = await (api.badges(), api.badgeProgress(), api.currentSeason().orNull).wait;
    return BadgeBoard(definitions: definitions, progress: progress, season: season);
  }
}

/// A guest's badge page: what badges are, and the way to sign in.
class BadgesSignIn extends StatelessWidget {
  const BadgesSignIn({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return auth.SignInPrompt(icon: Icons.workspace_premium_outlined, title: s.badges, body: s.badgesSignIn);
  }
}

/// The traveller's badges: the season, the current status — a card per
/// track with something counted, one under the other — with where they stand
/// among members (`percentile`), then every track.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final userId = context.select<AuthProvider, String?>((a) => a.userId);

    return Scaffold(
      appBar: AppBar(title: Text(s.badges, style: AppText.display(22)), centerTitle: true),
      body: userId == null
          ? const BadgesSignIn()
          : AsyncView<BadgeBoard>(
              key: ValueKey(userId),
              load: () => BadgeBoard.load(context.read<AmsApi>()),
              builder: (context, board, reload) {
                final tracks = board.tracks;
                // A status card per track counting 1 or more, in track order;
                // with nothing counted yet, the leading track alone.
                final started = [
                  for (final t in tracks)
                    if (t.count > 0) t,
                ];
                final statuses = started.isNotEmpty ? started : [?leadingTrack(tracks)];
                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset(context)),
                    children: [
                      if (board.season != null) ...[SeasonLine(season: board.season!), const SizedBox(height: 12)],
                      for (final (i, t) in statuses.indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => context.push(Routes.achievement(t.type)),
                          child: _Status(track: t, board: board),
                        ),
                      ],
                      if (board.progress.percentile case final top?) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.emoji_events_outlined, size: 18, color: AppColors.sunset500),
                            const SizedBox(width: 6),
                            Text(
                              s.fill(s.topPercentOfMembers, {'n': top}),
                              style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sand800),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(s.badgeCategories, style: AppText.display(18)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 172,
                        ),
                        itemCount: tracks.length,
                        itemBuilder: (_, i) => _TrackCard(
                          track: tracks[i],
                          name: trackLabel(s, tracks[i].type, fallback: board.nameOf(tracks[i].type)),
                          onTap: () => context.push(Routes.badgeTiers(tracks[i].type)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(s.badgeHistory, style: AppText.display(18)),
                      const SizedBox(height: 12),
                      const _PastSeasonsLink(),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// The way to earlier seasons' badges, under the current season's.
class _PastSeasonsLink extends StatelessWidget {
  const _PastSeasonsLink();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return InkWell(
      onTap: () => context.push(Routes.pastSeasons),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: AppColors.violet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.pastSeasons,
                    style: AppText.sans(14.5, weight: FontWeight.w700, color: AppColors.sand900),
                  ),
                  Text(s.pastSeasonsHint, style: AppText.sans(12, color: AppColors.sand500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
          ],
        ),
      ),
    );
  }
}

/// "Green season 2026 · until October 31, 2026".
class SeasonLine extends StatelessWidget {
  const SeasonLine({super.key, required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ends = season.endsOn;
    return Row(
      children: [
        const Icon(Icons.event_outlined, size: 16, color: AppColors.sand500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            ends == null ? season.name : s.fill(s.seasonUntil, {'season': season.name, 'date': Dates.long(ends)}),
            style: AppText.sans(12.5, color: AppColors.sand600),
          ),
        ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.track, required this.board});
  final BadgeTrack track;
  final BadgeBoard board;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = trackLabel(s, track.type, fallback: board.nameOf(track.type));
    final next = track.nextLevel;
    final target = next == null ? null : track.thresholds[next];
    final remaining = track.remaining ?? (target == null ? null : math.max(0, target - track.count));
    final defs = board.byType[track.type] ?? const [];
    final description = [
      for (final d in defs)
        if (d.level == (next ?? track.level)) d.description,
    ].whereType<String>().firstOrNull;

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
            track.level == null ? name : '${levelLabel(s, track.level)} $name',
            style: AppText.sans(19, weight: FontWeight.w700, color: AppColors.violet),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BadgeMedal(level: track.level, size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description != null)
                      Text(description, style: AppText.sans(12.5, color: AppColors.sand600, height: 1.4)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: trackFraction(track),
                        minHeight: 7,
                        backgroundColor: Colors.white,
                        valueColor: const AlwaysStoppedAnimation(AppColors.sand900),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      next == null || remaining == null
                          ? s.topTierReached
                          : s.fill(s.remainingTo, {'n': remaining, 'level': levelLabel(s, next)}),
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

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track, required this.name, required this.onTap});
  final BadgeTrack track;
  final String name;
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
            Row(
              children: [
                BadgeMedal(level: track.level, size: 40),
                const Spacer(),
                Icon(trackIcon(track.type), size: 20, color: AppColors.sand400),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900, height: 1.25),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${track.count} ${trackUnit(s, track.type)}',
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
                levelLabel(s, track.level),
                style: AppText.sans(11.5, weight: FontWeight.w600, color: AppColors.sand700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
