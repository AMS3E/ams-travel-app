import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';

/// Network image with a soft placeholder and disk cache.
class AppImage extends StatelessWidget {
  const AppImage(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height, this.radius});

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? radius;

  /// Widget tests have no disk-cache plugins; they flip this off.
  @visibleForTesting
  static bool useDiskCache = true;

  @override
  Widget build(BuildContext context) {
    Widget child = url.isEmpty
        ? const _Placeholder(icon: true)
        : !useDiskCache
        ? Image.network(
            url,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, _, _) => const _Placeholder(icon: true),
          )
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            width: width,
            height: height,
            fadeInDuration: const Duration(milliseconds: 250),
            placeholder: (_, _) => const _Placeholder(),
            errorWidget: (_, _, _) => const _Placeholder(icon: true),
          );
    if (radius != null) child = ClipRRect(borderRadius: radius!, child: child);
    return SizedBox(width: width, height: height, child: child);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.icon = false});
  final bool icon;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.sand200, AppColors.brand100],
      ),
    ),
    alignment: Alignment.center,
    child: icon ? const Icon(Icons.landscape_rounded, color: AppColors.brand300, size: 32) : null,
  );
}

