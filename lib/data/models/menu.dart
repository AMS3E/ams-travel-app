import 'json_utils.dart';

/// One dish or drink on a place's menu.
class MenuItem {
  const MenuItem({
    required this.name,
    this.nameKh,
    this.description,
    required this.price,
    this.currency = 'USD',
    this.image,
    this.popular = false,
    this.vegetarian = false,
    this.spicy = false,
  });

  final String name;
  final String? nameKh;

  /// What is in the dish, when the kitchen says.
  final String? description;

  /// In [currency]; the Preference page decides what it is shown in.
  final double price;
  final String currency;

  /// The photo on the dish card. Null shows the card without one.
  final String? image;

  /// What the kitchen is known for.
  final bool popular;
  final bool vegetarian;
  final bool spicy;

  factory MenuItem.fromJson(Json j) => MenuItem(
    name: str(j, 'name', alt: ['title']),
    nameKh: strOrNull(j, 'nameKh', alt: ['name_kh']),
    description: strOrNull(j, 'description', alt: ['detail']),
    price: dbl(j, 'price', alt: ['amount']) ?? 0,
    currency: strOrNull(j, 'currency') ?? 'USD',
    image: strOrNull(j, 'image', alt: ['imageUrl', 'image_url', 'photo']),
    popular: boolean(j, 'popular', alt: ['featured']),
    vegetarian: boolean(j, 'vegetarian', alt: ['veg']),
    spicy: boolean(j, 'spicy'),
  );

  Json toJson() => {
    'name': name,
    if (nameKh != null) 'nameKh': nameKh,
    if (description != null) 'description': description,
    'price': price,
    'currency': currency,
    if (image != null) 'image': image,
    if (popular) 'popular': true,
    if (vegetarian) 'vegetarian': true,
    if (spicy) 'spicy': true,
  };
}

/// A part of the menu — starters, mains, drinks — in the order the kitchen
/// lists them.
class MenuSection {
  const MenuSection({required this.name, this.nameKh, this.items = const []});

  final String name;
  final String? nameKh;
  final List<MenuItem> items;

  factory MenuSection.fromJson(Json j) => MenuSection(
    name: str(j, 'name', alt: ['title']),
    nameKh: strOrNull(j, 'nameKh', alt: ['name_kh']),
    items: objList(j, 'items', MenuItem.fromJson, alt: ['dishes']),
  );

  Json toJson() => {
    'name': name,
    if (nameKh != null) 'nameKh': nameKh,
    'items': [for (final i in items) i.toJson()],
  };
}
