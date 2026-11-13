import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'device_location_helper.dart';

Future<GeoLocationResult> platformGetCurrentLocation() {
  final completer = Completer<GeoLocationResult>();

  final nav = web.window.navigator;
  final geolocation = nav.geolocation;

  final success = ((web.GeolocationPosition pos) {
    if (!completer.isCompleted) {
      completer.complete(GeoLocationResult(
        latitude: pos.coords.latitude.toDouble(),
        longitude: pos.coords.longitude.toDouble(),
        accuracy: pos.coords.accuracy.toDouble(),
      ));
    }
  }).toJS;

  final error = ((web.GeolocationPositionError err) {
    if (!completer.isCompleted) {
      final msg = err.message.isNotEmpty
          ? err.message
          : (err.code == 1
              ? 'Location permission denied in browser. Please allow location in your browser address bar.'
              : 'Unable to retrieve GPS location from browser.');
      completer.completeError(Exception(msg));
    }
  }).toJS;

  final options = web.PositionOptions(
    enableHighAccuracy: true,
    timeout: 15000,
    maximumAge: 0,
  );

  geolocation.getCurrentPosition(success, error, options);

  return completer.future;
}
