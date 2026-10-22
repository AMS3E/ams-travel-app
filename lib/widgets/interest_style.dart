import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../data/api/catalog.dart';

/// Icon and accent colour for each kind of interest.
const _styles = <String, (IconData, Color)>{
  'temple': (Icons.temple_buddhist_rounded, AppColors.brand600),
  'stay': (Icons.hotel_rounded, AppColors.plum600),
  'food': (Icons.restaurant_rounded, Color(0xFFC05621)),
  'water': (Icons.water_rounded, Color(0xFF0987A0)),
  'activity': (Icons.hiking_rounded, Color(0xFF2F855A)),
  'route': (Icons.route_rounded, AppColors.sunset500),
};

/// The style of each of the six interest groups, by the API's group name.
const _groupIcons = {
  'Attraction Sites': 'temple',
  'Stays': 'stay',
  'Food': 'food',
  'Water': 'water',
  'Activities & Experiences': 'activity',
  'Tourism Corridors': 'route',
};

(IconData, Color) groupStyle(String groupName) =>
    _styles[_groupIcons[groupName]] ?? (Icons.interests_rounded, AppColors.brand600);

/// The interests' `iconKey`s as line symbols.
const _interestIcons = <String, IconData>{
  'sun': Icons.wb_twilight_rounded,
  'waves': Icons.waves_rounded,
  'temple': Icons.temple_buddhist_outlined,
  'building': Icons.apartment_rounded,
  'utensils': Icons.restaurant_rounded,
  'sparkles': Icons.auto_awesome_outlined,
  'home': Icons.home_outlined,
  'leaf': Icons.eco_outlined,
  'tree': Icons.park_outlined,
  'mountain': Icons.landscape_outlined,
  'camera': Icons.photo_camera_outlined,
  'route': Icons.route_outlined,
  'briefcase': Icons.work_outline_rounded,
};

/// An interest's own line symbol, else its group's.
IconData interestIcon(CatalogInterest interest) =>
    _interestIcons[interest.iconKey] ?? groupStyle(interest.groupName).$1;
