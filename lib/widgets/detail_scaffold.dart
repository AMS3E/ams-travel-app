import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import 'app_image.dart';
import 'common.dart';

/// Shared layout for detail pages: a large photo header that collapses into a
/// normal app bar showing [title].
class DetailScaffold extends StatefulWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.image,
    required this.header,
    required this.slivers,
    this.actions = const [],
    this.expandedHeight = 420,
    this.heroTag,
    this.bottomBar,
  });

  final String title;
  final String image;

  /// Content drawn over the bottom of the photo (title, stats…).
  final Widget header;
  final List<Widget> slivers;
  final List<Widget> actions;
  final double expandedHeight;
  final Object? heroTag;
  final Widget? bottomBar;

  @override
  State<DetailScaffold> createState() => _DetailScaffoldState();
}

class _DetailScaffoldState extends State<DetailScaffold> {
  final _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final top = MediaQuery.paddingOf(context).top;
      final collapsed = _scroll.offset > widget.expandedHeight - kToolbarHeight - top - 24;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget image = AppImage(widget.image);
    if (widget.heroTag != null) image = Hero(tag: widget.heroTag!, child: image);

    return Scaffold(
      bottomNavigationBar: widget.bottomBar,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: widget.expandedHeight,
            backgroundColor: Colors.white,
            systemOverlayStyle: _collapsed ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: _collapsed
                    ? IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded))
                    : GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
              ),
            ),
            title: AnimatedOpacity(
              opacity: _collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Text(widget.title, style: AppText.display(19), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            actions: [
              for (final a in widget.actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.3, 0.55, 1],
                        colors: [Color(0x661C1935), Color(0x001C1935), Color(0x401C1935), Color(0xEB1C1935)],
                      ),
                    ),
                  ),
                  Positioned(left: 20, right: 20, bottom: 24, child: widget.header),
                ],
              ),
            ),
          ),
          ...widget.slivers,
          SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

/// Section title used inside detail pages.
class DetailSection extends StatelessWidget {
  const DetailSection({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SectionHeader(eyebrow: eyebrow, title: title, subtitle: subtitle, padding: EdgeInsets.zero),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
