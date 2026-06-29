enum JourneyStatus { notStarted, ongoing, completed }

class TripLogModel {
  final String id;
  final String tripId;
  final DateTime? journeyStartedAt;
  final DateTime? journeyEndedAt;
  final JourneyStatus currentStatus;
  final double? currentLat;
  final double? currentLng;

  TripLogModel({required this.id, required this.tripId, this.journeyStartedAt,
    this.journeyEndedAt, required this.currentStatus, this.currentLat, this.currentLng});

  factory TripLogModel.fromJson(Map<String, dynamic> json) => TripLogModel(
    id: json['id'] ?? '',
    tripId: json['trip_id'] ?? '',
    journeyStartedAt: json['journey_started_at'] != null ? DateTime.tryParse(json['journey_started_at'].toString()) : null,
    journeyEndedAt: json['journey_ended_at'] != null ? DateTime.tryParse(json['journey_ended_at'].toString()) : null,
    currentStatus: JourneyStatus.values.firstWhere(
      (e) => e.name == json['current_status']?.toString().replaceAll(' ', ''),
      orElse: () => JourneyStatus.notStarted,
    ),
    currentLat: json['current_lat'] != null ? double.tryParse(json['current_lat'].toString()) : null,
    currentLng: json['current_lng'] != null ? double.tryParse(json['current_lng'].toString()) : null,
  );
}
