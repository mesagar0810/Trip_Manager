class VehicleModel {
  final String id;
  final String vehicleNumber;
  final String model;
  final DateTime? lastServiceOn;
  final String? technicalNotes;
  final bool isActive;

  VehicleModel({required this.id, required this.vehicleNumber, required this.model,
    this.lastServiceOn, this.technicalNotes, required this.isActive});

  factory VehicleModel.fromJson(Map<String, dynamic> json) => VehicleModel(
    id: json['id']?.toString() ?? '',
    vehicleNumber: json['vehicle_number']?.toString() ?? '',
    model: json['model']?.toString() ?? '',
    lastServiceOn: json['last_service_on'] != null ? DateTime.tryParse(json['last_service_on'].toString()) : null,
    technicalNotes: json['technical_notes']?.toString(),
    isActive: json['is_active'] ?? true,
  );

  String get daysSinceService {
    if (lastServiceOn == null) return 'Unknown';
    final days = DateTime.now().difference(lastServiceOn!).inDays;
    if (days == 0) return 'Today';
    return '$days days ago';
  }
}
