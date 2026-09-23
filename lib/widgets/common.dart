import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 12, 0),
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[Text(eyebrow!, style: AppText.eyebrow()), const SizedBox(height: 6)],
                Text(title, style: AppText.display(24)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: AppText.sans(14, color: AppColors.sand500, height: 1.45)),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.icon,
    this.color = AppColors.brand700,
    this.background = AppColors.brand50,
    this.border,
  });

  /// White pill used on top of photos.
  const Pill.onImage(this.label, {super.key, this.icon})
    : color = AppColors.sand900,
      background = const Color(0xF2FFFFFF),
      border = null;

  /// Accent pill (UNESCO, trending growth).
  const Pill.accent(this.label, {super.key, this.icon})
    : color = Colors.white,
      background = AppColors.sunset500,
      border = null;

  final String label;
  final IconData? icon;
  final Color color;
  final Color background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(
            label,
            style: AppText.sans(11.5, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class Stars extends StatelessWidget {
  const Stars(this.value, {super.key, this.size = 16, this.onChanged});
  final int value;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: Padding(
              padding: EdgeInsets.only(right: onChanged == null ? 1 : 6),
              child: Icon(
                i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: i <= value ? AppColors.star : AppColors.sand300,
              ),
            ),
          ),
      ],
    );
  }
}

/// Secondary Khmer line under an English title, as on the website.
class KhmerText extends StatelessWidget {
  const KhmerText(this.text, {super.key, this.color = AppColors.sand500, this.size = 14});
  final String? text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Text(text!, style: AppText.sans(size, color: color, height: 1.6));
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(color: AppColors.brand50, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: AppColors.brand500),
          ),
          const SizedBox(height: 18),
          Text(title, style: AppText.display(21), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppText.sans(14, color: AppColors.sand500, height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 22),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: Image.asset('assets/images/logo.jpg', width: size, height: size, fit: BoxFit.cover),
  );
}

/// Big number + label (region stats, home stats).
class StatBlock extends StatelessWidget {
  const StatBlock({super.key, required this.value, this.suffix = '', required this.label, this.onDark = false});
  final String value;
  final String suffix;
  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final main = onDark ? Colors.white : AppColors.sand900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: AppText.display(26, color: main),
              ),
              if (suffix.isNotEmpty)
                TextSpan(
                  text: suffix,
                  style: AppText.display(16, color: onDark ? AppColors.sunset200 : AppColors.sunset500),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppText.sans(12, color: onDark ? Colors.white70 : AppColors.sand500)),
      ],
    );
  }
}

/// Round translucent button used on top of hero images.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onPressed, this.color, this.tooltip});
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.85),
          child: IconButton(
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, size: 21, color: color ?? AppColors.sand900),
          ),
        ),
      ),
    );
  }
}

/// White rounded card with a hairline border — the website's base surface.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: const BorderSide(color: AppColors.sand200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

void showToast(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, textColor: AppColors.sunset200, onPressed: onAction ?? () {}),
    ),
  );
}
