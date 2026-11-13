import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'device_location_helper.dart';

Future<GeoLocationResult> platformGetCurrentLocation() async {
  try {
    bool serviceEnabled = false;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } on MissingPluginException {
      throw Exception('GPS plugin requires an app restart. Please stop and re-run the app to activate location services.');
    } catch (_) {
      serviceEnabled = true;
    }

    if (!serviceEnabled) {
      throw Exception('Location service (GPS) is turned off. Please turn on GPS in your device settings.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied. Please allow location access to set restaurant GPS.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please allow location in device settings.');
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    return GeoLocationResult(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
    );
  } on MissingPluginException {
    throw Exception('GPS plugin requires an app restart. Please stop and re-run the app to activate location services.');
  }
}
