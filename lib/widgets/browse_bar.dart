import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_strings.dart';
import '../core/router/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/models/models.dart';

/// The top of the browse pages: back arrow, the words being looked for, and
/// the search button. Tapping anywhere opens the type-ahead page.
class BrowseSearchBar extends StatelessWidget {
  const BrowseSearchBar({super.key, required this.hint, this.onWhite = false});

  final String hint;

  /// A white raised field (Popular) rather than the grey one.
  final bool onWhite;

  @override
  Widget build(BuildContext context) {
    void open() => context.push(Routes.popularSearch);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 30, color: AppColors.sand900),
          ),
          Expanded(
            child: Material(
              color: onWhite ? Colors.white : AppColors.sand100,
              borderRadius: BorderRadius.circular(16),
              elevation: onWhite ? 1.5 : 0,
              shadowColor: const Color(0x221C1935),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: open,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 5, 5, 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          hint,
                          style: AppText.sans(14.5, color: AppColors.sand400),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Material(
                        color: AppColors.violet,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: open,
                          child: const Padding(
                            padding: EdgeInsets.all(9),
                            child: Icon(Icons.search_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
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

/// The short name a browse page puts on an interest chip.
String shortInterestName(S s, Interest interest) => switch (interest.slug) {
  'attraction-sites' => s.quickAttraction,
  'stays' => s.quickStays,
  'food' => s.quickFood,
  'water' => s.quickNature,
  'activities-experiences' => s.quickExperiences,
  _ => interest.name,
};

/// One category along the top of a browse page.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.violet : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? AppColors.violet : AppColors.sand200),
        ),
        child: Text(
          label,
          style: AppText.sans(
            13.5,
            weight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.sand800,
          ),
        ),
      ),
    );
  }
}
