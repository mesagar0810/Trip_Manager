enum WeatherCondition { clear, rainy, foggy, stormy }
enum Visibility { good, moderate, poor }
enum RoadCondition { good, underConstruction, damaged }

class TripConditionsModel {
  final String id;
  final String tripRequestId;
  final WeatherCondition weatherCondition;
  final int temperature;
  final Visibility visibility;
  final RoadCondition roadCondition;
  final String? roadHazards;
  final bool isSafeToTravel;
  final DateTime fetchedAt;

  TripConditionsModel({
    required this.id, required this.tripRequestId, required this.weatherCondition,
    required this.temperature, required this.visibility, required this.roadCondition,
    this.roadHazards, required this.isSafeToTravel, required this.fetchedAt,
  });

  factory TripConditionsModel.fromJson(Map<String, dynamic> json) => TripConditionsModel(
    id: json['id']?.toString() ?? '',
    tripRequestId: json['trip_request_id']?.toString() ?? '',
    weatherCondition: WeatherCondition.values.firstWhere(
      (e) => e.name == json['weather_condition']?.toString(), orElse: () => WeatherCondition.clear),
    temperature: json['temperature'] != null ? int.tryParse(json['temperature'].toString()) ?? 0 : 0,
    visibility: Visibility.values.firstWhere(
      (e) => e.name == json['visibility']?.toString(), orElse: () => Visibility.good),
    roadCondition: RoadCondition.values.firstWhere(
      (e) => e.name == (json['road_condition'] as String?)?.replaceAll(' ', ''),
      orElse: () => RoadCondition.good),
    roadHazards: json['road_hazards']?.toString(),
    isSafeToTravel: json['is_safe_to_travel'] ?? true,
    fetchedAt: json['fetched_at'] != null ? (DateTime.tryParse(json['fetched_at'].toString()) ?? DateTime.now()) : DateTime.now(),
  );

  String get weatherLabel => weatherCondition.name[0].toUpperCase() + weatherCondition.name.substring(1);
  String get visibilityLabel => visibility.name[0].toUpperCase() + visibility.name.substring(1);
  String get roadConditionLabel {
    switch (roadCondition) {
      case RoadCondition.good: return 'Good';
      case RoadCondition.underConstruction: return 'Under Construction';
      case RoadCondition.damaged: return 'Damaged';
    }
  }
}
