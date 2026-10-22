import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/account.dart';
import '../../state/auth_provider.dart';
import '../../state/notifications_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/common.dart';
import '../auth/sign_in.dart' as auth;

/// The traveller's notifications (`GET /notifications`), newest first: All
/// and Unread, tap to mark read, swipe to delete, and mark all read.
///
/// The design's own kinds ("New places added in Siem Reap", "Complete your
/// profile") and push delivery are parked in screens-to-api.md.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    context.read<NotificationsProvider>().load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final signedIn = context.select<AuthProvider, bool>((a) => a.isSignedIn);
    final notifications = context.watch<NotificationsProvider>();

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(s.notifications, style: AppText.display(20)), centerTitle: true),
        // Centred across the page, at the top.
        body: Align(
          alignment: Alignment.topCenter,
          child: auth.SignInPrompt(
            icon: Icons.notifications_none_rounded,
            title: s.noNotifications,
            body: s.notificationsSignIn,
          ),
        ),
      );
    }

    Widget body() {
      if (!notifications.isLoaded) return const LoadingView();
      if (notifications.error != null && notifications.all.isEmpty) {
        return ErrorView(error: notifications.error!, onRetry: notifications.load);
      }
      return TabBarView(
        controller: _tabs,
        children: [
          _List(items: notifications.all),
          _List(items: notifications.unread),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.notifications, style: AppText.display(20)),
        centerTitle: true,
        actions: [
          if (notifications.unreadCount > 0)
            IconButton(
              tooltip: s.markAllRead,
              onPressed: notifications.markAllRead,
              icon: const Icon(Icons.done_all_rounded),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabAlignment: TabAlignment.fill,
          indicatorColor: AppColors.violet,
          labelColor: AppColors.violet,
          tabs: [
            Tab(text: '${s.all} (${notifications.all.length})'),
            Tab(text: '${s.unreadWord} (${notifications.unreadCount})'),
          ],
        ),
      ),
      body: body(),
    );
  }
}

/// The rows, under a heading for the day they arrived on.
class _List extends StatelessWidget {
  const _List({required this.items});
  final List<InboxNotification> items;

  /// Today, yesterday, this week, earlier — whichever the row falls in.
  static String _bucket(S s, Duration age) {
    if (age.inHours < 24) return s.today;
    if (age.inHours < 48) return s.yesterday;
    if (age.inDays < 7) return s.thisWeek;
    return s.earlier;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final provider = context.read<NotificationsProvider>();
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          children: [EmptyState(icon: Icons.notifications_none_rounded, title: s.noNotifications, body: '')],
        ),
      );
    }

    final now = DateTime.now();
    String? last;
    final rows = <Widget>[];
    for (final n in items) {
      final bucket = _bucket(s, now.difference(n.createdAt.toLocal()));
      if (bucket != last) {
        last = bucket;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(
              bucket,
              style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900),
            ),
          ),
        );
      }
      rows.add(
        Dismissible(
          key: ValueKey(n.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: AppColors.sunset500,
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          onDismissed: (_) {
            provider.remove(n.id);
            showToast(context, s.notificationDeleted);
          },
          child: _Row(notification: n, now: now),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView(
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
        children: rows,
      ),
    );
  }
}

/// One notification: its symbol, what happened, when, and whether it is new.
class _Row extends StatelessWidget {
  const _Row({required this.notification, required this.now});
  final InboxNotification notification;
  final DateTime now;

  /// PUBLISH_APPROVED, PUBLISH_REJECTED, PUBLISH_CHANGES_REQUESTED, BADGE_EARNED.
  static IconData _icon(String type) => switch (type) {
    'BADGE_EARNED' => Icons.workspace_premium_outlined,
    'PUBLISH_APPROVED' => Icons.check_circle_outline_rounded,
    'PUBLISH_REJECTED' => Icons.block_rounded,
    'PUBLISH_CHANGES_REQUESTED' => Icons.edit_note_rounded,
    _ => Icons.info_outline_rounded,
  };

  /// "18m ago", "2h ago", "3d ago".
  static String _when(S s, Duration age) {
    if (age.inMinutes < 60) return '${age.inMinutes.clamp(0, 59)}m ${s.agoWord}';
    if (age.inHours < 24) return '${age.inHours}h ${s.agoWord}';
    return '${age.inDays}d ${s.agoWord}';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final n = notification;

    return InkWell(
      onTap: () => context.read<NotificationsProvider>().markRead(n.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: AppColors.sand100, shape: BoxShape.circle),
              child: Icon(_icon(n.type), size: 18, color: AppColors.violet),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: AppText.sans(13.5, weight: FontWeight.w700, color: AppColors.sand900),
                  ),
                  if (n.body != null && n.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(n.body!, style: AppText.sans(11.5, color: AppColors.sand500, height: 1.4)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _when(s, now.difference(n.createdAt.toLocal())),
                  style: AppText.sans(11, color: AppColors.sand500),
                ),
                const SizedBox(height: 10),
                if (!n.isRead)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: AppColors.violet, shape: BoxShape.circle),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
