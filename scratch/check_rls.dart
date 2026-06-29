import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Starting RLS check with logged-in user...');
  
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

  // Initialize Supabase
  await Supabase.initialize(url: url, anonKey: key);
  final client = Supabase.instance.client;
  
  try {
    print('Attempting to sign in as Admin...');
    final response = await client.auth.signInWithPassword(
      email: 'Admin@tripmanager.app',
      password: 'Admin@12345',
    );
    print('Signed in successfully. User ID: ${response.user?.id}');
    
    // Test fetch users
    print('\n--- Fetching users ---');
    try {
      final users = await client.from('users').select();
      print('Users count: ${users.length}');
    } catch (e) {
      print('Failed to fetch users: $e');
    }

    // Test fetch drivers
    print('\n--- Fetching detailed drivers ---');
    try {
      final drivers = await client.from('drivers').select('*, users(user_name)');
      print('Drivers count: ${drivers.length}');
    } catch (e) {
      print('Failed to fetch detailed drivers: $e');
    }

    // Test fetch vehicles
    print('\n--- Fetching vehicles ---');
    try {
      final vehicles = await client.from('vehicles').select();
      print('Vehicles count: ${vehicles.length}');
    } catch (e) {
      print('Failed to fetch vehicles: $e');
    }
    
  } catch (e) {
    print('Auth / General exception: $e');
  }

  exit(0);
}
