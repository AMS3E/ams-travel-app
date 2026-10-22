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
import 'badges_screen.dart';

/// The levels of one track ([badgeKey] is its type, such as BROWSES),
/// highest first, each with the threshold from `GET /badges`. A level opens
/// once the one below it is earned.
class BadgeTiersScreen extends StatelessWidget {
  const BadgeTiersScreen({super.key, required this.badgeKey});
  final String badgeKey;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final signedIn = context.select<AuthProvider, bool>((a) => a.isSignedIn);

    return Scaffold(
      appBar: AppBar(title: Text(s.badges, style: AppText.display(20)), centerTitle: true),
      body: !signedIn
          ? const BadgesSignIn()
          : AsyncView<BadgeBoard>(
              load: () => BadgeBoard.load(context.read<AmsApi>()),
              builder: (context, board, _) {
                final defs = board.byType[badgeKey];
                if (defs == null || defs.isEmpty) {
                  return EmptyState(icon: Icons.workspace_premium_outlined, title: s.badges, body: s.noResults);
                }
                final track = board.track(badgeKey);
                final name = trackLabel(s, badgeKey, fallback: board.nameOf(badgeKey));
                final ladder = defs.reversed.toList();

                return ListView(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset(context)),
                  children: [
                    Row(
                      children: [
                        Icon(trackIcon(badgeKey), color: AppColors.violet),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name, style: AppText.display(20))),
                      ],
                    ),
                    if (board.season != null) ...[const SizedBox(height: 6), SeasonLine(season: board.season!)],
                    const SizedBox(height: 16),
                    for (var i = 0; i < ladder.length; i++) ...[
                      _TierCard(
                        definition: ladder[i],
                        below: i + 1 < ladder.length ? ladder[i + 1] : null,
                        board: board,
                        count: track.count,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

/// One level: what it asks for, whether it is open yet, and how far along.
class _TierCard extends StatelessWidget {
  const _TierCard({required this.definition, required this.below, required this.board, required this.count});
  final BadgeDefinition definition;

  /// The level under this one, which has to be earned first; null for the first.
  final BadgeDefinition? below;
  final BadgeBoard board;
  final int count;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = definition;
    final target = d.threshold;
    // Earned is the API's word (`earnedAt`), not a count compared here.
    final earned = board.earned(d);
    final open = below == null || board.earned(below!);
    final progress = progressTo(count, target);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: earned ? () => context.push(Routes.achievement(d.code)) : null,
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
                BadgeMedal(level: d.level, size: 40, muted: !open),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.level == null ? d.name : levelLabel(s, d.level),
                        style: AppText.sans(
                          15,
                          weight: FontWeight.w700,
                          color: open ? AppColors.sand900 : AppColors.sand500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        open
                            ? '$target ${trackUnit(s, d.type)} ${s.requiredWord}'
                            : s.completeFirst.replaceFirst('{tier}', levelLabel(s, below!.level)),
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
            if (d.description != null && d.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(d.description!, style: AppText.sans(12.5, color: AppColors.sand600, height: 1.4)),
            ],
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
                  '${count.clamp(0, target)} / $target',
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
