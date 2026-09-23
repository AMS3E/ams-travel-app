import 'json_utils.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.firstName,
    this.lastName,
    this.phone,
    this.location,
    this.joinedAt,
  });

  final String id;
  final String username;
  final String email;
  final String? avatarUrl;

  /// Split name and phone, as the account form collects them.
  final String? firstName;
  final String? lastName;
  final String? phone;

  /// Where the traveller is from, and when they signed up — both shown on the
  /// profile when the API sends them.
  final String? location;
  final DateTime? joinedAt;

  /// A copy with some details changed, for the account form.
  AppUser copyWith({
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? location,
  }) => AppUser(
    id: id,
    username: username ?? this.username,
    email: email ?? this.email,
    avatarUrl: avatarUrl,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    phone: phone ?? this.phone,
    location: location ?? this.location,
    joinedAt: joinedAt,
  );

  String get initials => username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();

  factory AppUser.fromJson(Json j) => AppUser(
    id: str(j, 'id', alt: ['_id', 'userId']),
    username: str(j, 'username', alt: ['name']),
    email: str(j, 'email'),
    avatarUrl: strOrNull(j, 'avatarUrl', alt: ['avatar']),
    firstName: strOrNull(j, 'firstName', alt: ['first_name', 'givenName']),
    lastName: strOrNull(j, 'lastName', alt: ['last_name', 'familyName']),
    phone: strOrNull(j, 'phone', alt: ['phoneNumber', 'tel']),
    location: strOrNull(j, 'location', alt: ['city', 'country']),
    joinedAt: DateTime.tryParse(strOrNull(j, 'joinedAt', alt: ['joined_at', 'createdAt']) ?? ''),
  );

  Json toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'avatarUrl': avatarUrl,
    if (firstName != null) 'firstName': firstName,
    if (lastName != null) 'lastName': lastName,
    if (phone != null) 'phone': phone,
    if (location != null) 'location': location,
    if (joinedAt != null) 'joinedAt': joinedAt!.toIso8601String(),
  };
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;

  /// Accepts `{token, user}` and `{accessToken, user}` shapes.
  factory AuthSession.fromJson(Json j) => AuthSession(
    token: str(j, 'token', alt: ['accessToken', 'access_token']),
    user: AppUser.fromJson(Json.from(j['user'] as Map)),
  );

  Json toJson() => {'token': token, 'user': user.toJson()};
}

class Review {
  const Review({
    required this.id,
    required this.author,
    required this.rating,
    this.title,
    this.text,
    this.tripType,
    this.visitedOn,
    this.photos = const [],
    this.destination,
    required this.createdAt,
  });

  final String id;
  final String author;
  final int rating;

  /// One-line summary the reviewer gave.
  final String? title;
  final String? text;

  /// Who they travelled with — business, couples, family, friends, solo.
  final String? tripType;

  /// The month they visited, which can be well before they wrote.
  final DateTime? visitedOn;
  final List<String> photos;

  /// "region/slug" of the place reviewed, when the API says which.
  final String? destination;
  final DateTime createdAt;

  factory Review.fromJson(Json j) => Review(
    id: str(j, 'id', alt: ['_id']),
    author: str(j, 'author', alt: ['username', 'userName']),
    rating: integer(j, 'rating'),
    title: strOrNull(j, 'title'),
    text: strOrNull(j, 'text', alt: ['comment', 'body']),
    tripType: strOrNull(j, 'tripType', alt: ['trip_type', 'visitType']),
    visitedOn: DateTime.tryParse(strOrNull(j, 'visitedOn', alt: ['visited_on']) ?? ''),
    photos: strList(j, 'photos', alt: ['images']),
    destination: strOrNull(j, 'destination', alt: ['destinationKey', 'place']),
    createdAt: DateTime.tryParse(str(j, 'createdAt', alt: ['created_at'])) ?? DateTime.now(),
  );

  Json toJson() => {
    'id': id,
    'author': author,
    'rating': rating,
    if (title != null) 'title': title,
    if (tripType != null) 'tripType': tripType,
    if (visitedOn != null) 'visitedOn': visitedOn!.toIso8601String(),
    if (photos.isNotEmpty) 'photos': photos,
    if (destination != null) 'destination': destination,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };
}
