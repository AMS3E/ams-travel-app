import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// The red the Tags section uses.
const tagChipRed = Color(0xFFE23E57);

/// A symbol for each category, for the chips in the Categories section.
/// Anything not listed falls back to a map pin.
const categoryIcons = <String, IconData>{
  'Adventure': Icons.terrain_rounded,
  'Agriculture': Icons.agriculture_rounded,
  'Ancient Cities': Icons.account_balance_rounded,
  'Ancient Roads': Icons.route_rounded,
  'Archaeological Sites': Icons.museum_rounded,
  'Art Gallery': Icons.palette_rounded,
  'Beach': Icons.beach_access_rounded,
  'Bird Sanctuary': Icons.flutter_dash_rounded,
  'Bird Watching': Icons.flutter_dash_rounded,
  'Boat Trip': Icons.directions_boat_rounded,
  'Bridges': Icons.linear_scale_rounded,
  'Camping': Icons.cabin_rounded,
  'Cave': Icons.dark_mode_rounded,
  'City Walk': Icons.directions_walk_rounded,
  'Coffee': Icons.local_cafe_rounded,
  'Community': Icons.groups_rounded,
  'Cooking Class': Icons.soup_kitchen_rounded,
  'Coral': Icons.waves_rounded,
  'Craft': Icons.handyman_rounded,
  'Cruise': Icons.sailing_rounded,
  'Cycling': Icons.pedal_bike_rounded,
  'Diving': Icons.scuba_diving_rounded,
  'Eco Lodge': Icons.cottage_rounded,
  'Farm': Icons.grass_rounded,
  'Fine Dining': Icons.restaurant_rounded,
  'Fishing': Icons.phishing_rounded,
  'Floating Village': Icons.houseboat_rounded,
  'Forest': Icons.forest_rounded,
  'Golf': Icons.golf_course_rounded,
  'Helicopter': Icons.flight_rounded,
  'Homestay': Icons.night_shelter_rounded,
  'Hospitals': Icons.local_hospital_rounded,
  'Indigenous Culture': Icons.diversity_3_rounded,
  'Island': Icons.beach_access_rounded,
  'Local Guide': Icons.tour_rounded,
  'Luxury Hotel': Icons.hotel_rounded,
  'Mangrove': Icons.park_rounded,
  'Michelin': Icons.star_rounded,
  'Mountain': Icons.landscape_rounded,
  'Museums': Icons.museum_rounded,
  'National Park': Icons.park_rounded,
  'Night Market': Icons.storefront_rounded,
  'Photography': Icons.photo_camera_rounded,
  'Private Guide': Icons.person_pin_rounded,
  'Private Island': Icons.holiday_village_rounded,
  'Rice': Icons.rice_bowl_rounded,
  'River Island': Icons.water_rounded,
  'Sacred Mountain': Icons.temple_buddhist_rounded,
  'Seafood': Icons.set_meal_rounded,
  'Shopping': Icons.shopping_bag_rounded,
  'Sky Bar': Icons.local_bar_rounded,
  'Snorkeling': Icons.pool_rounded,
  'Spa': Icons.spa_rounded,
  'Street Food': Icons.lunch_dining_rounded,
  'Sunset': Icons.wb_twilight_rounded,
  'Temples': Icons.temple_buddhist_rounded,
  'Traditional Food': Icons.ramen_dining_rounded,
  'Trekking': Icons.hiking_rounded,
  'VIP Tour': Icons.workspace_premium_rounded,
  'Viewpoint': Icons.visibility_rounded,
  'Village': Icons.holiday_village_rounded,
  'Volcano Lake': Icons.water_drop_rounded,
  'Waterfall': Icons.water_rounded,
  'Wildlife': Icons.pets_rounded,
  'Yacht': Icons.sailing_rounded,
};

class SectionBar extends StatelessWidget {
  const SectionBar({super.key, required this.title, required this.subtitle, required this.open, required this.onToggle});
  final String title;
  final String subtitle;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.sans(17, weight: FontWeight.w700, color: AppColors.sand900),
                ),
                Text(subtitle, style: AppText.sans(12, color: AppColors.sand500)),
              ],
            ),
          ),
          Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.sand500),
        ],
      ),
    );
  }
}

class PickChip extends StatelessWidget {
  const PickChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.violet,
    this.centred = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  /// Only the scope row stretches its chips, so only it needs the label
  /// pulled back into the middle.
  final bool centred;

  /// A symbol in front of the label, on the category chips.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: centred ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(99),
          // The scope row keeps its plain outline; the category and tag chips
          // are outlined in their own colour.
          border: Border.all(
            color: selected || !centred ? color.withValues(alpha: selected ? 1 : 0.5) : AppColors.sand200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppText.sans(13, weight: FontWeight.w600, color: selected ? Colors.white : AppColors.sand800),
            ),
          ],
        ),
      ),
    );
  }
}

class ViewAllChip extends StatelessWidget {
  const ViewAllChip({super.key, required this.label, required this.expanded, required this.onTap, this.color = AppColors.violet});
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.sans(13, weight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Icon(
              expanded ? Icons.remove_circle_rounded : Icons.add_circle_rounded,
              size: 17,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
