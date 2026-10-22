import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import 'common.dart';

/// The photo header of a detail page. The photo scrolls away; the back
/// button and [actions] stay pinned at the top, on a frosted glass bar once
/// the photo is gone.
class HeroAppBar extends StatefulWidget {
  const HeroAppBar({super.key, required this.height, required this.background, this.actions = const []});

  /// The header's full height, status bar included.
  final double height;
  final Widget background;

  /// Buttons on the right (save, share), together in one glass pill.
  final List<Widget> actions;

  @override
  State<HeroAppBar> createState() => _HeroAppBarState();
}

class _HeroAppBarState extends State<HeroAppBar> {
  static const _toolbarHeight = 60.0;

  ScrollPosition? _position;
  bool _collapsed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position == _position) return;
    _position?.removeListener(_onScroll);
    _position = position?..addListener(_onScroll);
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final top = MediaQuery.paddingOf(context).top;
    final collapsed = _position!.pixels > widget.height - _toolbarHeight - top - 24;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      toolbarHeight: _toolbarHeight,
      expandedHeight: widget.height - MediaQuery.paddingOf(context).top,
      // The bar itself is clear; the frosted glass below does the work.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      // Light status bar icons over the photo, dark ones over the glass bar.
      systemOverlayStyle: _collapsed ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      titleSpacing: 16,
      // White glass over the photo, faint dark glass on the glass bar.
      title: GlassScope(
        onLight: _collapsed,
        child: Row(
          children: [
            GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: s.back,
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            const Spacer(),
            if (widget.actions.isNotEmpty) GlassGroup(children: widget.actions),
          ],
        ),
      ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          FlexibleSpaceBar(collapseMode: CollapseMode.pin, background: widget.background),
          // Once the photo is gone: frosted glass over the page scrolling
          // under the bar, with a hairline below.
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: ClipRect(
                child: BackdropFilter(
                  // A light blur and an almost clear tint: the page shows
                  // through, softened, like clear glass.
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.05)],
                      ),
                      border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.6))),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
