import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:trip_manager/models/trip_conditions_model.dart';
import 'package:trip_manager/services/location_service.dart';

class WeatherResult {
  final WeatherCondition condition;
  final int temperature;
  final Visibility visibility;
  final bool isSafe;
  final String description;

  WeatherResult({required this.condition, required this.temperature,
    required this.visibility, required this.isSafe, required this.description});
}

class RoadResult {
  final RoadCondition condition;
  final String? hazards;
  final bool isSafe;
  final double distanceKm;
  final String routeSummary;

  RoadResult({required this.condition, this.hazards, required this.isSafe,
    required this.distanceKm, required this.routeSummary});
}

class WeatherService {
  static final _dio = Dio();

  static Future<WeatherResult> fetchWeather(String locationName) async {
    try {
      final apiKey = dotenv.env['OPENWEATHER_API_KEY'] ?? '';
      
      double lat;
      double lon;

      // Try cross-platform Google Geocoding first
      final googleCoords = await LocationService.geocodeAddress(locationName);
      if (googleCoords != null) {
        lat = googleCoords.latitude;
        lon = googleCoords.longitude;
      } else {
        // Fallback to native geocoding
        List<Location> locations = await locationFromAddress(locationName);
        if (locations.isEmpty) throw Exception('Location not found');
        lat = locations.first.latitude;
        lon = locations.first.longitude;
      }

      final res = await _dio.get(
        'https://api.openweathermap.org/data/2.5/weather',
        queryParameters: {'lat': lat, 'lon': lon, 'appid': apiKey, 'units': 'metric'},
      );

      final data = res.data;
      final weatherMain = data['weather'][0]['main'] as String;
      final temp = (data['main']['temp'] as num).round();
      final visibilityM = data['visibility'] as int? ?? 10000;

      WeatherCondition condition;
      if (['Thunderstorm', 'Tornado', 'Squall'].contains(weatherMain)) {
        condition = WeatherCondition.stormy;
      } else if (['Rain', 'Drizzle', 'Snow'].contains(weatherMain)) {
        condition = WeatherCondition.rainy;
      } else if (['Mist', 'Fog', 'Haze', 'Smoke', 'Dust', 'Sand'].contains(weatherMain)) {
        condition = WeatherCondition.foggy;
      } else {
        condition = WeatherCondition.clear;
      }

      Visibility vis;
      if (visibilityM >= 7000) vis = Visibility.good;
      else if (visibilityM >= 3000) vis = Visibility.moderate;
      else vis = Visibility.poor;

      final isSafe = condition != WeatherCondition.stormy && vis != Visibility.poor;

      return WeatherResult(
        condition: condition, temperature: temp, visibility: vis,
        isSafe: isSafe, description: data['weather'][0]['description'],
      );
    } catch (e) {
      // Fallback safe default on error
      return WeatherResult(
        condition: WeatherCondition.clear, temperature: 25,
        visibility: Visibility.good, isSafe: true, description: 'Data unavailable',
      );
    }
  }

  static Future<RoadResult> fetchRoadConditions(String from, String to) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': from, 'destination': to,
          'key': apiKey, 'departure_time': 'now',
        },
      );

      final data = res.data;
      if (data['status'] != 'OK') throw Exception('Directions API error');

      final route = data['routes'][0];
      final leg = route['legs'][0];
      final distanceM = (leg['distance']['value'] as num).round();
      final durationTraffic = leg['duration_in_traffic']?['value'] != null
          ? (leg['duration_in_traffic']['value'] as num).round()
          : null;
      final durationNormal = (leg['duration']['value'] as num).round();
      final summary = route['summary'] as String? ?? '$from to $to';

      // Infer congestion from traffic vs normal time ratio
      RoadCondition condition = RoadCondition.good;
      String? hazards;
      bool isSafe = true;

      if (durationTraffic != null) {
        final ratio = durationTraffic / durationNormal;
        if (ratio > 1.8) {
          condition = RoadCondition.damaged;
          hazards = 'Heavy congestion detected on route. Estimated delay: ${((durationTraffic - durationNormal) / 60).round()} minutes.';
          isSafe = false;
        } else if (ratio > 1.3) {
          condition = RoadCondition.underConstruction;
          hazards = 'Moderate traffic or construction ahead. Possible delays.';
        }
      }

      return RoadResult(
        condition: condition, hazards: hazards, isSafe: isSafe,
        distanceKm: distanceM / 1000, routeSummary: summary,
      );
    } catch (e) {
      return RoadResult(
        condition: RoadCondition.good, isSafe: true,
        distanceKm: 0, routeSummary: '$from → $to',
      );
    }
  }

  static Future<Map<String, dynamic>> fetchAllConditions(String from, String to) async {
    final weather = await fetchWeather(from);
    final road = await fetchRoadConditions(from, to);
    final isSafe = weather.isSafe && road.isSafe;

    return {
      'weather_condition': weather.condition.name,
      'temperature': weather.temperature,
      'visibility': weather.visibility.name,
      'road_condition': road.condition.name,
      'road_hazards': road.hazards,
      'is_safe_to_travel': isSafe,
      'fetched_at': DateTime.now().toIso8601String(),
    };
  }
}
