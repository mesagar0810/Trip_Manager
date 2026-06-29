import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
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

  final client = SupabaseClient(url, key);
  
  try {
    print('--- Fetching all rows from public.drivers ---');
    final drivers = await client.from('drivers').select('*');
    print('Total drivers found: ${drivers.length}');
    for (var d in drivers) {
      print(d);
    }
    
    print('\n--- Fetching all rows from public.users ---');
    final users = await client.from('users').select('*');
    print('Total users found: ${users.length}');
    for (var u in users) {
      print(u);
    }
  } catch (e) {
    print('Error querying database: $e');
  }
  
  exit(0);
}
