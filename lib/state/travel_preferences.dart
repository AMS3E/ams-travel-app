import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One of the eight things a traveller can say they are here for, picked
/// during onboarding.
class TravelInterest {
  const TravelInterest({required this.key, required this.icon, required this.categories});

  final String key;
  final IconData icon;

  /// Destination categories this interest covers, used to pick places for the
  /// "Picked for you" row on Home.
  final List<String> categories;
}

const travelInterests = <TravelInterest>[
  TravelInterest(
    key: 'history-culture',
    icon: Icons.account_balance_rounded,
    categories: [
      'Temples',
      'Ancient Cities',
      'Archaeological Sites',
      'Museums',
      'Bridges',
      'Hospitals',
      'Ancient Roads',
      'Sacred Mountain',
      'Indigenous Culture',
      'City Walk',
    ],
  ),
  TravelInterest(
    key: 'food-local-life',
    icon: Icons.ramen_dining_rounded,
    categories: [
      'Street Food',
      'Traditional Food',
      'Night Market',
      'Seafood',
      'Coffee',
      'Farm',
      'Rice',
      'Cooking Class',
      'Fine Dining',
      'Michelin',
      'Shopping',
    ],
  ),
  TravelInterest(
    key: 'nature-adventure',
    icon: Icons.park_rounded,
    categories: [
      'Waterfall',
      'Mountain',
      'National Park',
      'Forest',
      'Wildlife',
      'Trekking',
      'Adventure',
      'Cave',
      'Cycling',
      'Camping',
      'Viewpoint',
      'Volcano Lake',
      'Bird Watching',
      'Bird Sanctuary',
      'Mangrove',
    ],
  ),
  TravelInterest(
    key: 'wellness-relaxation',
    icon: Icons.self_improvement_rounded,
    categories: ['Spa', 'Luxury Hotel', 'Eco Lodge', 'Sunset', 'Sky Bar', 'Golf'],
  ),
  TravelInterest(
    key: 'beaches-islands',
    icon: Icons.beach_access_rounded,
    categories: [
      'Beach',
      'Island',
      'Private Island',
      'Coral',
      'Snorkeling',
      'Diving',
      'Yacht',
      'Cruise',
      'Boat Trip',
      'Fishing',
      'River Island',
      'Floating Village',
    ],
  ),
  TravelInterest(
    key: 'arts-crafts',
    icon: Icons.palette_rounded,
    categories: ['Craft', 'Art Gallery', 'Museums', 'Shopping'],
  ),
  TravelInterest(
    key: 'experience-travel',
    icon: Icons.backpack_rounded,
    categories: [
      'Homestay',
      'Community',
      'Village',
      'Local Guide',
      'Private Guide',
      'VIP Tour',
      'Agriculture',
      'Helicopter',
      'Photography',
    ],
  ),
  TravelInterest(
    key: 'family-activities',
    icon: Icons.family_restroom_rounded,
    categories: ['Floating Village', 'Beach', 'National Park', 'Museums', 'Night Market', 'Camping', 'Boat Trip'],
  ),
];

/// What the traveller chose during onboarding, kept on the device.
///
/// TODO(api): send these to the backend with the account once it exists.
class TravelPreferences extends ChangeNotifier {
  TravelPreferences(this._prefs) : _selected = (_prefs.getStringList(_key) ?? const []).toSet();

  static const _key = 'ams-travel:travel-interests';
  final SharedPreferences _prefs;
  Set<String> _selected;

  Set<String> get selected => _selected;
  bool get isEmpty => _selected.isEmpty;
  bool has(String key) => _selected.contains(key);

  /// Categories covered by everything chosen.
  Set<String> get categories => {
    for (final i in travelInterests)
      if (_selected.contains(i.key)) ...i.categories,
  };

  /// Forgets every pick, so onboarding starts with nothing chosen again.
  Future<void> clear() async {
    _selected = {};
    await _prefs.remove(_key);
    notifyListeners();
  }

  void toggle(String key) {
    _selected = {..._selected};
    if (!_selected.remove(key)) _selected.add(key);
    _prefs.setStringList(_key, _selected.toList());
    notifyListeners();
  }
}
