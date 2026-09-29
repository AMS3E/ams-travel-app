import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/travel_repository.dart';
import '../../state/auth_provider.dart';
import '../../state/collections_provider.dart';
import '../../state/travel_preferences.dart';
import '../../widgets/common.dart';
import '../welcome/welcome_screen.dart';

/// The traveller's own page: who they are, what they have collected, and the
/// handful of settings the app has.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final auth = context.watch<AuthProvider>();
    final saved = context.watch<SavedProvider>();
    final stamps = context.watch<StampsProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: Text(s.navProfile, style: AppText.display(26)), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (user != null) ...[
            _Header(user: user),
            const SizedBox(height: 14),
            _BadgeCard(stamps: stamps.count),
            const SizedBox(height: 14),
            _Counts(author: user.username, saves: saved.count + context.watch<FoldersProvider>().itemCount),
            const SizedBox(height: 22),
          ] else ...[
            _GuestCard(),
            const SizedBox(height: 22),
          ],

          _MenuRow(label: s.accountInfo, onTap: () => context.push(Routes.account)),
          _MenuRow(label: s.preference, onTap: () => context.push(Routes.preferences)),
          _MenuRow(label: s.helpSupport, onTap: () => context.push(Routes.help)),
          _MenuRow(label: s.termsConditions, onTap: () => context.push(Routes.terms)),

          if (user != null) ...[
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => _signOut(context),
                child: Text(
                  s.logOut,
                  style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sand600),
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sunset500,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.logOut),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    // Logging out starts the app over: the welcome flow plays again (here and
    // on the next launch) with nothing pre-chosen.
    await context.read<TravelPreferences>().clear();
    if (!context.mounted) return;
    await context.read<SharedPreferences>().remove(WelcomeScreen.seenKey);
    if (context.mounted) context.go(Routes.welcome);
  }

  static String _date(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

/// The traveller's card: photo, name, where they are, when they joined and
/// how much of the account is filled in, with a way to edit it.
class _Header extends StatelessWidget {
  const _Header({required this.user});
  final AppUser user;

  // Placeholders until the API carries these. TODO(api): send `location` and
  // `joinedAt` with the account and these fall away.
  static const _fallbackLocation = 'Phnom Penh, Cambodia';
  static final _fallbackJoined = DateTime(2026, 1, 12);

  /// How much of the account is filled in — what the API has, not a guess.
  int get _completed {
    final fields = [
      user.username,
      user.email,
      user.firstName,
      user.lastName,
      user.phone,
      user.location,
      user.avatarUrl,
    ];
    final filled = fields.where((f) => f != null && f.isNotEmpty).length;
    return (filled * 100 / fields.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final joined = user.joinedAt ?? _fallbackJoined;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sand200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.brand50,
            backgroundImage: user.avatarUrl == null ? null : NetworkImage(user.avatarUrl!),
            child: user.avatarUrl != null
                ? null
                : Text(user.initials, style: AppText.display(22, color: AppColors.brand600)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: AppText.sans(17, weight: FontWeight.w700, color: AppColors.violet),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  user.location ?? _fallbackLocation,
                  style: AppText.sans(12.5, color: AppColors.sand600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${s.joined}: ${ProfileScreen._date(joined)}',
                  style: AppText.sans(11.5, color: AppColors.sand400),
                ),
                const SizedBox(height: 4),
                Text(
                  s.profileCompleted.replaceFirst('{n}', '$_completed'),
                  style: AppText.sans(11.5, weight: FontWeight.w600, color: const Color(0xFF16A34A)),
                ),
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
}

/// The travel passport, as a badge.
class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.stamps});
  final int stamps;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return InkWell(
      onTap: () => context.push(Routes.badges),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(color: AppColors.brand50, shape: BoxShape.circle),
              child: stamps == 0
                  ? const Icon(Icons.approval_outlined, color: AppColors.sand400, size: 26)
                  : Center(child: Text('$stamps', style: AppText.display(24, color: AppColors.brand600))),
            ),
            const SizedBox(height: 10),
            Text(s.yourBadge, style: AppText.sans(14, weight: FontWeight.w600, color: AppColors.sand700)),
          ],
        ),
      ),
    );
  }
}

/// Reviews written and places saved.
class _Counts extends StatelessWidget {
  const _Counts({required this.author, required this.saves});
  final String author;
  final int saves;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        Expanded(
          child: FutureBuilder<List<Review>>(
            future: context.read<TravelRepository>().getMyReviews(author),
            builder: (context, snap) => _CountTile(
              value: snap.data?.length ?? 0,
              label: s.reviews,
              onTap: () => context.push(Routes.myReviews),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CountTile(
            value: saves,
            label: s.saves,
            onTap: () => context.go(Routes.saved),
          ),
        ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.value, required this.label, this.onTap});
  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.sand200),
        ),
        child: Column(
          children: [
            Text('$value', style: AppText.display(24)),
            const SizedBox(height: 2),
            Text(label, style: AppText.sans(13, color: AppColors.sand500)),
          ],
        ),
      ),
    );
  }
}

/// One settings row with a chevron.
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
                child: Text(label, style: AppText.sans(15, weight: FontWeight.w600, color: AppColors.sand900)),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.sand400),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
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
          benefit(Icons.offline_pin_outlined, s.benefitOffline),
          benefit(Icons.notifications_active_outlined, s.benefitAlerts),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.sunset500),
              onPressed: () => context.push(Routes.login),
              child: Text(s.logIn),
            ),
          ),
        ],
      ),
    );
  }
}
