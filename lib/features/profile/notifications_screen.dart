import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/notifications_provider.dart';
import '../../widgets/common.dart';

/// What the app has to tell the traveller, newest first.
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
    final notifications = context.watch<NotificationsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.notifications, style: AppText.display(20)),
        centerTitle: true,
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
      body: TabBarView(
        controller: _tabs,
        children: [
          _List(items: notifications.all),
          _List(items: notifications.unread),
        ],
      ),
    );
  }
}

/// The rows, under a heading for each day they arrived on.
class _List extends StatelessWidget {
  const _List({required this.items});
  final List<AppNotification> items;

  /// Today, yesterday, this week, earlier — whichever the row falls in.
  static String _bucket(S s, int minutes) {
    if (minutes < 60 * 24) return s.today;
    if (minutes < 60 * 48) return s.yesterday;
    if (minutes < 60 * 24 * 7) return s.thisWeek;
    return s.earlier;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (items.isEmpty) {
      return SingleChildScrollView(
        child: EmptyState(icon: Icons.notifications_none_rounded, title: s.noNotifications, body: ''),
      );
    }

    String? last;
    final rows = <Widget>[];
    for (final n in items) {
      final bucket = _bucket(s, n.minutesAgo);
      if (bucket != last) {
        last = bucket;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(bucket, style: AppText.sans(14, weight: FontWeight.w700, color: AppColors.sand900)),
          ),
        );
      }
      rows.add(_Row(notification: n));
    }

    return ListView(
      padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
      children: rows,
    );
  }
}

/// One notification: its symbol, what happened, when, and whether it is new.
class _Row extends StatelessWidget {
  const _Row({required this.notification});
  final AppNotification notification;

  static const _icons = <String, IconData>{
    'place': Icons.place_outlined,
    'profile': Icons.person_outline_rounded,
    'info': Icons.info_outline_rounded,
    'review': Icons.rate_review_outlined,
    'badge': Icons.workspace_premium_outlined,
  };

  /// "18m ago", "2h ago", "3d ago".
  String _when(S s, int minutes) {
    if (minutes < 60) return '${minutes}m ${s.agoWord}';
    if (minutes < 60 * 24) return '${minutes ~/ 60}h ${s.agoWord}';
    return '${minutes ~/ (60 * 24)}d ${s.agoWord}';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final n = notification;
    final read = context.select<NotificationsProvider, bool>((p) => p.isRead(n.id));

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
              child: Icon(_icons[n.kind] ?? Icons.info_outline_rounded, size: 18, color: AppColors.violet),
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
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    style: AppText.sans(11.5, color: AppColors.sand500, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_when(s, n.minutesAgo), style: AppText.sans(11, color: AppColors.sand500)),
                const SizedBox(height: 10),
                if (!read)
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
