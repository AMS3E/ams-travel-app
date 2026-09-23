import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/travel_preferences.dart';


/// Labels for the eight interests, in the current language.
String interestLabel(S s, String key) => switch (key) {
  'history-culture' => s.interestHistory,
  'food-local-life' => s.interestFood,
  'nature-adventure' => s.interestNature,
  'wellness-relaxation' => s.interestWellness,
  'beaches-islands' => s.interestBeaches,
  'arts-crafts' => s.interestArts,
  'experience-travel' => s.interestExperience,
  _ => s.interestFamily,
};

/// "Make your journey yours" — the second onboarding step, also reachable
/// later from Profile to change the answers.
class InterestsStep extends StatelessWidget {
  const InterestsStep({super.key, this.onContinue});

  /// Set while this is a page of the onboarding flow; null when opened on its
  /// own from Profile, where it just saves and closes.
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final prefs = context.watch<TravelPreferences>();
    final standalone = onContinue == null;
    final enabled = standalone || !prefs.isEmpty;
    final labelColor = enabled ? Colors.white : AppColors.sand400;

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            if (standalone)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(24, standalone ? 4 : 52, 24, 8),
                children: [
                  Text(
                    s.interestsTitle2,
                    style: AppText.sans(27, weight: FontWeight.w800, color: AppColors.sand900, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.interestsSubtitle,
                    style: AppText.sans(15, weight: FontWeight.w500, color: AppColors.sand600, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 14,
                      mainAxisExtent: 110,
                    ),
                    itemCount: travelInterests.length,
                    itemBuilder: (context, i) {
                      final interest = travelInterests[i];
                      return _InterestTile(
                        icon: interest.icon,
                        label: interestLabel(s, interest.key),
                        selected: prefs.has(interest.key),
                        onTap: () => context.read<TravelPreferences>().toggle(interest.key),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              // Bottom room for the flow's page dots.
              padding: EdgeInsets.fromLTRB(24, 8, 24, standalone ? 16 : 36),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    disabledBackgroundColor: AppColors.sand100,
                    disabledForegroundColor: AppColors.sand400,
                    minimumSize: const Size(0, 58),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: !enabled
                      ? null
                      : () {
                          if (standalone) {
                            context.pop();
                          } else {
                            onContinue!();
                          }
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          standalone ? s.save : (prefs.isEmpty ? s.startJourney : s.continueJourney),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sans(16, weight: FontWeight.w700, color: labelColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, size: 19, color: labelColor),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestTile extends StatelessWidget {
  const _InterestTile({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: selected ? AppColors.violet : AppColors.sand200, width: selected ? 1.8 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(icon, size: 36, color: AppColors.sand900),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: AppText.sans(16, weight: FontWeight.w700, color: AppColors.sand900, height: 1.25),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selected)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.violet,
                borderRadius: BorderRadius.only(topRight: Radius.circular(21), bottomLeft: Radius.circular(16)),
              ),
              child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
