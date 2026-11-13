import 'device_location_helper_stub.dart'
    if (dart.library.js_interop) 'device_location_helper_web.dart';

class GeoLocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;

  const GeoLocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}

class DeviceLocationHelper {
  DeviceLocationHelper._();

  /// Captures current device location across Web (HTML5 Geolocation),
  /// Android, iOS, and Desktop.
  static Future<GeoLocationResult> getCurrentLocation() {
    return platformGetCurrentLocation();
  }
}
