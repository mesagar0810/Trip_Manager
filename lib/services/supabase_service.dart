import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize({required String url, required String anonKey}) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  // Auth
  static Future<AuthResponse> signUp(String username, String password, String role) async {
    // 1. Check if user already exists
    final existing = await client.from('users').select('id, is_active').eq('user_name', username).maybeSingle();
    if (existing != null) {
      if (existing['is_active'] == true) {
        throw Exception('Username is already taken.');
      } else {
        // Inactive user -> Reactivate via RPC function!
        await client.rpc('reactivate_user', params: {
          'u_username': username,
          'u_password': password,
        });

        // Sign in to get the driver session and restore admin session to match the expected return profile
        final adminSession = client.auth.currentSession;
        final response = await client.auth.signInWithPassword(
          email: '$username@tripmanager.app',
          password: password,
        );
        if (adminSession != null && adminSession.refreshToken != null) {
          await client.auth.setSession(adminSession.refreshToken!);
        } else {
          await client.auth.signOut();
        }
        return response;
      }
    }

    // 2. Completely new user -> create fresh
    final email = '$username@tripmanager.app';
    final adminSession = client.auth.currentSession;
    
    final response = await client.auth.signUp(email: email, password: password);
    if (response.user != null) {
      await client.from('users').insert({
        'id': response.user!.id, 'user_name': username,
        'password': password, 'role': role,
        'is_active': true,
      });
      if (role == 'user') {
        await client.from('drivers').insert({'user_id': response.user!.id, 'is_active': true});
      }
      // Restore previous session if there was one to prevent admin log-out, otherwise sign out
      if (adminSession != null && adminSession.refreshToken != null) {
        await client.auth.setSession(adminSession.refreshToken!);
      } else {
        await client.auth.signOut();
      }
    }
    return response;
  }

  static Future<AuthResponse> signIn(String username, String password) async {
    final email = '$username@tripmanager.app';
    final response = await client.auth.signInWithPassword(email: email, password: password);
    final userId = response.user?.id;
    if (userId == null) throw Exception('Login failed.');

    // Check if user is active in the users table
    final userData = await client
        .from('users')
        .select('is_active')
        .eq('id', userId)
        .maybeSingle();

    if (userData != null && userData['is_active'] == false) {
      await client.auth.signOut();
      throw Exception('Your account has been deactivated. Please contact your administrator.');
    }
    return response;
  }

  static Future<void> signOut() async => await client.auth.signOut();

  static User? get currentUser => client.auth.currentUser;

  // User
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final res = await client.from('users').select().eq('id', userId).maybeSingle();
    return res;
  }

  // Trips
  static Future<List<Map<String, dynamic>>> getTripsForUser(String userId) async {
    return await client.from('trip_info')
        .select('*, trip_conditions(*), trip_assignments(*, vehicles(*), driver_declarations(*))')
        .eq('requested_by', userId)
        .order('requested_at', ascending: false);
  }
