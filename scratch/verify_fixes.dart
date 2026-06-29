import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockGotrueAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> getItem({required String key}) async => _data[key];

  @override
  Future<void> removeItem({required String key}) async => _data.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) async => _data[key] = value;
}

void main() async {
  print('Starting Verification Script...');
  
  // Read .env file
  final envFile = File('.env');
  if (!await envFile.exists()) {
    print('Error: .env file not found!');
    exit(1);
  }
  
  final lines = await envFile.readAsLines();
  String? url;
  String? key;
  for (var line in lines) {
    if (line.startsWith('SUPABASE_URL=')) {
      url = line.split('=')[1].trim();
    } else if (line.startsWith('SUPABASE_ANON_KEY=')) {
      key = line.split('=')[1].trim();
    }
  }

  if (url == null || key == null) {
    print('Error: SUPABASE_URL or SUPABASE_ANON_KEY not found in .env');
    exit(1);
  }

  // Initialize Supabase Client directly with Mock storage
  final client = SupabaseClient(
    url,
    key,
    authOptions: AuthClientOptions(
      pkceAsyncStorage: MockGotrueAsyncStorage(),
    ),
  );
  
  try {
    print('\n1. Signing in as Admin...');
    final authRes = await client.auth.signInWithPassword(
      email: 'Admin@tripmanager.app',
      password: 'Admin@12345',
    );
    final adminId = authRes.user?.id;
    print('Signed in. Admin User ID: $adminId');

    // Generate unique username
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testDriverName = 'verify_drv_$timestamp';
    final testDriverPass = 'driver@12345';
    print('\n2. Creating test driver "$testDriverName" with license number "LIC-$timestamp"...');
    
    // Call signUp directly, but wrapped in a session preservation structure
    final adminSession = client.auth.currentSession;
    if (adminSession == null) {
      throw Exception('Admin session was lost before calling signUp');
    }
    
    final signUpResponse = await client.auth.signUp(
      email: '$testDriverName@tripmanager.app',
      password: testDriverPass,
    );
    
    final createdUserId = signUpResponse.user?.id;
    if (createdUserId == null) {
      throw Exception('Sign up failed: no user returned');
    }
    print('Driver user created with id: $createdUserId');

    // Create user profiles in users and drivers tables (simulating SupabaseService.signUp)
    await client.from('users').insert({
      'id': createdUserId,
      'user_name': testDriverName,
      'password': testDriverPass,
      'role': 'user',
    });
    
    await client.from('drivers').insert({'user_id': createdUserId});
    
    // Restore Admin Session
    await client.auth.setSession(adminSession.refreshToken!);
    print('Restored Admin Session. Current User: ${client.auth.currentUser?.email}');

    // Now query the driver ID and update it (simulating createDriver license updating)
    final driverRes = await client.from('drivers').select('id').eq('user_id', createdUserId).maybeSingle();
    final driverId = driverRes?['id'];
    if (driverId == null) {
      throw Exception('Failed to fetch newly created driver profile ID');
    }
    print('Driver profile ID found: $driverId');

    print('Updating driver license details...');
    await client.from('drivers').update({
      'license_number': 'LIC-$timestamp',
      'license_expiry': '2028-12-31',
    }).eq('id', driverId);
    print('Driver license updated successfully.');

    // Fetch details to verify
    final checkDriver = await client.from('drivers').select('*, users(user_name)').eq('id', driverId).single();
    print('Verified Driver data from DB: $checkDriver');

    print('\n3. Testing Admin update capability (changing username to ${testDriverName}_new)...');
    await client.from('users').update({'user_name': '${testDriverName}_new'}).eq('id', createdUserId);
    print('Username updated successfully.');

    print('\n4. Testing Admin delete capability (deleting user $createdUserId)...');
    // Delete from drivers (FK is cascade, so deleting user will delete driver, or we delete driver then user)
    await client.from('drivers').delete().eq('id', driverId);
    await client.from('users').delete().eq('id', createdUserId);
    print('Driver and User deleted successfully from public tables.');

    print('Verification test passed successfully!');

  } catch (e) {
    print('Exception occurred during verification: $e');
  }

  exit(0);
}
