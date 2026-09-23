import 'dart:ui';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/collections_provider.dart';


/// Bottom navigation: Home · Explore · Map · Saved · Profile, as a floating
/// frosted-glass bar with the page scrolling underneath.
///
/// Because the body runs under the bar, tab pages add
/// `MediaQuery.paddingOf(context).bottom` to their bottom spacing — the
/// Scaffold sets it to the bar's height.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final savedCount = context.select<SavedProvider, int>((p) => p.count);
    final items = [
      (Icons.home_outlined, Icons.home_rounded, s.navHome, 0),
      (Icons.explore_outlined, Icons.explore_rounded, s.navExplore, 0),
      (Icons.public_outlined, Icons.public_rounded, s.navMap, 0),
      (Icons.favorite_border_rounded, Icons.favorite_rounded, s.navSaved, savedCount),
      (Icons.person_outline_rounded, Icons.person_rounded, s.navProfile, 0),
    ];

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
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
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavItem(
                            icon: items[i].$1,
                            selectedIcon: items[i].$2,
                            label: items[i].$3,
                            badge: items[i].$4,
                            selected: shell.currentIndex == i,
                            onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                          ),
                        ),
                    ],
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
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
                Badge(
                  isLabelVisible: badge > 0,
                  backgroundColor: AppColors.sunset500,
                  label: Text('$badge'),
                  child: Icon(selected ? selectedIcon : icon, size: 23, color: color),
                ),
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
