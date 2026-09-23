import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../state/locale_provider.dart';

/// EN | ខ្មែរ switch, like the website header.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key, this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    Widget option(String label, bool km) {
      final selected = locale.isKhmer == km;
      return GestureDetector(
        onTap: () => locale.setKhmer(km),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? (onDark ? Colors.white : AppColors.brand600) : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: AppText.sans(
              12.5,
              weight: FontWeight.w600,
              color: selected
                  ? (onDark ? AppColors.brand900 : Colors.white)
                  : (onDark ? Colors.white : AppColors.sand600),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.16) : AppColors.sand100,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: onDark ? Colors.white24 : AppColors.sand200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [option('EN', false), option('ខ្មែរ', true)]),
    );
  }
}
