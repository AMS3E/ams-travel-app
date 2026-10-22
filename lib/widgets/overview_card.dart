import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// A place's overview: a heading and its text in a [GradientCard]. Long text folds to [foldedLines] lines, ending
/// in "… Read more".
class OverviewCard extends StatefulWidget {
  const OverviewCard({super.key, required this.title, required this.text, this.foldedLines = 4});

  final String title;

  /// Plain text; run HTML through `htmlToText` first.
  final String text;
  final int foldedLines;

  @override
  State<OverviewCard> createState() => _OverviewCardState();
}

class _OverviewCardState extends State<OverviewCard> {
  bool _open = false;
  late final _toggle = TapGestureRecognizer()..onTap = () => setState(() => _open = !_open);

  @override
  void dispose() {
    _toggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GradientCard(
    title: widget.title,
    child: LayoutBuilder(builder: (context, box) => _body(context, box.maxWidth)),
  );

  Widget _body(BuildContext context, double width) {
    final s = S.of(context);
    final style = AppText.sans(15.5, color: AppColors.sand600, height: 1.6);
    final link = AppText.sans(15.5, weight: FontWeight.w600, color: AppColors.violet, height: 1.6);
    final text = widget.text;
    TextSpan withLink(String body, String label) => TextSpan(
      text: body,
      style: style,
      // Non-breaking, so the link never splits over two lines.
      children: [TextSpan(text: label.replaceAll(' ', '\u00A0'), style: link, recognizer: _toggle)],
    );

    if (!_fits(context, TextSpan(text: text, style: style), width)) {
      if (_open) return Text.rich(withLink('$text ', s.showLess));
      // The longest start of the text that still leaves room for the link.
      var lo = 0, hi = text.length;
      while (lo < hi) {
        final mid = (lo + hi + 1) ~/ 2;
        if (_fits(context, withLink('${text.substring(0, mid).trimRight()}… ', s.readMore), width)) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      // The whole folded text opens it, not only the link.
      return GestureDetector(
        onTap: _toggle.onTap,
        child: Text.rich(withLink('${text.substring(0, lo).trimRight()}… ', s.readMore)),
      );
    }
    return Text(text, style: style);
  }

  bool _fits(BuildContext context, TextSpan span, double width) {
    final painter = TextPainter(
      text: span,
      maxLines: widget.foldedLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }
}

/// A soft grey card with an orange-to-violet border around [child].
class GradientFrame extends StatelessWidget {
  const GradientFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    this.color = const Color(0xFFF7F7F8),
    this.radius = 20,
    this.expand = true,
  });

  final Widget child;
  final EdgeInsets padding;

  /// The fill inside the border.
  final Color color;

  /// 20 for a card; a large one makes a pill.
  final double radius;

  /// Full width (a card), or only as wide as [child] (a pill).
  final bool expand;

  static const _borderWidth = 1.2;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFFFFA36C), Color(0xFFF3B9C9), Color(0xFFA66CF5)],
        ),
      ),
      child: Container(
        width: expand ? double.infinity : null,
        margin: const EdgeInsets.all(_borderWidth),
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius - _borderWidth)),
        child: child,
      ),
    );
  }
}

/// A heading and its content in a [GradientFrame]: the overview, the region
/// map.
class GradientCard extends StatelessWidget {
  const GradientCard({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GradientFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.sans(20, weight: FontWeight.w700, color: AppColors.sand900),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppText.sans(14, color: AppColors.sand500)),
          ],
          SizedBox(height: subtitle == null ? 8 : 14),
          child,
        ],
      ),
    );
  }
}
