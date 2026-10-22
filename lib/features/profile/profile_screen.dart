import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/ams_api.dart';
import '../../state/auth_provider.dart';
import '../../widgets/async_view.dart';
import '../../state/collections_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/place_list_row.dart';
import '../destination/check_in_screen.dart';
import '../auth/sign_in.dart' as auth;
import '../welcome/welcome_screen.dart';
import 'badges_screen.dart';
import 'season_points.dart';
import '../../core/utils/dates.dart';

/// What the profile counts, read once per visit: the reviews written
/// (`GET /reviews/me` page total), the check-ins (`GET /stamps/me`), this
/// season's badge progress (`GET /badges/me/progress`) and points
/// (`GET /seasons/me/progress`), with the season itself
/// (`GET /seasons/current`) for the points tile. A call that fails leaves its
/// tile out instead of showing a wrong number.
class _ProfileCounts {
  const _ProfileCounts({this.reviews, this.stamps, this.progress, this.points, this.season});
  final int? reviews;
  final List<Stamp>? stamps;
  final BadgeProgress? progress;

  /// This season's points: a total, no longer a badge ladder.
  final int? points;
  final Season? season;
}

/// The traveller's own page: who they are, what they have collected, and the
/// handful of settings the app has.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<_ProfileCounts>? _counts;
  String? _countsFor;

  /// Reads the counts again — after writing a review, say, so the tile is
  /// not left showing what it said at sign-in.
  void _reload() {
    if (!mounted || _countsFor == null) return;
    setState(() => _counts = _load(context.read<AmsApi>()));
  }

  Future<_ProfileCounts> _load(AmsApi api) async {
    final (reviews, stamps, progress, totals, season) = await (
      api.myReviews(size: 1).orNull,
      api.myStamps().orNull,
      api.badgeProgress().orNull,
      api.seasonProgress().orNull,
      api.currentSeason().orNull,
    ).wait;
    return _ProfileCounts(
      reviews: reviews?.totalElements,
      stamps: stamps,
      progress: progress,
      points: totals?.points,
      season: season,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final authState = context.watch<AuthProvider>();
    final user = authState.user;
    final signedIn = authState.isSignedIn;
    // Counts are read again when another traveller signs in.
    if (signedIn && _countsFor != user?.id) {
      _countsFor = user?.id;
      _counts = _load(context.read<AmsApi>());
    } else if (!signedIn) {
      _counts = null;
      _countsFor = null;
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.navProfile, style: AppText.display(26)), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          if (!signedIn) return;
          final reload = _load(context.read<AmsApi>());
          setState(() => _counts = reload);
          await Future.wait([reload, context.read<AuthProvider>().refreshAccount()]);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            if (signedIn) ...[
              if (user != null) _Header(user: user),
              const SizedBox(height: 14),
              FutureBuilder<_ProfileCounts>(
                future: _counts,
                builder: (context, snap) => _Collected(counts: snap.data, onReturn: _reload),
              ),
              const SizedBox(height: 22),
            ] else ...[
              const _GuestCard(),
              const SizedBox(height: 22),
            ],

            // Notifications are behind the bell on the home page.
            if (signedIn) _MenuRow(label: s.accountInfo, onTap: () => context.push(Routes.account)),
            _MenuRow(label: s.preference, onTap: () => context.push(Routes.preferences)),
            _MenuRow(label: s.helpSupport, onTap: () => context.push(Routes.help)),
            _MenuRow(label: s.termsConditions, onTap: () => context.push(Routes.terms)),

            if (signedIn) ...[
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () => _signOut(context),
                  child: Text(
                    s.logOut,
                    style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sunset600),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Center(
              child: Column(
                children: [
                  const AppLogo(size: 40),
                  const SizedBox(height: 8),
                  Text('© 2026 AMS Travel', style: AppText.sans(12, color: AppColors.sand400)),
                  Text(s.footerVersion, style: AppText.sans(12, color: AppColors.sand400)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final s = S.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.logOutConfirm, style: AppText.display(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sunset500, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.logOut),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final prefs = context.read<SharedPreferences>();
    final router = GoRouter.of(context);
    // Ends the Keycloak session in the browser, then forgets it here.
    await context.read<AuthProvider>().signOut();
    // Logging out starts the app over: the welcome slides play again, here
    // and on the next launch.
    await prefs.remove(WelcomeScreen.seenKey);
    router.go(Routes.welcome);
  }
}

/// The traveller's card: photo, name, home province, email, when they
/// joined, how complete the profile is (`profileCompletion`), and the pencil
/// to edit it.
class _Header extends StatelessWidget {
  const _Header({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final joined = user.createdAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Row(
        children: [
          ProfileAvatar(user: user, radius: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: AppText.sans(17, weight: FontWeight.w700, color: AppColors.violet),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.homeProvinceName != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 13, color: AppColors.sand500),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '${user.homeProvinceName}, ${s.cambodia}',
                          style: AppText.sans(12.5, color: AppColors.sand600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  user.email,
                  style: AppText.sans(12.5, color: AppColors.sand600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (joined != null)
                  Text('${s.joined}: ${Dates.short(joined)}', style: AppText.sans(11.5, color: AppColors.sand400)),
                if (user.profileCompletion != null && user.profileCompletion! < 100) ...[
                  const SizedBox(height: 4),
                  // Red while the profile is unfinished, so it reads as
                  // something still to do.
                  // A tap says what is still missing.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showMissing(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: user.profileCompletion! / 100,
                              minHeight: 5,
                              backgroundColor: AppColors.sand100,
                              color: AppColors.sunset500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  s.fill(s.profileCompleted, {'n': user.profileCompletion!}),
                                  style: AppText.sans(11.5, weight: FontWeight.w600, color: AppColors.sunset500),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.sunset500),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push(Routes.editProfile),
            tooltip: s.editProfile,
            icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.sand600),
          ),
        ],
      ),
    );
  }

  /// The fields still empty, by the server's rule for `profileCompletion`
  /// (name, email, phone, picture and home province, 20 each), each with
  /// the form that fills it, opened at that field.
  List<(String, String)> _missing(S s) => [
    if ((user.fullName?.trim() ?? '').isEmpty) (s.fullName, Routes.accountField('name')),
    if (user.email.trim().isEmpty) (s.email, Routes.account),
    if ((user.phone?.trim() ?? '').isEmpty) (s.phoneNumber, Routes.accountField('phone')),
    if (user.avatarUrl.isEmpty) (s.profilePhoto, Routes.pickProfilePhoto),
    if (user.homeProvinceId == null) (s.homeProvince, Routes.accountField('province')),
  ];

  /// What is still missing; a tap on one goes to fill it, and "Complete
  /// profile" to the first.
  Future<void> _showMissing(BuildContext context) async {
    final s = S.read(context);
    final missing = _missing(s);
    final route = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.profileIncompleteTitle, style: AppText.display(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.fill(s.profileCompleted, {'n': user.profileCompletion!}),
              style: AppText.sans(13.5, weight: FontWeight.w600, color: AppColors.sunset500),
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(s.profileIncompleteBody, style: AppText.sans(14, color: AppColors.sand700)),
              const SizedBox(height: 4),
              for (final (label, to) in missing)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(c, to),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.radio_button_unchecked_rounded, size: 16, color: AppColors.sunset500),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.sand900),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.sand400),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(s.later)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.violet, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, missing.firstOrNull?.$2 ?? Routes.account),
            child: Text(s.completeProfile),
          ),
        ],
      ),
    );
    if (route != null && context.mounted) context.push(route);
  }
}

