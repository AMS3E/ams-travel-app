import 'json_utils.dart';

/// A bookable room in a stay.
class Room {
  const Room({
    required this.id,
    required this.name,
    required this.image,
    this.images = const [],
    this.description,
    required this.pricePerNight,
    this.currency = 'USD',
    this.guests = 2,
    this.beds,
    this.sizeSqm,
    this.amenities = const [],
    this.available = true,
  });

  final String id;
  final String name;
  final String image;

  /// Extra photos; [image] is the cover.
  final List<String> images;
  List<String> get gallery => [image, ...images.where((u) => u != image)];

  /// Longer text about the room, when the API has one.
  final String? description;

  final double pricePerNight;
  final String currency;

  /// How many people it sleeps.
  final int guests;

  /// "1 king bed", "2 twin beds"…
  final String? beds;
  final int? sizeSqm;
  final List<String> amenities;
  final bool available;

  factory Room.fromJson(Json j) => Room(
    id: str(j, 'id', alt: ['slug']),
    name: str(j, 'name', alt: ['title']),
    image: str(j, 'image', alt: ['imageUrl', 'image_url']),
    images: strList(j, 'images', alt: ['photos', 'gallery']),
    description: strOrNull(j, 'description', alt: ['detail', 'summary']),
    pricePerNight: dbl(j, 'pricePerNight', alt: ['price_per_night', 'price']) ?? 0,
    currency: strOrNull(j, 'currency') ?? 'USD',
    guests: j['guests'] == null ? 2 : integer(j, 'guests', alt: ['capacity'], fallback: 2),
    beds: strOrNull(j, 'beds', alt: ['bed']),
    sizeSqm: j['sizeSqm'] == null && j['size_sqm'] == null ? null : integer(j, 'sizeSqm', alt: ['size_sqm']),
    amenities: strList(j, 'amenities', alt: ['facilities']),
    available: j['available'] == null ? true : boolean(j, 'available'),
  );

  Json toJson() => {
    'id': id,
    'name': name,
    'image': image,
    if (images.isNotEmpty) 'images': images,
    if (description != null) 'description': description,
    'pricePerNight': pricePerNight,
    'currency': currency,
    'guests': guests,
    if (beds != null) 'beds': beds,
    if (sizeSqm != null) 'sizeSqm': sizeSqm,
    'amenities': amenities,
    'available': available,
  };
}
