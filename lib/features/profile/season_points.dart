import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../data/api/ams_api.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';

// The API runs two kinds of season, one after the other: GREEN_SEASON (May to
// October, the rains) and HIGH_SEASON (November to April). Points start again
// at each season. `GET /seasons` (public) lists them all with their status
// (UPCOMING, ACTIVE, COMPLETED); `GET /seasons/me/history` has the traveller's
// totals per season and `GET /points/me?seasonId=` the entries behind them.

/// A season type's leaf or sun, colour and short name.
({IconData icon, Color color, String label}) seasonStyle(S s, String? type) => switch (type) {
  'HIGH_SEASON' => (icon: Icons.wb_sunny_rounded, color: const Color(0xFFE0922F), label: s.highSeason),
  _ => (icon: Icons.eco_rounded, color: AppColors.success, label: s.greenSeason),
};

/// "1 May 2026 – 31 Oct 2026", or null without both dates.
String? seasonDates(Season? season) {
  final starts = season?.startsOn;
  final ends = season?.endsOn;
  return starts == null || ends == null ? null : '${Dates.short(starts)} – ${Dates.short(ends)}';
}

/// The round leaf or sun of a season type.
class SeasonIcon extends StatelessWidget {
  const SeasonIcon({super.key, required this.type});
  final String? type;
  static const size = 40.0;

  @override
  Widget build(BuildContext context) {
    final style = seasonStyle(S.of(context), type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
      child: Icon(style.icon, size: size * 0.55, color: Colors.white),
    );
  }
}

/// "🌿 Green season", small, in the season's colour.
class SeasonTag extends StatelessWidget {
  const SeasonTag({super.key, required this.type});
  final String? type;