/// The photo from `avatarUrl`, else the first letter of the name.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.user, this.radius = 30});
  final UserProfile user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = user.avatarUrl.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.brand50,
      backgroundImage: hasPhoto ? NetworkImage(user.avatarUrl) : null,
      child: hasPhoto ? null : Text(user.initials, style: AppText.display(radius * 0.73, color: AppColors.brand600)),
    );
  }
}

/// The badge, then what the traveller has collected: reviews, check-ins and
/// the season's points, three across.
class _Collected extends StatelessWidget {
  const _Collected({required this.counts, required this.onReturn});
  final _ProfileCounts? counts;

  /// Called when a page that can change the counts is closed.
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final progress = counts?.progress;
    final points = counts?.points;
    final stamps = counts?.stamps;

    return Column(
      children: [
        _BadgeCard(progress: progress),
        const SizedBox(height: 14),
        // Three tiles of the same height, whatever their labels run to.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _CountTile(
                  value: counts?.reviews == null ? '—' : '${counts!.reviews}',
                  label: s.reviews,
                  icon: Icons.rate_review_outlined,
                  onTap: () async {
                    await context.push(Routes.myReviews);
                    onReturn();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CountTile(
                  value: stamps == null ? '—' : '${stamps.length}',
                  label: s.checkIns,
                  icon: Icons.approval_outlined,
                  onTap: stamps == null ? null : () => _showCheckIns(context, stamps),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CountTile(
                  value: points == null ? '—' : '$points',
                  label: s.pointsThisSeason,
                  icon: Icons.stars_outlined,
                  footer: counts?.season == null ? null : SeasonTag(type: counts!.season!.type),
                  onTap: () => showSeasonPoints(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The places checked in at, newest first: attractions, stays, food places
  /// and activities, their cards in one `GET /search/cards` call per kind.
  /// The scan button here checks in at whichever place's code is scanned.
  static void _showCheckIns(BuildContext context, List<Stamp> stamps) {
    final s = S.read(context);
    final api = context.read<AmsApi>();
    final sorted = [...stamps]..sort((a, b) => (b.collectedAt ?? DateTime(0)).compareTo(a.collectedAt ?? DateTime(0)));

    Future<List<PlaceCard>> load() async {
      final recent = sorted.take(100).toList();
      final byType = <CardType, List<String>>{};
      for (final st in recent) {
        byType.putIfAbsent(st.targetType, () => []).add(st.destinationId);
      }
      final found = await [for (final e in byType.entries) api.cards(e.value, type: e.key)].wait;
      final byKey = {
        for (final list in found) ...{for (final c in list) FoldersProvider.keyOf(c.type, c.id): c},
      };
      return [for (final st in recent) ?byKey[FoldersProvider.keyOf(st.targetType, st.destinationId)]];
    }

    showListSheet(
      context,
      title: s.checkIns,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  openCheckIn(context);
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: Text(s.scanCode),
              ),
            ),
          ),
          if (sorted.isEmpty)
            EmptyState(icon: Icons.approval_outlined, title: s.noCheckIns, body: s.noCheckInsBody)
          else
            AsyncView<List<PlaceCard>>(
              load: load,
              builder: (context, cards, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [for (final c in cards) PlaceListRow(card: c)],
              ),
            ),
        ],
      ),
    );
  }
}

/// The level reached furthest along, as a medal, leading to Badges.
class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.progress});
  final BadgeProgress? progress;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lead = progress == null ? null : leadingTrack(progress!.tracks);
    return InkWell(
      onTap: () => context.push(Routes.badges),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Column(
          children: [
            BadgeMedal(level: lead?.level, size: 62),
            const SizedBox(height: 10),
            Text(
              lead?.level == null ? s.yourBadge : '${levelLabel(s, lead!.level)} ${trackLabel(s, lead.type)}',
              style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.sand700),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.value, required this.label, this.icon, this.footer, this.onTap});
  final String value;
  final String label;
  final IconData? icon;

  /// Shown under the label, such as the points tile's season.
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 17, color: AppColors.violet), const SizedBox(width: 5)],
                Text(value, style: AppText.display(22)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.sans(12.5, color: AppColors.sand500, height: 1.3),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (footer != null) ...[const SizedBox(height: 6), footer!],
          ],
        ),
      ),
    );
  }
}

/// One settings row with a chevron, and a count when there is one.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sand200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sand900),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
            ],
          ),
        ),
      ),
    );
  }
}

/// A guest's profile: why to have an account, then Log in and Register, both
/// on Keycloak's pages.
class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final busy = context.select<AuthProvider, bool>((a) => a.busy);
    Widget benefit(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.sunset200),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppText.sans(14, color: Colors.white, height: 1.4)),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.brand950, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppLogo(size: 52),
          const SizedBox(height: 16),
          Text(s.guestTitle, style: AppText.display(24, color: Colors.white)),
          const SizedBox(height: 8),
          Text(s.guestSubtitle, style: AppText.sans(14, color: Colors.white70, height: 1.5)),
          const SizedBox(height: 20),
          benefit(Icons.favorite_border_rounded, s.benefitSave),
          benefit(Icons.approval_outlined, s.benefitAny),
          benefit(Icons.military_tech_outlined, s.benefitAlerts),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.sunset500),
              onPressed: busy ? null : () => auth.signIn(context),
              child: Text(s.logIn),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              onPressed: busy ? null : () => auth.register(context),
              child: Text(s.registerCta),
            ),
          ),
        ],
      ),
    );
  }
}
