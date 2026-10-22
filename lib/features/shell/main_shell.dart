import 'dart:math' as math;
import 'dart:ui';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/account.dart';
import '../../state/auth_provider.dart';
import '../../state/locale_provider.dart';
import '../../state/settings_provider.dart';
import '../destination/check_in_screen.dart';
import '../map/map_screen.dart';

/// Bottom navigation: Explore · Map · Scan · Saved · Profile, as a floating
/// frosted-glass bar with the page scrolling underneath.
///
/// Because the body runs under the bar, tab pages add
/// `MediaQuery.paddingOf(context).bottom` to their bottom spacing — the
/// Scaffold sets it to the bar's height.
///
/// It also carries the account's preferences (`GET /preferences/me`) into the
/// app once signed in: language, currency and the notification switch.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final AuthProvider _auth;
  UserPreferences? _applied;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _auth.addListener(_applyAccount);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyAccount());
  }

  /// Each answer from `/preferences/me` is applied once.
  void _applyAccount() {
    final prefs = _auth.preferences;
    if (!mounted || prefs == null || identical(prefs, _applied)) return;
    _applied = prefs;
    context.read<LocaleProvider>().applyCode(prefs.preferredLanguage);
    context.read<SettingsProvider>().apply(prefs);
  }

  @override
  void dispose() {
    _auth.removeListener(_applyAccount);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppNavBar.tab.value = widget.shell.currentIndex;
    return Scaffold(
      extendBody: true,
      body: widget.shell,
      bottomNavigationBar: AppNavBar(shell: widget.shell),
    );
  }
}

/// The floating bar itself. The tabs show it through [MainShell]; every page
/// pushed above them shows it through [WithNavBar], and a [Hero] keeps it
/// still while pages slide in and out.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, this.shell});

  /// Null on a pushed page: a tab is then reached with `go`, which also
  /// closes the pages above the tabs.
  final StatefulNavigationShell? shell;

  /// The Map tab's index in the bar.
  static const _mapTab = 1;
  static const _paths = [Routes.home, Routes.map, Routes.saved, Routes.profile];

  /// The tab underneath, lit on pushed pages too.
  static final tab = ValueNotifier<int>(0);

  /// The bar's height on screen, safe area included.
  static double heightOf(BuildContext context) => 68 + math.max(MediaQuery.paddingOf(context).bottom, 10);

  void _open(BuildContext context, int i) {
    final shell = this.shell;
    if (shell != null) {
      shell.goBranch(i, initialLocation: i == shell.currentIndex);
    } else {
      context.go(_paths[i]);
    }
    if (i == _mapTab) MapScreen.tabTaps.value++;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final items = [
      (Icons.explore_outlined, Icons.explore_rounded, s.navExplore),
      (Icons.public_outlined, Icons.public_rounded, s.navMap),
      (Icons.favorite_border_rounded, Icons.favorite_rounded, s.navSaved),
      (Icons.person_outline_rounded, Icons.person_rounded, s.navProfile),
    ];

    return Hero(
      tag: AppNavBar,
      transitionOnUserGestures: true,
      // Flying between pages it has no Material above it.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [BoxShadow(color: Color(0x141C1935), blurRadius: 20, offset: Offset(0, 6))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.05)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.2),
                    ),
                    child: ValueListenableBuilder<int>(
                      valueListenable: tab,
                      builder: (context, current, _) => Row(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            // The check-in scanner sits in the middle; it opens
                            // over the tabs rather than being one.
                            if (i == 2)
                              Expanded(
                                child: _ScanItem(label: s.scanCode, onTap: () => openCheckIn(context)),
                              ),
                            Expanded(
                              child: _NavItem(
                                icon: items[i].$1,
                                selectedIcon: items[i].$2,
                                label: items[i].$3,
                                selected: (shell?.currentIndex ?? current) == i,
                                onTap: () => _open(context, i),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A page pushed above the tabs, with the bar floating over its foot. The
/// page is told the bar is there through its bottom padding, the way the
/// tabs are, so its lists scroll clear of it and its own bottom buttons sit
/// above it. The bar steps aside while the keyboard is up.
class WithNavBar extends StatelessWidget {
  const WithNavBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final shown = mq.viewInsets.bottom == 0;
    // The same tree either way, so the page keeps its state.
    return Stack(
      children: [
        MediaQuery(
          data: shown ? mq.copyWith(padding: mq.padding.copyWith(bottom: AppNavBar.heightOf(context))) : mq,
          child: child,
        ),
        if (shown) const Positioned(left: 0, right: 0, bottom: 0, child: AppNavBar()),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.violet : AppColors.sand800;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? selectedIcon : icon, size: 23, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(11, weight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The scan button in the middle of the bar: the icon alone, a size up.
class _ScanItem extends StatelessWidget {
  const _ScanItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const Center(child: Icon(Icons.qr_code_scanner_rounded, size: 34, color: AppColors.sand800)),
      ),
    );
  }
}