  @override
  Widget build(BuildContext context) {
    final style = seasonStyle(S.of(context), type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: style.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              style.label,
              style: AppText.sans(10.5, weight: FontWeight.w700, color: style.color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The season points sheet, opened from the profile's points tile.
void showSeasonPoints(BuildContext context) {
  showListSheet(context, title: S.read(context).seasonPoints, child: const _SeasonPoints());
}

class _SeasonData {
  const _SeasonData(this.seasons, this.history);
  final List<Season> seasons;
  final List<SeasonProgress> history;
}

class _SeasonPoints extends StatelessWidget {
  const _SeasonPoints();

  static Future<_SeasonData> _load(AmsApi api) async {
    final (seasons, history) = await (api.seasons(), api.seasonHistory().orNull).wait;
    return _SeasonData(seasons, history ?? const []);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AmsApi>();
    return AsyncView<_SeasonData>(
      load: () => _load(api),
      builder: (context, data, _) => _SeasonBrowser(data: data),
    );
  }
}

/// The season chips, the picked season's card, what comes next, and the
/// picked season's entries.
class _SeasonBrowser extends StatefulWidget {
  const _SeasonBrowser({required this.data});
  final _SeasonData data;

  @override
  State<_SeasonBrowser> createState() => _SeasonBrowserState();
}

class _SeasonBrowserState extends State<_SeasonBrowser> {
  /// Seasons that have started, newest first.
  late final List<Season> _started = [
    for (final season in widget.data.seasons)
      if (!season.isUpcoming) season,
  ]..sort((a, b) => (b.startsOn ?? DateTime(0)).compareTo(a.startsOn ?? DateTime(0)));

  /// The first season still to come.
  late final Season? _next = ([
    for (final season in widget.data.seasons)
      if (season.isUpcoming) season,
  ]..sort((a, b) => (a.startsOn ?? DateTime(0)).compareTo(b.startsOn ?? DateTime(0)))).firstOrNull;

  late Season? _picked = _started.where((season) => season.isActive).firstOrNull ?? _started.firstOrNull;

  SeasonProgress? _totals(Season season) => widget.data.history.where((h) => h.seasonId == season.id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final picked = _picked;
    if (picked == null) {
      return EmptyState(icon: Icons.stars_outlined, title: s.noPoints, body: s.noPointsBody);
    }
    final next = _next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_started.length > 1) ...[
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final season in _started)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SeasonChip(
                      season: season,
                      selected: season.id == picked.id,
                      onTap: () => setState(() => _picked = season),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        _SeasonCard(season: picked, totals: _totals(picked)),
        if (next != null && picked.isActive) ...[const SizedBox(height: 10), _NextSeason(season: next)],
        const SizedBox(height: 20),
        Text(
          s.pointsEarned,
          style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.sand900),
        ),
        const SizedBox(height: 4),
        _Entries(key: ValueKey(picked.id), seasonId: picked.id),
      ],
    );
  }
}

class _SeasonChip extends StatelessWidget {
  const _SeasonChip({required this.season, required this.selected, required this.onTap});
  final Season season;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = seasonStyle(S.of(context), season.type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? style.color : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? style.color : AppColors.sand200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 15, color: selected ? Colors.white : style.color),
            const SizedBox(width: 5),
            Text(
              season.name,
              style: AppText.sans(12.5, weight: FontWeight.w600, color: selected ? Colors.white : AppColors.sand800),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picked season: its name and dates, how long is left, and the points
/// with the reviews and ratings behind them.
class _SeasonCard extends StatelessWidget {
  const _SeasonCard({required this.season, required this.totals});
  final Season season;
  final SeasonProgress? totals;

  /// "12 days left", "Last day", or "Ended 30 Apr 2026".
  String? _when(S s) {
    final ends = season.endsOn;
    if (ends == null) return null;
    if (season.isCompleted) return s.fill(s.seasonEnded, {'date': Dates.short(ends)});
    final days = Dates.dateOnly(ends).difference(Dates.dateOnly(DateTime.now())).inDays + 1;
    if (days <= 1) return s.seasonLastDay;
    return s.fill(s.seasonDaysLeft, {'n': days});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final style = seasonStyle(s, season.type);
    final active = season.isActive;
    final when = _when(s);
    final dates = seasonDates(season);

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
              SeasonIcon(type: season.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      season.name,
                      style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900),
                    ),
                    if (dates != null) Text(dates, style: AppText.sans(12, color: AppColors.sand600)),
                  ],
                ),
              ),
              if (when != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? style.color : AppColors.sand200,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    when,
                    style: AppText.sans(11, weight: FontWeight.w700, color: active ? Colors.white : AppColors.sand700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${totals?.points ?? 0}', style: AppText.display(34, color: style.color)),
              const SizedBox(width: 6),
              Text(
                s.pointsWord,
                style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.sand700),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            s.fill(s.seasonActivity, {'reviews': totals?.reviewCount ?? 0, 'ratings': totals?.ratingCount ?? 0}),
            style: AppText.sans(12.5, color: AppColors.sand600),
          ),
        ],
      ),
    );
  }
}

/// "Next: High season 2026/27 · starts 1 Nov 2026" — points start from zero.
class _NextSeason extends StatelessWidget {
  const _NextSeason({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final style = seasonStyle(s, season.type);
    final starts = season.startsOn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Row(
        children: [
          Icon(style.icon, size: 18, color: style.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              starts == null
                  ? s.fill(s.seasonNextNoDate, {'season': season.name})
                  : s.fill(s.seasonNext, {'season': season.name, 'date': Dates.short(starts)}),
              style: AppText.sans(12.5, color: AppColors.sand700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// The picked season's point entries (`GET /points/me?seasonId=`).
class _Entries extends StatelessWidget {
  const _Entries({super.key, required this.seasonId});
  final String seasonId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = context.read<AmsApi>();
    return AsyncView<PageOf<PointEntry>>(
      load: () => api.myPoints(seasonId: seasonId, size: 50),
      builder: (context, page, _) => page.content.isEmpty
          ? EmptyState(icon: Icons.stars_outlined, title: s.noPoints, body: s.noPointsBody)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in page.content)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      p.sourceType == 'REVIEW' ? Icons.rate_review_outlined : Icons.star_outline_rounded,
                      color: AppColors.violet,
                    ),
                    title: Text(p.sourceType == 'REVIEW' ? s.pointsForReview : s.pointsForRating),
                    subtitle: p.createdAt == null ? null : Text(Dates.short(p.createdAt!)),
                    trailing: Text(
                      '+${p.points}',
                      style: AppText.sans(15, weight: FontWeight.w700, color: AppColors.success),
                    ),
                  ),
              ],
            ),
    );
  }
}