static Future<List<Map<String, dynamic>>> getAllTrips({String? status}) async {
  if (status != null && status != 'all') {
    return await client
        .from('trip_info')
        .select(
          '*, users:users!trip_info_requested_by_fkey(user_name), trip_conditions(*), trip_assignments(*, vehicles(*), drivers(*, users(user_name)), driver_declarations(*)), trip_logs(*)',
        )
        .eq('status', status)
        .order('requested_at', ascending: false);
  }

  return await client
      .from('trip_info')
      .select(
        '*, users:users!trip_info_requested_by_fkey(user_name), trip_conditions(*), trip_assignments(*, vehicles(*), drivers(*, users(user_name)), driver_declarations(*)), trip_logs(*)',
      )
      .order('requested_at', ascending: false);
}

  static Future<Map<String, dynamic>> createTrip(Map<String, dynamic> data) async {
    final res = await client.from('trip_info').insert(data).select().single();
    return res;
  }

  static Future<void> updateTripStatus(String tripId, String status,
      {String? approvedBy, String? rejectionReason}) async {
    final data = <String, dynamic>{
      'status': status, 'reviewed_at': DateTime.now().toIso8601String()
    };
    if (approvedBy != null) data['approved_by'] = approvedBy;
    if (rejectionReason != null) data['rejection_reason'] = rejectionReason;
    await client.from('trip_info').update(data).eq('id', tripId);
  }

  // Trip Conditions
  static Future<void> upsertTripConditions(Map<String, dynamic> data) async {
    await client.from('trip_conditions').upsert(data, onConflict: 'trip_request_id');
  }

  static Future<Map<String, dynamic>?> getTripConditions(String tripId) async {
    return await client.from('trip_conditions').select()
        .eq('trip_request_id', tripId).maybeSingle();
  }

  // Trip Assignment (driver self-assigns)
  static Future<Map<String, dynamic>> createAssignment(String tripId, String driverId, String vehicleId) async {
    return await client.from('trip_assignments').insert({
      'trip_id': tripId, 'driver_id': driverId,
      'vehicle_id': vehicleId, 'assigned_at': DateTime.now().toIso8601String(),
    }).select().single();
  }

  static Future<String?> getDriverId(String userId) async {
    final res = await client.from('drivers').select('id').eq('user_id', userId).maybeSingle();
    return res?['id'];
  }

  // Vehicles
  static Future<Map<String, dynamic>> createVehicle(Map<String, dynamic> data) async {
    return await client.from('vehicles').insert(data).select().single();
  }

  static Future<List<Map<String, dynamic>>> getAvailableVehicles() async {
    return await client.from('vehicles').select().eq('is_active', true);
  }

  // Drivers
  static Future<void> createDriver(String username, String password,
      {String? licenseNumber, String? licenseExpiry}) async {
    final response = await signUp(username, password, 'user');
    if (response.user != null) {
      final driverId = await getDriverId(response.user!.id);
      if (driverId != null) {
        final updateData = <String, dynamic>{};
        if (licenseNumber != null && licenseNumber.isNotEmpty) {
          updateData['license_number'] = licenseNumber;
        }
        if (licenseExpiry != null && licenseExpiry.isNotEmpty) {
          updateData['license_expiry'] = licenseExpiry;
        }
        if (updateData.isNotEmpty) {
          await client.from('drivers').update(updateData).eq('id', driverId);
        }
      }
    }
  }

  // Declaration
  static Future<void> submitDeclaration(Map<String, dynamic> data) async {
    await client.from('driver_declarations').upsert(data, onConflict: 'trip_assignment_id');
  }

  // Trip Logs
  static Future<Map<String, dynamic>> startJourney(String tripId) async {
    final res = await client.from('trip_logs').insert({
      'trip_id': tripId,
      'journey_started_at': DateTime.now().toIso8601String(),
      'current_status': 'ongoing',
    }).select().single();
    await client.from('trip_info').update({'status': 'ongoing'}).eq('id', tripId);
    return res;
  }

  static Future<void> endJourney(String tripId, String logId) async {
    await client.from('trip_logs').update({
      'journey_ended_at': DateTime.now().toIso8601String(),
      'current_status': 'completed',
    }).eq('id', logId);
    await client.from('trip_info').update({'status': 'completed'}).eq('id', tripId);
  }

  static Future<void> updateLocation(String logId, double lat, double lng) async {
    await client.from('trip_logs').update({'current_lat': lat, 'current_lng': lng}).eq('id', logId);
  }

  static Future<Map<String, dynamic>?> getTripLog(String tripId) async {
    try {
      final res = await client.from('trip_logs').select().eq('trip_id', tripId).maybeSingle();
      return res;
    } catch (e) {
      debugPrint('Error getting trip log: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllDrivers() async {
    return await client.from('users').select('id, user_name').eq('role', 'user');
  }

  static Future<List<Map<String, dynamic>>> getDetailedDrivers() async {
    return await client.from('drivers').select('*, users(user_name)').eq('is_active', true);
  }

  static Future<void> updateDriver(String id, Map<String, dynamic> data) async {
    await client.from('drivers').update(data).eq('id', id);
  }

  static Future<void> updateUser(String id, Map<String, dynamic> data) async {
    await client.from('users').update(data).eq('id', id);
  }

  static Future<void> deleteDriver(String id, String userId) async {
    await client.from('drivers').update({'is_active': false}).eq('id', id);
    await client.from('users').update({'is_active': false}).eq('id', userId);
  }

  static Future<List<Map<String, dynamic>>> getAllVehicles() async {
    return await client.from('vehicles').select().eq('is_active', true).order('vehicle_number');
  }

  static Future<void> updateVehicle(String id, Map<String, dynamic> data) async {
    await client.from('vehicles').update(data).eq('id', id);
  }

  static Future<void> deleteVehicle(String id) async {
    await client.from('vehicles').update({'is_active': false}).eq('id', id);
  }

  static Stream<List<Map<String, dynamic>>> watchTripLog(String tripId) {
    return client.from('trip_logs').stream(primaryKey: ['id']).eq('trip_id', tripId);
  }
}
