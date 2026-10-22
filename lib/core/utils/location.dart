import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Why the device position could not be read.
enum LocationProblem { serviceOff, denied, deniedForever, unavailable }

extension LocationProblemSettings on LocationProblem? {
  /// Only the phone's settings can fix it: asking again does nothing.
  bool get needsSettings => this == LocationProblem.deniedForever || this == LocationProblem.serviceOff;
}

/// The device position, or why there is none.
class DeviceLocation {
  const DeviceLocation._(this.latitude, this.longitude, this.problem);

  /// A position already known (a test's).
  const DeviceLocation.at(double this.latitude, double this.longitude) : problem = null;

  final double? latitude;
  final double? longitude;
  final LocationProblem? problem;

  bool get ok => problem == null;
}

/// Asks for permission when needed, then reads the position once.
/// Used by Explore by Nearby and the map.
Future<DeviceLocation> currentLocation({bool ask = true}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const DeviceLocation._(null, null, LocationProblem.serviceOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && ask) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const DeviceLocation._(null, null, LocationProblem.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      return const DeviceLocation._(null, null, LocationProblem.denied);
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    return DeviceLocation._(p.latitude, p.longitude, null);
  } catch (_) {
    return const DeviceLocation._(null, null, LocationProblem.unavailable);
  }
}

/// The phone's last known position, without asking for permission or
/// waiting for a fresh fix. Null when there is none or access is not granted.
/// Lets the map jump to the traveller at once while [currentLocation] runs.
Future<DeviceLocation?> lastKnownLocation() async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return null;
    final p = await Geolocator.getLastKnownPosition();
    if (p == null) return null;
    return DeviceLocation._(p.latitude, p.longitude, null);
  } catch (_) {
    return null;
  }
}

/// The device position each time it moves at least [distanceMeters]. Only
/// call it once access is granted ([currentLocation] came back ok).
Stream<DeviceLocation> watchLocation({int distanceMeters = 10}) => Geolocator.getPositionStream(
  locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceMeters),
).map((p) => DeviceLocation._(p.latitude, p.longitude, null));

/// Opens the settings page that fixes [problem]: the phone's location
/// switch when it is off, otherwise the app's own permission page.
Future<void> openLocationSettings([LocationProblem? problem]) =>
    problem == LocationProblem.serviceOff ? Geolocator.openLocationSettings() : Geolocator.openAppSettings();

/// The town and country for a position ("Siem Reap, Cambodia"), from the
/// phone's own geocoder. Null when it cannot tell.
Future<String?> placeName(double latitude, double longitude) async {
  try {
    final marks = await geo.Geocoding().placemarkFromCoordinates(latitude, longitude);
    if (marks.isEmpty) return null;
    final m = marks.first;
    String? firstOf(List<String?> values) {
      for (final v in values) {
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final town = firstOf([m.locality, m.subAdministrativeArea, m.administrativeArea]);
    final country = firstOf([m.country]);
    final name = [?town, ?country].join(', ');
    return name.isEmpty ? null : name;
  } catch (_) {
    return null;
  }
}

/// Opens the device's maps app with directions to a point.
Future<void> openDirections(double latitude, double longitude) => launchUrl(
  Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude'),
  mode: LaunchMode.externalApplication,
);
