import 'package:trip_manager/models/trip_conditions_model.dart';
import 'package:trip_manager/models/vehicle_model.dart';

enum TripStatus { pending, approved, rejected, ongoing, completed }

extension TripStatusExt on TripStatus {
  String get label {
    switch (this) {
      case TripStatus.pending: return 'Pending';
      case TripStatus.approved: return 'Approved';
      case TripStatus.rejected: return 'Rejected';
      case TripStatus.ongoing: return 'Ongoing';
      case TripStatus.completed: return 'Completed';
    }
  }
}

class TripModel {
  final String id;
  final String requestedBy;
  final String? requestedByName;
  final String fromLocation;
  final String toLocation;
  final DateTime tripDate;
  final String tentativeTime;
  final String? description;
  final String? coTravelers;
  final TripStatus status;
  final String? approvedBy;
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final TripConditionsModel? conditions;
  final TripAssignment? assignment;

  TripModel({
    required this.id, required this.requestedBy, this.requestedByName,
    required this.fromLocation, required this.toLocation, required this.tripDate,
    required this.tentativeTime, this.description, this.coTravelers, required this.status,
    this.approvedBy, this.rejectionReason, required this.requestedAt,
    this.reviewedAt, this.conditions, this.assignment,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
    id: json['id'] ?? '',
    requestedBy: json['requested_by'] ?? '',
    requestedByName: json['users']?['user_name'],
    fromLocation: json['from_location'] ?? '',
    toLocation: json['to_location'] ?? '',
    tripDate: json['trip_date'] != null ? (DateTime.tryParse(json['trip_date'].toString()) ?? DateTime.now()) : DateTime.now(),
    tentativeTime: json['tentative_time'] ?? '',
    description: json['description'],
    coTravelers: json['co_travelers'],
    status: TripStatus.values.firstWhere((e) => e.name == json['status']?.toString(), orElse: () => TripStatus.pending),
    approvedBy: json['approved_by'],
    rejectionReason: json['rejection_reason'],
    requestedAt: json['requested_at'] != null ? (DateTime.tryParse(json['requested_at'].toString()) ?? DateTime.now()) : DateTime.now(),
    reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null,
    conditions: _parseConditions(json),
    assignment: _parseAssignment(json),
  );

  static TripConditionsModel? _parseConditions(Map<String, dynamic> json) {
    final cond = json['trip_conditions'];
    if (cond == null) return null;
    if (cond is List) {
      if (cond.isEmpty || cond[0] == null) return null;
      return TripConditionsModel.fromJson(cond[0] as Map<String, dynamic>);
    } else if (cond is Map) {
      return TripConditionsModel.fromJson(Map<String, dynamic>.from(cond));
    }
    return null;
  }

  static TripAssignment? _parseAssignment(Map<String, dynamic> json) {
    final assign = json['trip_assignments'];
    if (assign == null) return null;
    if (assign is List) {
      if (assign.isEmpty || assign[0] == null) return null;
      return TripAssignment.fromJson(assign[0] as Map<String, dynamic>);
    } else if (assign is Map) {
      return TripAssignment.fromJson(Map<String, dynamic>.from(assign));
    }
    return null;
  }
}

class TripAssignment {
  final String id;
  final String tripId;
  final String driverId;
  final String vehicleId;
  final DateTime? assignedAt;
  final VehicleModel? vehicle;
  final String? driverName;
  final DriverDeclaration? declaration;

  TripAssignment({required this.id, required this.tripId, required this.driverId,
    required this.vehicleId, this.assignedAt, this.vehicle, this.driverName, this.declaration});

  factory TripAssignment.fromJson(Map<String, dynamic> json) => TripAssignment(
    id: json['id']?.toString() ?? '',
    tripId: json['trip_id']?.toString() ?? '',
    driverId: json['driver_id']?.toString() ?? '',
    vehicleId: json['vehicle_id']?.toString() ?? '',
    assignedAt: json['assigned_at'] != null ? DateTime.tryParse(json['assigned_at'].toString()) : null,
    vehicle: _parseVehicle(json),
    driverName: _parseDriverName(json),
    declaration: _parseDeclaration(json),
  );

  static VehicleModel? _parseVehicle(Map<String, dynamic> json) {
    final veh = json['vehicles'];
    if (veh == null) return null;
    if (veh is List) {
      if (veh.isEmpty || veh[0] == null) return null;
      return VehicleModel.fromJson(veh[0] as Map<String, dynamic>);
    } else if (veh is Map) {
      return VehicleModel.fromJson(Map<String, dynamic>.from(veh));
    }
    return null;
  }

  static String? _parseDriverName(Map<String, dynamic> json) {
    final drivers = json['drivers'];
    if (drivers == null) return null;
    if (drivers is List) {
      if (drivers.isEmpty || drivers[0] == null) return null;
      final firstDriver = drivers[0];
      if (firstDriver is Map) {
        final users = firstDriver['users'];
        if (users is Map) {
          return users['user_name']?.toString();
        }
      }
    } else if (drivers is Map) {
      final users = drivers['users'];
      if (users is Map) {
        return users['user_name']?.toString();
      }
    }
    return null;
  }

  static DriverDeclaration? _parseDeclaration(Map<String, dynamic> json) {
    final dec = json['driver_declarations'];
    if (dec == null) return null;
    if (dec is List) {
      if (dec.isEmpty || dec[0] == null) return null;
      return DriverDeclaration.fromJson(dec[0] as Map<String, dynamic>);
    } else if (dec is Map) {
      return DriverDeclaration.fromJson(Map<String, dynamic>.from(dec));
    }
    return null;
  }
}

class DriverDeclaration {
  final String id;
  final String tripAssignmentId;
  final bool hasValidLicence;
  final bool isPhysicallyFit;
  final bool vehicleRoadworthy;
  final bool isSubstanceFree;
  final bool docsAvailable;
  final bool submitted;
  final DateTime? submittedAt;

  DriverDeclaration({
    required this.id, required this.tripAssignmentId, required this.hasValidLicence,
    required this.isPhysicallyFit, required this.vehicleRoadworthy, required this.isSubstanceFree,
    required this.docsAvailable, required this.submitted, this.submittedAt,
  });

  factory DriverDeclaration.fromJson(Map<String, dynamic> json) => DriverDeclaration(
    id: json['id']?.toString() ?? '',
    tripAssignmentId: json['trip_assignment_id']?.toString() ?? '',
    hasValidLicence: json['has_valid_licence'] ?? false,
    isPhysicallyFit: json['is_physically_fit'] ?? false,
    vehicleRoadworthy: json['vehicle_roadworthy'] ?? false,
    isSubstanceFree: json['is_substance_free'] ?? false,
    docsAvailable: json['docs_available'] ?? false,
    submitted: json['submitted'] ?? false,
    submittedAt: json['submitted_at'] != null ? DateTime.tryParse(json['submitted_at'].toString()) : null,
  );

  bool get allChecked => hasValidLicence && isPhysicallyFit && vehicleRoadworthy && isSubstanceFree && docsAvailable;
}
