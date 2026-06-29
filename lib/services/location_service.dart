import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_manager/services/supabase_service.dart';

class LocationService {
  static StreamSubscription<Position>? _subscription;
  static Timer? _timer;

  static Future<LatLng?> geocodeAddress(String address) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      if (apiKey.isEmpty) return null;
      final dio = Dio();
      final res = await dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'address': address,
          'key': apiKey,
        },
      );
      if (res.statusCode == 200 && res.data['status'] == 'OK') {
        final results = res.data['results'] as List;
        if (results.isNotEmpty) {
          final loc = results.first['geometry']['location'];
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('Error forward geocoding: $e');
    }
    return null;
  }

  static Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      if (apiKey.isEmpty) return 'No API Key';
      final dio = Dio();
      final res = await dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': apiKey,
        },
      );
      if (res.statusCode == 200 && res.data['status'] == 'OK') {
        final results = res.data['results'] as List;
        if (results.isNotEmpty) {
          return results.first['formatted_address'] as String;
        }
      }
      return 'Address not found';
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      return 'Error fetching address';
    }
  }

  static Future<List<String>> getPlaceSuggestions(String input) async {
    if (input.trim().isEmpty) return [];
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        debugPrint('GOOGLE_MAPS_API_KEY is empty in .env');
        return [];
      }
      final dio = Dio();
      final res = await dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': input,
          'key': apiKey,
        },
      );
      if (res.statusCode == 200 && res.data['status'] == 'OK') {
        final predictions = res.data['predictions'] as List;
        return predictions.map<String>((p) => p['description'] as String).toList();
      } else {
        debugPrint('Google Places API response status: ${res.data['status']}');
      }
    } catch (e) {
      debugPrint('Error fetching place suggestions: $e');
    }
    return [];
  }

  static Future<bool> requestPermission() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final isGranted = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
      if (!isGranted) {
        debugPrint('Location permission was denied or denied forever.');
        return false;
      }

      // Check if service is enabled, but don't block returning true if permission was granted.
      // Geolocator operations will handle service disabled errors when they are actually called.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled on this device, but permission is granted.');
      }
      return true;
    } catch (e) {
      debugPrint('Error checking or requesting location permission: $e');
      return false;
    }
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      if (!await requestPermission()) return null;
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  static Future<bool> startTracking(String logId) async {
    try {
      _subscription?.cancel();
      _subscription = null;
      _timer?.cancel();
      _timer = null;

      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint('Location permission not granted for active tracking');
        return false;
      }

      // Get initial position immediately to seed tracking
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        await SupabaseService.updateLocation(logId, pos.latitude, pos.longitude);
      } catch (e) {
        debugPrint('Error getting initial location: $e');
      }

      // Query coordinates every 10 minutes to protect battery life
      _timer = Timer.periodic(const Duration(minutes: 10), (timer) async {
        try {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
          await SupabaseService.updateLocation(logId, pos.latitude, pos.longitude);
        } catch (e) {
          debugPrint('Error updating location in periodic callback: $e');
        }
      });
      return true;
    } catch (e) {
      debugPrint('Exception in startTracking: $e');
      return false;
    }
  }

  static void stopTracking() {
    try {
      _subscription?.cancel();
      _subscription = null;
      _timer?.cancel();
      _timer = null;
    } catch (e) {
      debugPrint('Error stopping tracking: $e');
    }
  }
}
